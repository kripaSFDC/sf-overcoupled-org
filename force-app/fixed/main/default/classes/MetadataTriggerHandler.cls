/**
 * The router.
 *
 * One trigger per object. That trigger contains one line. Everything else is a
 * row in Trigger_Action__mdt, which means the answer to "what runs when a
 * catalogue item is updated?" is a report, not an archaeology expedition.
 *
 * Three things this does that the static-Boolean version could not:
 *
 *   1. ORDER IS DATA. Order__c decides. Changing it is a metadata deploy, not an
 *      edit to a 600-line handler that six teams share.
 *   2. BYPASS IS A PERMISSION. Bypass_Permission__c names a custom permission.
 *      Assign it and the action stops, for that user, immediately, with no
 *      deployment. That is the 2am switch.
 *   3. RECURSION IS LOUD. There is a depth limit, and when it trips it THROWS.
 *      The old `hasRun` flag swallowed the second pass and let a wrong record
 *      reach a report. A stack trace on screen beats a silent wrong number.
 *
 * Governor note: Trigger_Action__mdt.getAll() is an in-memory read of custom
 * metadata. It is not SOQL and does not consume a query. That is why the bulk
 * harness can assert a flat query count.
 */
public inherited sharing class MetadataTriggerHandler {

    private static final Integer MAX_DEPTH = 5;

    private static final Set<String> BYPASSED_OBJECTS = new Set<String>();
    private static final Map<String, Integer> DEPTH = new Map<String, Integer>();
    private static Map<String, List<Trigger_Action__mdt>> routeCache;

    // ---------------------------------------------------------------- bypass

    public static void bypass(String objectApiName) {
        BYPASSED_OBJECTS.add(objectApiName.toLowerCase());
    }

    public static void clearBypass(String objectApiName) {
        BYPASSED_OBJECTS.remove(objectApiName.toLowerCase());
    }

    public static void clearAllBypasses() {
        BYPASSED_OBJECTS.clear();
    }

    public static Boolean isBypassed(String objectApiName) {
        return BYPASSED_OBJECTS.contains(objectApiName.toLowerCase());
    }

    // ------------------------------------------------------------------- run

    public void run() {
        if (!Trigger.isExecuting) {
            throw new TriggerHandlerException(
                'MetadataTriggerHandler.run() may only be called from inside a trigger.');
        }

        SObject sample = (Trigger.new != null && !Trigger.new.isEmpty())
            ? Trigger.new[0]
            : Trigger.old[0];
        String objectName = sample.getSObjectType().getDescribe().getName();

        if (isBypassed(objectName)) {
            return;
        }

        String context = currentContext();
        if (context == null) {
            return;
        }

        String key = objectName + '.' + context;
        Integer depth = enter(key);

        try {
            for (Trigger_Action__mdt action : routesFor(objectName, context)) {
                if (!isPermitted(action)) {
                    continue;
                }
                dispatch(action, context, instantiate(action));
            }
        } finally {
            exit(key);
        }
    }

    // ---------------------------------------------------------------- depth

    private Integer enter(String key) {
        Integer depth = (DEPTH.containsKey(key) ? DEPTH.get(key) : 0) + 1;
        DEPTH.put(key, depth);
        if (depth > MAX_DEPTH) {
            // Loudly. Not silently. This is the whole argument.
            throw new TriggerHandlerException(
                'Recursion depth ' + depth + ' exceeded for ' + key + '. ' +
                'Something is writing back into its own trigger. Fix the cycle - ' +
                'do not raise this number.');
        }
        return depth;
    }

    private void exit(String key) {
        DEPTH.put(key, DEPTH.get(key) - 1);
    }

    public static Integer currentDepth(String objectApiName, String context) {
        String key = objectApiName + '.' + context;
        return DEPTH.containsKey(key) ? DEPTH.get(key) : 0;
    }

    // ---------------------------------------------------------------- routes

    @TestVisible
    private static List<Trigger_Action__mdt> routesFor(String objectName, String context) {
        if (routeCache == null) {
            buildCache();
        }
        String key = (objectName + '|' + context).toLowerCase();
        return routeCache.containsKey(key) ? routeCache.get(key) : new List<Trigger_Action__mdt>();
    }

    private static void buildCache() {
        routeCache = new Map<String, List<Trigger_Action__mdt>>();

        List<Trigger_Action__mdt> all = allActions();
        // Insertion sort on Order__c. Small n, and it keeps the whole thing
        // inside one in-memory read.
        for (Integer i = 1; i < all.size(); i++) {
            Trigger_Action__mdt current = all[i];
            Integer j = i - 1;
            while (j >= 0 && all[j].Order__c > current.Order__c) {
                all[j + 1] = all[j];
                j--;
            }
            all[j + 1] = current;
        }

        for (Trigger_Action__mdt action : all) {
            if (action.Active__c != true) {
                continue;
            }
            String key = (action.Object_API_Name__c + '|' + action.Context__c).toLowerCase();
            if (!routeCache.containsKey(key)) {
                routeCache.put(key, new List<Trigger_Action__mdt>());
            }
            routeCache.get(key).add(action);
        }
    }

    @TestVisible
    private static List<Trigger_Action__mdt> overrideActions;

    @TestVisible
    private static List<Trigger_Action__mdt> allActions() {
        if (overrideActions != null) {
            return overrideActions.clone();
        }
        return Trigger_Action__mdt.getAll().values();
    }

    @TestVisible
    private static void resetCache() {
        routeCache = null;
    }

    // ----------------------------------------------------------- permissions

    @TestVisible
    private Boolean isPermitted(Trigger_Action__mdt action) {
        if (String.isNotBlank(action.Bypass_Permission__c)
            && FeatureManagement.checkPermission(action.Bypass_Permission__c)) {
            return false;
        }
        if (String.isNotBlank(action.Required_Permission__c)
            && !FeatureManagement.checkPermission(action.Required_Permission__c)) {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ dispatch

    @TestVisible
    private static Object instantiate(Trigger_Action__mdt action) {
        Type actionType = Type.forName(action.Apex_Class_Name__c);
        if (actionType == null) {
            throw new TriggerHandlerException(
                'Trigger_Action__mdt "' + action.DeveloperName + '" points at Apex class "' +
                action.Apex_Class_Name__c + '", which does not exist or is not visible. ' +
                'TriggerActionRegistryTest exists so that this is a deploy failure, not a runtime one.');
        }
        return actionType.newInstance();
    }

    private void dispatch(Trigger_Action__mdt action, String context, Object instance) {
        try {
            switch on context {
                when 'BEFORE_INSERT' {
                    ((TriggerAction.BeforeInsert) instance).beforeInsert(Trigger.new);
                }
                when 'AFTER_INSERT' {
                    ((TriggerAction.AfterInsert) instance).afterInsert(Trigger.new);
                }
                when 'BEFORE_UPDATE' {
                    ((TriggerAction.BeforeUpdate) instance).beforeUpdate(Trigger.new, Trigger.oldMap);
                }
                when 'AFTER_UPDATE' {
                    ((TriggerAction.AfterUpdate) instance).afterUpdate(Trigger.new, Trigger.oldMap);
                }
                when 'BEFORE_DELETE' {
                    ((TriggerAction.BeforeDelete) instance).beforeDelete(Trigger.oldMap);
                }
                when 'AFTER_DELETE' {
                    ((TriggerAction.AfterDelete) instance).afterDelete(Trigger.oldMap);
                }
                when 'AFTER_UNDELETE' {
                    ((TriggerAction.AfterUndelete) instance).afterUndelete(Trigger.new);
                }
            }
        } catch (TypeException e) {
            throw new TriggerHandlerException(
                'Apex class "' + action.Apex_Class_Name__c + '" is registered for ' + context +
                ' but does not implement TriggerAction.' + interfaceFor(context) + '. ' + e.getMessage());
        }
    }

    @TestVisible
    private static String interfaceFor(String context) {
        switch on context {
            when 'BEFORE_INSERT'  { return 'BeforeInsert'; }
            when 'AFTER_INSERT'   { return 'AfterInsert'; }
            when 'BEFORE_UPDATE'  { return 'BeforeUpdate'; }
            when 'AFTER_UPDATE'   { return 'AfterUpdate'; }
            when 'BEFORE_DELETE'  { return 'BeforeDelete'; }
            when 'AFTER_DELETE'   { return 'AfterDelete'; }
            when 'AFTER_UNDELETE' { return 'AfterUndelete'; }
            when else             { return 'Unknown'; }
        }
    }

    private String currentContext() {
        if (Trigger.isBefore) {
            if (Trigger.isInsert) { return 'BEFORE_INSERT'; }
            if (Trigger.isUpdate) { return 'BEFORE_UPDATE'; }
            if (Trigger.isDelete) { return 'BEFORE_DELETE'; }
        } else {
            if (Trigger.isInsert)   { return 'AFTER_INSERT'; }
            if (Trigger.isUpdate)   { return 'AFTER_UPDATE'; }
            if (Trigger.isDelete)   { return 'AFTER_DELETE'; }
            if (Trigger.isUndelete) { return 'AFTER_UNDELETE'; }
        }
        return null;
    }
}

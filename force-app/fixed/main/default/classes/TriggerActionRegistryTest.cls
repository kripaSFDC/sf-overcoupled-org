/**
 * Gap 2 of 3: the registry is validated at DEPLOY time, not at 9am on Monday.
 *
 * The weakness of any metadata-driven dispatcher is that the wiring is data, and
 * data is not compiled. Rename a class, delete an action, register a BeforeUpdate
 * class in an AfterInsert slot, and nothing complains until a user saves a record.
 *
 * This test closes that. It fails the deployment instead.
 *
 * It is the single highest-value class in the whole package and it is thirty
 * lines long. If you take one thing from this episode, take this one.
 */
@IsTest
private class TriggerActionRegistryTest {

    @IsTest
    static void everyRegisteredActionResolvesAndImplementsItsInterface() {
        List<String> problems = new List<String>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (Trigger_Action__mdt action : Trigger_Action__mdt.getAll().values()) {
            if (action.Active__c != true) {
                continue;
            }
            String label = 'Trigger_Action__mdt.' + action.DeveloperName;

            if (!globalDescribe.containsKey(action.Object_API_Name__c)) {
                problems.add(label + ' targets object "' + action.Object_API_Name__c +
                             '", which does not exist in this org.');
                continue;
            }

            Type actionType = Type.forName(action.Apex_Class_Name__c);
            if (actionType == null) {
                problems.add(label + ' points at Apex class "' + action.Apex_Class_Name__c +
                             '", which does not exist or is not global/public.');
                continue;
            }

            Object instance;
            try {
                instance = actionType.newInstance();
            } catch (Exception e) {
                problems.add(label + ': ' + action.Apex_Class_Name__c +
                             ' has no zero-argument constructor (' + e.getMessage() + ').');
                continue;
            }

            if (!implementsContext(instance, action.Context__c)) {
                problems.add(label + ': ' + action.Apex_Class_Name__c + ' is registered for ' +
                             action.Context__c + ' but does not implement TriggerAction.' +
                             expectedInterface(action.Context__c) + '.');
            }

            if (action.Order__c == null) {
                problems.add(label + ' has no Order__c. Ordering must be explicit.');
            }
        }

        Assert.isTrue(problems.isEmpty(),
            'The trigger action registry is inconsistent:\n - ' + String.join(problems, '\n - '));
    }

    @IsTest
    static void ordersAreUniqueWithinAnObjectAndContext() {
        Map<String, Set<Decimal>> seen = new Map<String, Set<Decimal>>();
        List<String> clashes = new List<String>();

        for (Trigger_Action__mdt action : Trigger_Action__mdt.getAll().values()) {
            if (action.Active__c != true || action.Order__c == null) {
                continue;
            }
            String key = action.Object_API_Name__c + '|' + action.Context__c;
            if (!seen.containsKey(key)) {
                seen.put(key, new Set<Decimal>());
            }
            if (seen.get(key).contains(action.Order__c)) {
                clashes.add(key + ' has two actions at order ' + action.Order__c +
                            '. Execution order would be undefined.');
            }
            seen.get(key).add(action.Order__c);
        }

        Assert.isTrue(clashes.isEmpty(), String.join(clashes, '\n'));
    }

    private static Boolean implementsContext(Object instance, String context) {
        switch on context {
            when 'BEFORE_INSERT'  { return instance instanceof TriggerAction.BeforeInsert; }
            when 'AFTER_INSERT'   { return instance instanceof TriggerAction.AfterInsert; }
            when 'BEFORE_UPDATE'  { return instance instanceof TriggerAction.BeforeUpdate; }
            when 'AFTER_UPDATE'   { return instance instanceof TriggerAction.AfterUpdate; }
            when 'BEFORE_DELETE'  { return instance instanceof TriggerAction.BeforeDelete; }
            when 'AFTER_DELETE'   { return instance instanceof TriggerAction.AfterDelete; }
            when 'AFTER_UNDELETE' { return instance instanceof TriggerAction.AfterUndelete; }
            when else             { return false; }
        }
    }

    private static String expectedInterface(String context) {
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
}

/**
 * Gap 3 of 3: one commit point per transaction.
 *
 * In the broken package there are three DML statements in three classes, each of
 * which can partially succeed, in an order that is an accident of trigger
 * registration. If link 3 fails, links 1 and 2 have already committed. You get
 * half a price change and nothing tells you.
 *
 * Here work is registered and committed once, in a declared object order, inside
 * a savepoint. Either the whole price change lands or none of it does.
 *
 * Production note: fflib_SObjectUnitOfWork does all of this and more, and if you
 * are already on fflib, use it - but construct it with an fflib_SObjectUnitOfWork.IDML
 * implementation that calls Database.insert with AccessLevel.USER_MODE, because
 * the stock one does not. That combination is the part that is not written down
 * anywhere, and it is why this class exists in the teaching copy.
 */
public inherited sharing class AipUnitOfWork {

    private final List<SObjectType> commitOrder;
    private final AccessLevel level;
    private final String justification;
    private final Map<String, List<SObject>> newRecords = new Map<String, List<SObject>>();
    private final Map<String, Map<Id, SObject>> dirtyRecords = new Map<String, Map<Id, SObject>>();

    public AipUnitOfWork(List<SObjectType> commitOrder) {
        this(commitOrder, AccessLevel.USER_MODE, null);
    }

    /**
     * System mode requires a justification. Not for the compiler - for the person
     * reading this in eighteen months who needs to know whether it was a decision
     * or a shortcut.
     */
    public AipUnitOfWork(List<SObjectType> commitOrder, AccessLevel level, String justification) {
        if (level == AccessLevel.SYSTEM_MODE && String.isBlank(justification)) {
            throw new TriggerHandlerException(
                'A system-mode unit of work must carry a written justification.');
        }
        this.commitOrder = commitOrder;
        this.level = level;
        this.justification = justification;
        resetBuckets();
    }

    public void registerNew(SObject record) {
        String key = keyFor(record);
        assertRegistered(key);
        newRecords.get(key).add(record);
    }

    public void registerNew(List<SObject> records) {
        for (SObject r : records) {
            registerNew(r);
        }
    }

    /**
     * Registering the same record twice merges rather than duplicating. That is
     * what stops two independent actions issuing two updates to one row - which
     * in the broken package is exactly how a save ends up firing its own trigger
     * a second time.
     */
    public void registerDirty(SObject record) {
        String key = keyFor(record);
        assertRegistered(key);
        Map<Id, SObject> bucket = dirtyRecords.get(key);
        Id recordId = record.Id;
        if (bucket.containsKey(recordId)) {
            SObject existing = bucket.get(recordId);
            for (String fieldName : record.getPopulatedFieldsAsMap().keySet()) {
                if (fieldName != 'Id') {
                    existing.put(fieldName, record.get(fieldName));
                }
            }
        } else {
            bucket.put(recordId, record);
        }
    }

    public void registerDirty(List<SObject> records) {
        for (SObject r : records) {
            registerDirty(r);
        }
    }

    public Integer pendingCount() {
        Integer total = 0;
        for (String key : newRecords.keySet()) {
            total += newRecords.get(key).size() + dirtyRecords.get(key).size();
        }
        return total;
    }

    public void commitWork() {
        if (pendingCount() == 0) {
            return;
        }
        if (level == AccessLevel.SYSTEM_MODE) {
            System.debug(LoggingLevel.INFO, 'SYSTEM-MODE UNIT OF WORK: ' + justification);
        }
        System.Savepoint sp = Database.setSavepoint();
        try {
            for (SObjectType t : commitOrder) {
                String key = String.valueOf(t);
                List<SObject> inserts = newRecords.get(key);
                if (!inserts.isEmpty()) {
                    SecureDb.doInsert(inserts, true, level);
                }
                List<SObject> updates = dirtyRecords.get(key).values();
                if (!updates.isEmpty()) {
                    SecureDb.doUpdate(updates, true, level);
                }
            }
            resetBuckets();
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    private void resetBuckets() {
        newRecords.clear();
        dirtyRecords.clear();
        for (SObjectType t : commitOrder) {
            newRecords.put(String.valueOf(t), new List<SObject>());
            dirtyRecords.put(String.valueOf(t), new Map<Id, SObject>());
        }
    }

    private String keyFor(SObject record) {
        return String.valueOf(record.getSObjectType());
    }

    private void assertRegistered(String key) {
        if (!newRecords.containsKey(key)) {
            throw new TriggerHandlerException(
                'SObject type ' + key + ' was not declared in this unit of work commit order. ' +
                'The order is explicit on purpose - it is the thing that stops a parent being ' +
                'saved after its children.');
        }
    }
}

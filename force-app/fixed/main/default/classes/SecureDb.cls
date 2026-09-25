/**
 * Gap 1 of 3: security is a default, not a review checklist item.
 *
 * Triggers run in system mode. Always have. Every handler in the broken package
 * therefore ignores field-level security and sharing, and the only thing between
 * that and an audit finding is whether a reviewer remembered to look.
 *
 * Every query and every DML in the rebuilt package goes through here, so user
 * mode is what you get by forgetting, not what you get by remembering.
 *
 * Two honest caveats, both worth saying out loud:
 *
 *   1. User mode applies the RUNNING user's permissions. Inside a trigger that is
 *      whoever saved the record. Assign AIP_Demo_Operator before you test, or the
 *      rebuilt code will correctly refuse to write and you will think it is broken.
 *   2. Platform event subscribers run as the Automated Process user, which holds
 *      almost nothing. That subscriber is a legitimate, named, system-mode
 *      exception - see doInsertAsSystem. Grep for it and you have the complete
 *      list of everywhere this org runs above the user. It should stay short.
 */
public inherited sharing class SecureDb {

    public static List<SObject> query(String soql, Map<String, Object> binds) {
        return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public static List<SObject> query(String soql, Map<String, Object> binds, AccessLevel level) {
        return Database.queryWithBinds(soql, binds, level);
    }

    public static List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNone) {
        return doInsert(records, allOrNone, AccessLevel.USER_MODE);
    }

    public static List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNone, AccessLevel level) {
        return Database.insert(records, allOrNone, level);
    }

    public static List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNone) {
        return doUpdate(records, allOrNone, AccessLevel.USER_MODE);
    }

    public static List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNone, AccessLevel level) {
        return Database.update(records, allOrNone, level);
    }

    public static List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalId, Boolean allOrNone) {
        return Database.upsert(records, externalId, allOrNone, AccessLevel.USER_MODE);
    }

    public static List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalId, Boolean allOrNone, AccessLevel level) {
        return Database.upsert(records, externalId, allOrNone, level);
    }

    public static List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNone) {
        return Database.delete(records, allOrNone, AccessLevel.USER_MODE);
    }

    /** Deliberate, named, logged escape hatch. Requires a justification string. */
    public static List<Database.SaveResult> doInsertAsSystem(List<SObject> records, Boolean allOrNone, String justification) {
        System.debug(LoggingLevel.INFO, 'SYSTEM-MODE INSERT: ' + justification);
        return Database.insert(records, allOrNone, AccessLevel.SYSTEM_MODE);
    }

    public static List<Database.SaveResult> doUpdateAsSystem(List<SObject> records, Boolean allOrNone, String justification) {
        System.debug(LoggingLevel.INFO, 'SYSTEM-MODE UPDATE: ' + justification);
        return Database.update(records, allOrNone, AccessLevel.SYSTEM_MODE);
    }
}

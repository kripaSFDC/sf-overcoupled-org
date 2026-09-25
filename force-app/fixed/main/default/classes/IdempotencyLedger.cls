/**
 * "Exactly once" is not something a subscriber can promise. Platform events are
 * at-least-once - a replay, a retry after a row-lock, a resumed checkpoint, and
 * the same event arrives twice.
 *
 * So do not promise it in code. Promise it in the schema: Event_Uuid__c is a
 * unique external id. The database enforces the guarantee whether or not the
 * next developer reads this comment.
 */
public inherited sharing class IdempotencyLedger {

    /** One query for the whole batch. */
    public static Set<String> alreadyProcessed(Set<String> uuids) {
        Set<String> seen = new Set<String>();
        if (uuids == null || uuids.isEmpty()) {
            return seen;
        }
        List<Processed_Event__c> rows = (List<Processed_Event__c>) SecureDb.query(
            'SELECT Id, Event_Uuid__c FROM Processed_Event__c WHERE Event_Uuid__c IN :uuids',
            new Map<String, Object>{ 'uuids' => uuids },
            AccessLevel.SYSTEM_MODE);
        for (Processed_Event__c row : rows) {
            seen.add(row.Event_Uuid__c);
        }
        return seen;
    }

    public static List<Processed_Event__c> entriesFor(Set<String> uuids, String handler) {
        List<Processed_Event__c> rows = new List<Processed_Event__c>();
        for (String uuid : uuids) {
            rows.add(new Processed_Event__c(
                Event_Uuid__c = uuid,
                Handler__c    = handler,
                Processed_At__c = System.now()
            ));
        }
        return rows;
    }
}

/**
 * The inbox door.
 *
 * The first version of staging in the real remediation did not hold, and this is
 * why: it validated on the way in and threw when a row was wrong. A throw on
 * insert means the sender gets an error, retries, and you have no record of what
 * they sent - so you cannot reproduce the failure and you cannot fix it without
 * asking them to send it again.
 *
 * This version never rejects. Everything lands. Bad rows land as Quarantined and
 * sit there where you can read them. Validation is a decision made later, by the
 * promoter, against a row you still have.
 */
public with sharing class StagingIntakeGuard implements TriggerAction.BeforeInsert {

    public void beforeInsert(List<SObject> newList) {
        for (SObject record : newList) {
            Inbound_Listing_Staging__c row = (Inbound_Listing_Staging__c) record;

            if (row.Attempt_Count__c == null) {
                row.Attempt_Count__c = 0;
            }
            if (String.isNotBlank(row.Source_Key__c)) {
                row.Source_Key__c = row.Source_Key__c.trim().toUpperCase();
            }
            if (String.isBlank(row.Raw_Payload__c)) {
                row.Status__c = 'Quarantined';
                row.Error_Message__c = 'Empty payload. Kept for investigation, not rejected.';
                continue;
            }
            if (String.isBlank(row.Status__c)) {
                row.Status__c = 'New';
            }
        }
    }
}

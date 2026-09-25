/**
 * Replaces ManufacturerListingTriggerHandler.
 *
 * Everything it needs is on the record in hand. No parent query, no duplicate
 * check, no case creation - because raising a case is not this object's job, and
 * deciding that was the actual architectural fix. The old handler did three
 * unrelated things because there was only ever one place to put code.
 */
public with sharing class ManufacturerListingCompliance implements TriggerAction.BeforeUpdate {

    private static final Set<SObjectField> WATCHED = new Set<SObjectField>{
        Manufacturer_Listing__c.Listed_Price__c,
        Manufacturer_Listing__c.Pack_Size__c
    };

    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        for (SObject record : ChangeDetector.changed(newList, oldMap, WATCHED)) {
            Manufacturer_Listing__c listing = (Manufacturer_Listing__c) record;
            listing.Compliance_Status__c = 'Pending Review';
            listing.Needs_Review__c      = true;
            listing.Last_Synced__c       = System.now();
        }
    }
}

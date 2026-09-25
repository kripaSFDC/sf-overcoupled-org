/**
 * The second link.
 *
 * Two queries per record, and a describe call in the loop for good measure.
 * Note that this handler cannot see link 1. It has no idea it is running inside
 * someone else's transaction. That is the actual defect - the coupling, not the
 * query count. The query count is just how the coupling announces itself.
 */
public with sharing class ManufacturerListingTriggerHandler {

    private static Boolean hasRun = false;

    public static void onAfterUpdate(List<Manufacturer_Listing__c> listings, Map<Id, Manufacturer_Listing__c> oldMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        Id priceChangeRt = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Price_Change')
            .getRecordTypeId();

        List<Case> toRaise = new List<Case>();

        for (Manufacturer_Listing__c listing : listings) {
            Manufacturer_Listing__c prior = oldMap.get(listing.Id);

            if (listing.Listed_Price__c == prior.Listed_Price__c) {
                continue;
            }

            // Query two: the parent, one row at a time, because the handler
            // was written as if it would only ever see one record.
            Catalogue_Item__c parent = [
                SELECT Id, Name, Item_Code__c, Current_Price__c, Storage_Temp__c
                FROM Catalogue_Item__c
                WHERE Id = :listing.Catalogue_Item__c
                LIMIT 1
            ];

            // Query three: "don't raise a duplicate case". Reasonable intent.
            // Catastrophic placement.
            Integer openCases = [
                SELECT COUNT()
                FROM Case
                WHERE Manufacturer_Listing__c = :listing.Id
                  AND IsClosed = false
            ];

            if (openCases > 0) {
                continue;
            }

            toRaise.add(new Case(
                RecordTypeId            = priceChangeRt,
                Subject                 = 'Price change: ' + parent.Item_Code__c,
                Description             = 'Listed price moved from ' + prior.Listed_Price__c +
                                          ' to ' + listing.Listed_Price__c + '.',
                Status                  = 'New',
                Origin                  = 'Internal',
                Catalogue_Item__c       = parent.Id,
                Manufacturer_Listing__c = listing.Id,
                Automation_Source__c    = 'ManufacturerListingTriggerHandler',
                Trigger_Depth__c        = 2
            ));
        }

        if (!toRaise.isEmpty()) {
            // Fires link 3.
            insert toRaise;
        }
    }
}

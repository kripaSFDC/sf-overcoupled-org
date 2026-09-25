/**
 * The first link.
 *
 * Three things are wrong here and only one of them is obvious:
 *
 *   1. SOQL inside the for loop. This is the one everybody sees. It is also the
 *      least interesting, because it is trivially fixable.
 *   2. `hasRun`. A static Boolean is not recursion control - it is a promise that
 *      this logic only ever needs to happen once per transaction. That promise is
 *      false the moment anything re-enters with a different set of records, and
 *      when it breaks it does not throw. It silently skips work.
 *   3. The handler owns no decision. It reacts. There is nowhere to stand and ask
 *      "should this happen at all?" - so the answer is always yes.
 */
public with sharing class CatalogueItemTriggerHandler {

    // Link 3 updates Catalogue Item, which re-enters this handler.
    // This flag stops the loop. It also throws away whatever the second pass
    // was supposed to do, and nobody finds out until a record is wrong in a report.
    private static Boolean hasRun = false;

    public static void onAfterUpdate(List<Catalogue_Item__c> items, Map<Id, Catalogue_Item__c> oldMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        List<Manufacturer_Listing__c> toUpdate = new List<Manufacturer_Listing__c>();

        for (Catalogue_Item__c item : items) {
            Catalogue_Item__c prior = oldMap.get(item.Id);

            if (item.Current_Price__c == prior.Current_Price__c) {
                continue;
            }

            // One query. Per record. Every time.
            // 101 catalogue items in a data load is all it takes.
            // Note the SELECT list. Catalogue_Item__c is a non-reparentable
            // master-detail: createable, never updateable. Query it onto a record
            // and then update that record and the DML refuses the whole payload.
            // It is not selected here because it is not needed here.
            List<Manufacturer_Listing__c> listings = [
                SELECT Id, Listed_Price__c, Needs_Review__c
                FROM Manufacturer_Listing__c
                WHERE Catalogue_Item__c = :item.Id
            ];

            for (Manufacturer_Listing__c listing : listings) {
                listing.Listed_Price__c = item.Current_Price__c;
                listing.Needs_Review__c = true;
                listing.Last_Synced__c = System.now();
                toUpdate.add(listing);
            }
        }

        if (!toUpdate.isEmpty()) {
            // Fires link 2.
            update toUpdate;
        }
    }
}

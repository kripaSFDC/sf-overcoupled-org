/**
 * The third link - the one that turns a chain into a cycle.
 *
 * This updates Catalogue Item, which re-enters link 1, which is only stopped by
 * a static Boolean. The snake reaches its own tail here.
 *
 * Draw this on a whiteboard and it is three arrows. Debug it in production at
 * 6pm on a Friday and it is a 4,000 line log where the same class name appears
 * eleven times and none of the occurrences tell you which one mattered.
 */
public with sharing class CaseTriggerHandler {

    private static Boolean hasRun = false;

    public static void onAfterInsert(List<Case> cases) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        List<Catalogue_Item__c> toFlag = new List<Catalogue_Item__c>();

        for (Case c : cases) {
            if (c.Manufacturer_Listing__c == null) {
                continue;
            }

            // Query four.
            Manufacturer_Listing__c listing = [
                SELECT Id, Catalogue_Item__c, Listed_Price__c
                FROM Manufacturer_Listing__c
                WHERE Id = :c.Manufacturer_Listing__c
                LIMIT 1
            ];

            // Query five. We already had the parent id on the case.
            Catalogue_Item__c item = [
                SELECT Id, Needs_Review__c, Last_Price_Change__c
                FROM Catalogue_Item__c
                WHERE Id = :listing.Catalogue_Item__c
                LIMIT 1
            ];

            item.Needs_Review__c = true;
            item.Last_Price_Change__c = System.now();
            toFlag.add(item);
        }

        if (!toFlag.isEmpty()) {
            // Back to link 1. `hasRun` is already true there, so this update's
            // downstream effect is silently discarded.
            update toFlag;
        }
    }
}

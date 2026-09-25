/**
 * The test that shipped with all of this.
 *
 * It passes. It covers every line of all three handlers. It inserts one record.
 * Coverage is not a safety property, and this class is the proof.
 *
 * Note the @TestSetup, and why it has to be there.
 *
 * Manufacturer_Listing__c is a master-detail child, and Catalogue_Item__c
 * carries a roll-up summary over it. So inserting a listing forces the parent's
 * roll-up to recalculate, which sends the parent back through the save
 * procedure - which fires CatalogueItemTrigger. Nothing useful happens on that
 * pass, because the price hasn't moved. But `hasRun` gets set to true on the
 * way through.
 *
 * Do the setup inline in the test method and the real price change arrives to
 * find `hasRun` already true, and does nothing at all. The assertion fails and
 * the message tells you a price is wrong - not that a static Boolean ate your
 * transaction.
 *
 * @TestSetup runs in its own transaction, so statics reset before the test
 * method starts. That is the only reason this test can pass.
 *
 * Worth sitting with: the flag does not just drop work in production. It drops
 * work inside the test written to prove the feature works.
 */
@IsTest
private class BrokenChainTest {

    @TestSetup
    static void makeData() {
        Account manufacturer = new Account(Name = 'Northbridge Pharma');
        insert manufacturer;

        Catalogue_Item__c item = new Catalogue_Item__c(
            Name             = 'Amoxicillin 500mg Caps',
            Item_Code__c     = 'TEST-0001',
            Current_Price__c = 10.00,
            Storage_Temp__c  = 'Ambient',
            Status__c        = 'Active'
        );
        insert item;

        insert new Manufacturer_Listing__c(
            Catalogue_Item__c    = item.Id,
            Manufacturer__c      = manufacturer.Id,
            Listed_Price__c      = 10.00,
            Pack_Size__c         = 28,
            Compliance_Status__c = 'Compliant',
            Source_Key__c        = 'TEST-0001|NORTHBRIDGE'
        );
    }

    @IsTest
    static void priceChangeFlowsToListing() {
        Catalogue_Item__c item = [
            SELECT Id, Current_Price__c FROM Catalogue_Item__c WHERE Item_Code__c = 'TEST-0001' LIMIT 1
        ];
        Manufacturer_Listing__c listing = [
            SELECT Id FROM Manufacturer_Listing__c WHERE Catalogue_Item__c = :item.Id LIMIT 1
        ];

        Test.startTest();
        item.Current_Price__c = 12.50;
        update item;
        Test.stopTest();

        Manufacturer_Listing__c saved = [
            SELECT Listed_Price__c, Needs_Review__c
            FROM Manufacturer_Listing__c
            WHERE Id = :listing.Id
        ];

        Assert.areEqual(12.50, saved.Listed_Price__c, 'Listed price should follow the catalogue price.');
        Assert.isTrue(saved.Needs_Review__c, 'Listing should be flagged for review.');

        // One record in, one record out, green tick. Ship it.
        // Now look at BulkSafetyTest in force-app/fixed and notice what this
        // class never asked.
    }
}

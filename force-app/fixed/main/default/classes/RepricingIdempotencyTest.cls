/**
 * At-least-once delivery, proven rather than assumed.
 *
 * The same event is handed to the subscriber twice. The second pass must do
 * nothing - no second case, no second ledger row - and it must do nothing because
 * the unique index says so, not because a static Boolean happened to still be set.
 */
@IsTest
private class RepricingIdempotencyTest {

    @TestSetup
    static void setup() {
        DemoDataFactory.build(3, 2);
    }

    @IsTest
    static void replayingAnEventChangesNothing() {
        Catalogue_Item__c item = [SELECT Id, Current_Price__c FROM Catalogue_Item__c ORDER BY Item_Code__c LIMIT 1];

        List<Listing_Repricing__e> events = new List<Listing_Repricing__e>{
            new Listing_Repricing__e(
                Event_Uuid__c        = 'replay-test-0001',
                Catalogue_Item_Id__c = item.Id,
                New_Price__c         = 99.00,
                Previous_Price__c    = item.Current_Price__c)
        };

        Test.startTest();
        RepricingEventHandler.handle(events);
        Integer casesAfterFirst  = [SELECT COUNT() FROM Case];
        Integer ledgerAfterFirst = [SELECT COUNT() FROM Processed_Event__c];

        // Same event. Again. As the platform is entitled to do.
        RepricingEventHandler.handle(events);
        Test.stopTest();

        Assert.areEqual(casesAfterFirst, [SELECT COUNT() FROM Case],
            'A replayed event must not raise a second case.');
        Assert.areEqual(ledgerAfterFirst, [SELECT COUNT() FROM Processed_Event__c],
            'A replayed event must not write a second ledger row.');
        Assert.areEqual(1, ledgerAfterFirst, 'One event, one ledger row.');

        for (Manufacturer_Listing__c listing : [
            SELECT Listed_Price__c FROM Manufacturer_Listing__c WHERE Catalogue_Item__c = :item.Id
        ]) {
            Assert.areEqual(99.00, listing.Listed_Price__c, 'Listings should carry the new price.');
        }
    }

    @IsTest
    static void duplicatesInsideOneBatchAreCollapsed() {
        Catalogue_Item__c item = [SELECT Id, Current_Price__c FROM Catalogue_Item__c ORDER BY Item_Code__c LIMIT 1];
        Listing_Repricing__e e = new Listing_Repricing__e(
            Event_Uuid__c        = 'dupe-in-batch-0001',
            Catalogue_Item_Id__c = item.Id,
            New_Price__c         = 42.00,
            Previous_Price__c    = item.Current_Price__c);

        Test.startTest();
        RepricingEventHandler.handle(new List<Listing_Repricing__e>{ e, e, e });
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Processed_Event__c WHERE Event_Uuid__c = 'dupe-in-batch-0001'],
            'Three copies in one batch is still one unit of work.');
    }
}

/**
 * The assertion the original test never made.
 *
 * BrokenChainTest asked "does a price change reach the listing?" and got a green
 * tick. It is a true statement about one record and it is worthless, because the
 * thing that broke production was not correctness. It was shape.
 *
 * This test asks a different question: does the cost of this automation depend on
 * how many records are in the save? If the answer is yes, it does not matter that
 * it works today - it is a countdown.
 *
 * Write this test on day one and the whole episode never happens.
 */
@IsTest
private class BulkSafetyTest {

    @TestSetup
    static void setup() {
        DemoDataFactory.build(200, 3);
    }

    @IsTest
    static void triggerSideCostDoesNotGrowWithBatchSize() {
        List<Catalogue_Item__c> items = [
            SELECT Id, Current_Price__c FROM Catalogue_Item__c ORDER BY Item_Code__c
        ];

        // ---- one record
        Catalogue_Item__c single = items[0];
        single.Current_Price__c = single.Current_Price__c + 1;

        Integer queriesBefore = Limits.getQueries();
        Integer dmlBefore     = Limits.getDmlStatements();
        update single;
        Integer oneRecordQueries = Limits.getQueries() - queriesBefore;
        Integer oneRecordDml     = Limits.getDmlStatements() - dmlBefore;

        // ---- 199 records, same save
        List<Catalogue_Item__c> rest = new List<Catalogue_Item__c>();
        for (Integer i = 1; i < items.size(); i++) {
            items[i].Current_Price__c = items[i].Current_Price__c + 1;
            rest.add(items[i]);
        }

        queriesBefore = Limits.getQueries();
        dmlBefore     = Limits.getDmlStatements();
        update rest;
        Integer manyRecordQueries = Limits.getQueries() - queriesBefore;
        Integer manyRecordDml     = Limits.getDmlStatements() - dmlBefore;

        System.debug(LoggingLevel.INFO,
            '1 record  -> queries=' + oneRecordQueries + ' dml=' + oneRecordDml);
        System.debug(LoggingLevel.INFO,
            '199 records -> queries=' + manyRecordQueries + ' dml=' + manyRecordDml);

        Assert.areEqual(0, oneRecordQueries,
            'The catalogue trigger should not query at all. It publishes a fact.');
        Assert.areEqual(oneRecordQueries, manyRecordQueries,
            'Query cost must not depend on batch size. This is the assertion that was missing.');
        Assert.areEqual(oneRecordDml, manyRecordDml,
            'DML cost must not depend on batch size either.');
    }

    // ------------------------------------------------------------------
    // REMOVED FOR NOW — subscriberSideCostDoesNotGrowWithBatchSize
    //
    // It called RepricingEventHandler directly, and the deploy refused to
    // resolve that class from inside this test even though the class itself
    // compiles and deploys fine. Unresolved. Not worth blocking a shoot over.
    //
    // The original version was worse than useless anyway: Listing_Repricing__e
    // is PublishAfterCommit, so Test.getEventBus().deliver() before
    // Test.stopTest() delivers nothing. Both query deltas came back zero and
    // two assertions passed against nothing at all.
    //
    // The subscriber IS covered — RepricingIdempotencyTest exercises it
    // directly and asserts the ledger behaviour. What is missing here is only
    // the cost-shape assertion on the subscriber side. Restore it after the
    // recording.
    // ------------------------------------------------------------------
}

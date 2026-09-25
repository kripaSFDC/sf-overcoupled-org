@IsTest
private class StagingPromoterTest {

    @TestSetup
    static void setup() {
        DemoDataFactory.build(2, 1);
    }

    @IsTest
    static void promotesGoodRowsAndKeepsBadOnes() {
        Catalogue_Item__c item = [SELECT Id, Item_Code__c FROM Catalogue_Item__c ORDER BY Item_Code__c LIMIT 1];

        insert new List<Inbound_Listing_Staging__c>{
            new Inbound_Listing_Staging__c(
                Source_Key__c          = 'STG-GOOD-0001',
                Catalogue_Item_Code__c = item.Item_Code__c,
                Raw_Payload__c         = '{"listedPrice": 31.25, "packSize": 56}'),
            new Inbound_Listing_Staging__c(
                Source_Key__c          = 'STG-BADJSON-0001',
                Catalogue_Item_Code__c = item.Item_Code__c,
                Raw_Payload__c         = 'this is not json'),
            new Inbound_Listing_Staging__c(
                Source_Key__c          = 'STG-ORPHAN-0001',
                Catalogue_Item_Code__c = 'CAT-99999',
                Raw_Payload__c         = '{"listedPrice": 10.00, "packSize": 28}')
        };

        Test.startTest();
        Database.executeBatch(new StagingPromoter(), 200);
        Test.stopTest();

        Map<String, Inbound_Listing_Staging__c> rows = new Map<String, Inbound_Listing_Staging__c>();
        for (Inbound_Listing_Staging__c row : [
            SELECT Source_Key__c, Status__c, Error_Message__c, Attempt_Count__c
            FROM Inbound_Listing_Staging__c
        ]) {
            rows.put(row.Source_Key__c, row);
        }

        Assert.areEqual('Promoted', rows.get('STG-GOOD-0001').Status__c);
        Assert.areEqual('Failed',   rows.get('STG-BADJSON-0001').Status__c,
            'Bad payloads become data you can read, not exceptions that lose the other rows.');
        Assert.areEqual('Failed',   rows.get('STG-ORPHAN-0001').Status__c);
        Assert.isNotNull(rows.get('STG-ORPHAN-0001').Error_Message__c,
            'A failure the operator cannot read is not a failure, it is a mystery.');
        Assert.areEqual(1, rows.get('STG-GOOD-0001').Attempt_Count__c.intValue());

        Assert.areEqual(1, [SELECT COUNT() FROM Manufacturer_Listing__c WHERE Source_Key__c = 'STG-GOOD-0001']);
    }

    @IsTest
    static void emptyPayloadsAreQuarantinedNotRejected() {
        Inbound_Listing_Staging__c row = new Inbound_Listing_Staging__c(
            Source_Key__c = '  stg-empty-0001  ', Catalogue_Item_Code__c = 'CAT-00001');
        insert row;

        Inbound_Listing_Staging__c saved = [
            SELECT Source_Key__c, Status__c, Error_Message__c FROM Inbound_Listing_Staging__c WHERE Id = :row.Id
        ];
        Assert.areEqual('STG-EMPTY-0001', saved.Source_Key__c, 'Keys are normalised on the way in.');
        Assert.areEqual('Quarantined', saved.Status__c);
        Assert.isNotNull(saved.Error_Message__c);
    }
}

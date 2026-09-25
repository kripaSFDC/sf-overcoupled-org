@IsTest
private class DemoDataFactoryTest {

    @IsTest
    static void buildsTheCatalogue() {
        Test.startTest();
        Integer created = DemoDataFactory.build(5, 2);
        Test.stopTest();

        Assert.areEqual(8 + 5 + 10, created, 'Should create manufacturers, items and listings.');
        Assert.areEqual(5, [SELECT COUNT() FROM Catalogue_Item__c]);
        Assert.areEqual(10, [SELECT COUNT() FROM Manufacturer_Listing__c]);

        List<Catalogue_Item__c> repriced = DemoDataFactory.repriceAll(1.00);
        Assert.areEqual(5, repriced.size(), 'Every item should be in the reprice set.');
    }
}

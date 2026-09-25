@IsTest
private class AipUnitOfWorkTest {

    @IsTest
    static void commitsInDeclaredOrder() {
        DemoDataFactory.build(2, 1);
        List<Manufacturer_Listing__c> listings = [SELECT Id, Needs_Review__c FROM Manufacturer_Listing__c];

        AipUnitOfWork uow = new AipUnitOfWork(new List<SObjectType>{
            Manufacturer_Listing__c.SObjectType, Processed_Event__c.SObjectType
        });

        for (Manufacturer_Listing__c l : listings) {
            l.Needs_Review__c = true;
            uow.registerDirty(l);
        }
        uow.registerNew(new Processed_Event__c(Event_Uuid__c = 'uow-test-1', Handler__c = 'test'));

        Assert.areEqual(listings.size() + 1, uow.pendingCount());

        Test.startTest();
        uow.commitWork();
        Test.stopTest();

        Assert.areEqual(0, uow.pendingCount(), 'Committing should empty the unit of work.');
        Assert.areEqual(1, [SELECT COUNT() FROM Processed_Event__c WHERE Event_Uuid__c = 'uow-test-1']);
    }

    @IsTest
    static void mergesRepeatedDirtyRegistrations() {
        DemoDataFactory.build(1, 1);
        Manufacturer_Listing__c listing = [SELECT Id FROM Manufacturer_Listing__c LIMIT 1];

        AipUnitOfWork uow = new AipUnitOfWork(new List<SObjectType>{ Manufacturer_Listing__c.SObjectType });
        uow.registerDirty(new Manufacturer_Listing__c(Id = listing.Id, Needs_Review__c = true));
        uow.registerDirty(new Manufacturer_Listing__c(Id = listing.Id, Pack_Size__c = 56));

        Assert.areEqual(1, uow.pendingCount(),
            'Two actions touching one record must produce one update, not two.');

        uow.commitWork();

        Manufacturer_Listing__c saved = [SELECT Needs_Review__c, Pack_Size__c FROM Manufacturer_Listing__c WHERE Id = :listing.Id];
        Assert.isTrue(saved.Needs_Review__c, 'First registration should survive the merge.');
        Assert.areEqual(56, saved.Pack_Size__c.intValue(), 'Second registration should survive the merge.');
    }

    @IsTest
    static void refusesUndeclaredTypes() {
        AipUnitOfWork uow = new AipUnitOfWork(new List<SObjectType>{ Case.SObjectType });
        try {
            uow.registerNew(new Account(Name = 'Nope'));
            Assert.fail('Should have refused an undeclared SObject type.');
        } catch (TriggerHandlerException e) {
            Assert.isTrue(e.getMessage().contains('commit order'), e.getMessage());
        }
    }

    @IsTest
    static void systemModeRequiresAJustification() {
        try {
            new AipUnitOfWork(new List<SObjectType>{ Case.SObjectType }, AccessLevel.SYSTEM_MODE, '   ');
            Assert.fail('System mode without a justification should be refused.');
        } catch (TriggerHandlerException e) {
            Assert.isTrue(e.getMessage().contains('justification'), e.getMessage());
        }
    }
}

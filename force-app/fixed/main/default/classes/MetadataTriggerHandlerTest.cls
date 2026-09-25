@IsTest
private class MetadataTriggerHandlerTest {

    @IsTest
    static void bypassStopsEverythingForThatObject() {
        DemoDataFactory.build(2, 1);
        List<Catalogue_Item__c> items = [SELECT Id, Current_Price__c, Needs_Review__c FROM Catalogue_Item__c];

        MetadataTriggerHandler.bypass('Catalogue_Item__c');
        for (Catalogue_Item__c item : items) {
            item.Current_Price__c = item.Current_Price__c + 10;
        }
        update items;
        MetadataTriggerHandler.clearBypass('Catalogue_Item__c');

        for (Catalogue_Item__c item : [SELECT Needs_Review__c FROM Catalogue_Item__c]) {
            Assert.isFalse(item.Needs_Review__c,
                'Bypassed automation should not have stamped anything.');
        }
        Assert.isFalse(MetadataTriggerHandler.isBypassed('Catalogue_Item__c'));
    }

    @IsTest
    static void stampsRunWhenNotBypassed() {
        DemoDataFactory.build(2, 1);
        List<Catalogue_Item__c> items = [SELECT Id, Current_Price__c FROM Catalogue_Item__c];
        for (Catalogue_Item__c item : items) {
            item.Current_Price__c = item.Current_Price__c + 10;
        }
        update items;

        for (Catalogue_Item__c item : [SELECT Needs_Review__c, Last_Price_Change__c FROM Catalogue_Item__c]) {
            Assert.isTrue(item.Needs_Review__c, 'Before-update stamping should have run.');
            Assert.isNotNull(item.Last_Price_Change__c);
        }
    }

    @IsTest
    static void missingApexClassFailsByName() {
        Trigger_Action__mdt ghost = new Trigger_Action__mdt(
            DeveloperName       = 'Ghost_Action',
            Object_API_Name__c  = 'Catalogue_Item__c',
            Apex_Class_Name__c  = 'ThisClassDoesNotExist',
            Context__c          = 'AFTER_UPDATE',
            Order__c            = 999,
            Active__c           = true);
        try {
            MetadataTriggerHandler.instantiate(ghost);
            Assert.fail('Should have refused to instantiate a class that does not exist.');
        } catch (TriggerHandlerException e) {
            Assert.isTrue(e.getMessage().contains('ThisClassDoesNotExist'),
                'The error must name the class. ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('TriggerActionRegistryTest'),
                'And it should point at the test that would have caught it earlier.');
        }
    }

    @IsTest
    static void runOutsideATriggerIsRefused() {
        try {
            new MetadataTriggerHandler().run();
            Assert.fail('Should refuse to run outside a trigger.');
        } catch (TriggerHandlerException e) {
            Assert.isTrue(e.getMessage().contains('inside a trigger'), e.getMessage());
        }
    }

    @IsTest
    static void routesAreFilteredAndOrdered() {
        MetadataTriggerHandler.overrideActions = new List<Trigger_Action__mdt>{
            new Trigger_Action__mdt(DeveloperName = 'Second', Object_API_Name__c = 'Case',
                Apex_Class_Name__c = 'B', Context__c = 'BEFORE_INSERT', Order__c = 20, Active__c = true),
            new Trigger_Action__mdt(DeveloperName = 'First', Object_API_Name__c = 'Case',
                Apex_Class_Name__c = 'A', Context__c = 'BEFORE_INSERT', Order__c = 10, Active__c = true),
            new Trigger_Action__mdt(DeveloperName = 'Off', Object_API_Name__c = 'Case',
                Apex_Class_Name__c = 'C', Context__c = 'BEFORE_INSERT', Order__c = 5, Active__c = false)
        };
        MetadataTriggerHandler.resetCache();

        List<Trigger_Action__mdt> routes = MetadataTriggerHandler.routesFor('Case', 'BEFORE_INSERT');

        Assert.areEqual(2, routes.size(), 'Inactive rows must be excluded.');
        Assert.areEqual('A', routes[0].Apex_Class_Name__c, 'Order__c decides, not creation date.');
        Assert.areEqual('B', routes[1].Apex_Class_Name__c);
        Assert.areEqual(0, MetadataTriggerHandler.routesFor('Account', 'BEFORE_INSERT').size());

        MetadataTriggerHandler.overrideActions = null;
        MetadataTriggerHandler.resetCache();
    }

    @IsTest
    static void interfaceNamesAreMappedForErrorMessages() {
        Assert.areEqual('BeforeUpdate', MetadataTriggerHandler.interfaceFor('BEFORE_UPDATE'));
        Assert.areEqual('AfterUndelete', MetadataTriggerHandler.interfaceFor('AFTER_UNDELETE'));
        Assert.areEqual('Unknown', MetadataTriggerHandler.interfaceFor('NONSENSE'));
    }
}

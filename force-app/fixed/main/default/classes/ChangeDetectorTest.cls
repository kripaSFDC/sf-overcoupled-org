@IsTest
private class ChangeDetectorTest {

    @IsTest
    static void detectsOnlyWatchedFields() {
        Catalogue_Item__c current = new Catalogue_Item__c(Current_Price__c = 12, Status__c = 'Active');
        Catalogue_Item__c prior   = new Catalogue_Item__c(Current_Price__c = 10, Status__c = 'Active');

        Assert.isTrue(ChangeDetector.hasChanged(current, prior,
            new Set<SObjectField>{ Catalogue_Item__c.Current_Price__c }),
            'Price moved, so this should be true.');

        Assert.isFalse(ChangeDetector.hasChanged(current, prior,
            new Set<SObjectField>{ Catalogue_Item__c.Status__c }),
            'Status did not move, so this should be false - even though the record changed.');
    }

    @IsTest
    static void treatsMissingPriorAsChanged() {
        Assert.isTrue(ChangeDetector.hasChanged(new Catalogue_Item__c(), null,
            new Set<SObjectField>{ Catalogue_Item__c.Current_Price__c }),
            'An insert has no prior state, so everything counts as changed.');
    }

    @IsTest
    static void filtersTheBatchDownToWhatMoved() {
        DemoDataFactory.build(3, 1);
        List<Catalogue_Item__c> items = [SELECT Id, Current_Price__c FROM Catalogue_Item__c ORDER BY Item_Code__c];

        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (Catalogue_Item__c item : items) {
            oldMap.put(item.Id, item.clone(true, true, true, true));
        }
        items[0].Current_Price__c = items[0].Current_Price__c + 5;

        List<SObject> moved = ChangeDetector.changed(items, oldMap,
            new Set<SObjectField>{ Catalogue_Item__c.Current_Price__c });

        Assert.areEqual(1, moved.size(), 'Three records saved, one price moved, one record of work.');
        List<Id> movedIds = new List<Id>(ChangeDetector.changedIds(items, oldMap,
            new Set<SObjectField>{ Catalogue_Item__c.Current_Price__c }));
        Assert.areEqual(1, movedIds.size());
        Assert.areEqual(items[0].Id, movedIds[0]);
    }
}

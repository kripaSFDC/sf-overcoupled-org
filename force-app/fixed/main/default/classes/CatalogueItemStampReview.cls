/**
 * Before-update stamping. No DML, no SOQL - the record is already in memory and
 * about to be saved, so writing to it is free.
 *
 * In the broken package this same field was set by link 3, from a different
 * object, in a different transaction context, using two queries to get back to a
 * record it already had the Id of.
 */
public with sharing class CatalogueItemStampReview implements TriggerAction.BeforeUpdate {

    private static final Set<SObjectField> WATCHED = new Set<SObjectField>{
        Catalogue_Item__c.Current_Price__c,
        Catalogue_Item__c.Storage_Temp__c
    };

    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        for (SObject record : ChangeDetector.changed(newList, oldMap, WATCHED)) {
            Catalogue_Item__c item = (Catalogue_Item__c) record;
            item.Needs_Review__c = true;
            item.Last_Price_Change__c = System.now();
        }
    }
}

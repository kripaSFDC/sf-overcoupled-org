/**
 * Link 1 of 3.
 *
 * Written in year one, by someone solving exactly one problem: "when the price
 * changes, push it to the listings." It worked. It still works, for one record.
 */
trigger CatalogueItemTrigger on Catalogue_Item__c (after update) {
    CatalogueItemTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
}

/**
 * Link 2 of 3.
 *
 * Added in year two by a different team, for a good reason: compliance wanted a
 * case raised whenever a listed price moved, so somebody had to sign it off.
 * Nobody asked what was already updating listings.
 */
trigger ManufacturerListingTrigger on Manufacturer_Listing__c (after update) {
    ManufacturerListingTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
}

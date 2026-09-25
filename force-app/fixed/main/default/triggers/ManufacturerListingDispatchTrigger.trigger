/**
 * One trigger, every context, one line of logic - and that line is a lookup, not
 * a decision. What actually runs is a row in Trigger_Action__mdt, which means an
 * admin can answer "what happens when this object is saved?" from a report.
 */
trigger ManufacturerListingDispatchTrigger on Manufacturer_Listing__c (
    before insert, after insert,
    before update, after update,
    before delete, after delete,
    after undelete
) {
    new MetadataTriggerHandler().run();
}

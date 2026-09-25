// The 2am switch.
//
// Two ways to stop automation without a deployment:
//
//   1. In code, for one transaction - MetadataTriggerHandler.bypass(). This is
//      what a data-load script uses.
//   2. By permission, for one user, until you take it away - assign the
//      AIP_Automation_Bypass permission set. Setup > Permission Sets > assign.
//      No deploy, no code change, effective on the next save.
//
// Number 2 is the one that matters. The broken package has no equivalent: to
// stop that chain you comment out a trigger and deploy to production, which is
// the last thing anyone wants to be doing during an incident.

List<Catalogue_Item__c> items = [
    SELECT Id, Current_Price__c, Needs_Review__c FROM Catalogue_Item__c LIMIT 5
];
for (Catalogue_Item__c item : items) {
    item.Needs_Review__c = false;
}
update items;

MetadataTriggerHandler.bypass('Catalogue_Item__c');
for (Catalogue_Item__c item : items) {
    item.Current_Price__c = item.Current_Price__c + 1;
}
update items;
MetadataTriggerHandler.clearBypass('Catalogue_Item__c');

Integer stillClean = [
    SELECT COUNT() FROM Catalogue_Item__c WHERE Id IN :items AND Needs_Review__c = false
];
System.debug(LoggingLevel.INFO,
    stillClean + ' of ' + items.size() + ' records were saved with automation bypassed.');

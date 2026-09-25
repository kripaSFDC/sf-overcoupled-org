// Wipes the demo data so you can run the whole thing again between takes.
// Run this, then 01-seed.apex.

MetadataTriggerHandler.bypass('Catalogue_Item__c');
MetadataTriggerHandler.bypass('Manufacturer_Listing__c');
MetadataTriggerHandler.bypass('Case');

delete [SELECT Id FROM Case WHERE Catalogue_Item__c != null];
delete [SELECT Id FROM Manufacturer_Listing__c];
delete [SELECT Id FROM Catalogue_Item__c];
delete [SELECT Id FROM Processed_Event__c];
delete [SELECT Id FROM Inbound_Listing_Staging__c];
delete [SELECT Id FROM Account WHERE Name LIKE 'Manufacturer %'];

System.debug(LoggingLevel.INFO, 'Reset complete.');

// Run a few seconds after 03-prove-it.apex.
//
// The platform event subscriber has run in its own transaction, with its own
// limits, as its own user. If it had failed, the price change would still be
// committed and you would have a ledger row missing rather than an outage.

Integer items     = [SELECT COUNT() FROM Catalogue_Item__c];
Integer flagged   = [SELECT COUNT() FROM Catalogue_Item__c WHERE Needs_Review__c = true];
Integer listings  = [SELECT COUNT() FROM Manufacturer_Listing__c WHERE Needs_Review__c = true];
Integer cases     = [SELECT COUNT() FROM Case WHERE Automation_Source__c = 'CataloguePricingService'];
Integer ledger    = [SELECT COUNT() FROM Processed_Event__c];

System.debug(LoggingLevel.INFO, '=================================================');
System.debug(LoggingLevel.INFO, 'Catalogue items:        ' + items);
System.debug(LoggingLevel.INFO, 'Flagged for review:     ' + flagged);
System.debug(LoggingLevel.INFO, 'Listings repriced:      ' + listings);
System.debug(LoggingLevel.INFO, 'Cases raised:           ' + cases);
System.debug(LoggingLevel.INFO, 'Events in the ledger:   ' + ledger);
System.debug(LoggingLevel.INFO, '=================================================');
System.debug(LoggingLevel.INFO, 'Run 03-prove-it.apex again. The ledger count will not double.');

// ---------------------------------------------------------------------------
// RUN THIS WITH force-app/broken DEPLOYED.
//
// A price rise across the catalogue. Every supplier does this. It is not an
// edge case, it is a Tuesday.
//
// Expected output:
//   System.LimitException: Too many SOQL queries: 101
//
// Say the number out loud. It failed on catalogue item 101 of 200. Ninety-nine
// items had already been repriced and committed nothing, because the whole
// transaction rolls back - so the operator sees an error, retries, and gets the
// same error, and there is no partial progress to tell them how far it got.
// ---------------------------------------------------------------------------

List<Catalogue_Item__c> items = DemoDataFactory.repriceAll(2.50);
System.debug(LoggingLevel.INFO, 'Repricing ' + items.size() + ' catalogue items...');

update items;

System.debug(LoggingLevel.INFO, 'If you are reading this line, something is wrong with the demo.');

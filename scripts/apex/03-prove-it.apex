// ---------------------------------------------------------------------------
// RUN THIS WITH force-app/fixed DEPLOYED AND force-app/broken RETIRED.
//
// The identical save. Watch the query count.
// ---------------------------------------------------------------------------

List<Catalogue_Item__c> items = DemoDataFactory.repriceAll(2.50);

Integer queriesBefore = Limits.getQueries();
Integer dmlBefore     = Limits.getDmlStatements();

update items;

System.debug(LoggingLevel.INFO, '=================================================');
System.debug(LoggingLevel.INFO, 'Records saved:  ' + items.size());
System.debug(LoggingLevel.INFO, 'Queries used:   ' + (Limits.getQueries() - queriesBefore) + ' / 100');
System.debug(LoggingLevel.INFO, 'DML used:       ' + (Limits.getDmlStatements() - dmlBefore) + ' / 150');
System.debug(LoggingLevel.INFO, '=================================================');
System.debug(LoggingLevel.INFO, 'The listings have not moved yet. That is the point.');
System.debug(LoggingLevel.INFO, 'The price change is committed. The consequences are in flight.');
System.debug(LoggingLevel.INFO, 'Wait a few seconds, then run 04-verify.apex.');

// 200 catalogue items, 3 manufacturer listings each, 8 manufacturers.
//
// 200 is not an arbitrary number. It is the chunk size the platform hands a
// trigger, and 101 is the SOQL ceiling. One query per record inside a loop
// therefore survives a load of 100 and dies on a load of 200 - which is precisely
// why this class of bug reaches production with a green test suite behind it.

Integer created = DemoDataFactory.build(200, 3);

System.debug(LoggingLevel.INFO, 'Created ' + created + ' records.');
System.debug(LoggingLevel.INFO, 'Catalogue items: ' + [SELECT COUNT() FROM Catalogue_Item__c]);
System.debug(LoggingLevel.INFO, 'Listings:        ' + [SELECT COUNT() FROM Manufacturer_Listing__c]);

// The inbox.
//
// Three rows arrive from a manufacturer feed: one good, one with a malformed
// payload, one referring to a catalogue item that does not exist yet.
//
// In the broken model the integration wrote straight to Manufacturer_Listing__c,
// which fired the chain, which meant a malformed row from a supplier could take
// down a price change nobody in that supplier's company had ever heard of.
//
// Here, all three land. None of them are rejected. Two fail promotion and stay
// on the inbox with a readable reason, where somebody can fix the catalogue and
// let them retry.

String goodCode = [SELECT Item_Code__c FROM Catalogue_Item__c ORDER BY Item_Code__c LIMIT 1].Item_Code__c;

insert new List<Inbound_Listing_Staging__c>{
    new Inbound_Listing_Staging__c(
        Source_Key__c = 'FEED-' + System.now().getTime() + '-A',
        Catalogue_Item_Code__c = goodCode,
        Raw_Payload__c = '{"listedPrice": 44.90, "packSize": 84}'),
    new Inbound_Listing_Staging__c(
        Source_Key__c = 'FEED-' + System.now().getTime() + '-B',
        Catalogue_Item_Code__c = goodCode,
        Raw_Payload__c = '{"listedPrice": not-a-number}'),
    new Inbound_Listing_Staging__c(
        Source_Key__c = 'FEED-' + System.now().getTime() + '-C',
        Catalogue_Item_Code__c = 'CAT-99999',
        Raw_Payload__c = '{"listedPrice": 12.00, "packSize": 28}')
};

Database.executeBatch(new StagingPromoter(), 200);

System.debug(LoggingLevel.INFO,
    'Batch queued. Give it a moment, then look at Inbound Listing Staging in the UI ' +
    'and read the Error Message column. Nothing was lost.');

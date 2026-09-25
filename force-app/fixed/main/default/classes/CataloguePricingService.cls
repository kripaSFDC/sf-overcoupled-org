/**
 * Where the actual business rule lives now: one class, callable from a trigger
 * action, a queueable, a batch job, an API or a test, with no knowledge of which
 * one called it.
 *
 * The query count here is FOUR, and it is four whether the batch holds one
 * repricing or two hundred. Count them as you read - that number is the whole
 * point of the episode and it is worth pointing at on screen.
 */
public with sharing class CataloguePricingService {

    public class Repricing {
        public Id catalogueItemId;
        public Decimal newPrice;
        public Decimal previousPrice;
        public Repricing(Id catalogueItemId, Decimal newPrice, Decimal previousPrice) {
            this.catalogueItemId = catalogueItemId;
            this.newPrice = newPrice;
            this.previousPrice = previousPrice;
        }
    }

    public class Outcome {
        public Integer listingsUpdated = 0;
        public Integer casesRaised = 0;
        public Integer queriesUsed = 0;
    }

    public Outcome applyRepricings(List<Repricing> repricings, AipUnitOfWork uow) {
        return applyRepricings(repricings, uow, AccessLevel.USER_MODE);
    }

    public Outcome applyRepricings(List<Repricing> repricings, AipUnitOfWork uow, AccessLevel level) {
        Outcome outcome = new Outcome();
        Integer queriesBefore = Limits.getQueries();

        if (repricings == null || repricings.isEmpty()) {
            return outcome;
        }

        Map<Id, Repricing> byItemId = new Map<Id, Repricing>();
        for (Repricing r : repricings) {
            byItemId.put(r.catalogueItemId, r);
        }

        CatalogueItemSelector itemSelector = new CatalogueItemSelector();
        ManufacturerListingSelector listingSelector = new ManufacturerListingSelector();
        CaseSelector caseSelector = new CaseSelector();
        itemSelector.accessLevel = level;
        listingSelector.accessLevel = level;
        caseSelector.accessLevel = level;

        // Query 1 - the parents, all of them, once.
        Map<Id, Catalogue_Item__c> items = itemSelector.mapByIds(byItemId.keySet());

        // Query 2 - every listing under every parent, once.
        Map<Id, List<Manufacturer_Listing__c>> listingsByItem =
            listingSelector.mapByCatalogueItemIds(byItemId.keySet());

        Set<Id> allListingIds = new Set<Id>();
        for (List<Manufacturer_Listing__c> group : listingsByItem.values()) {
            for (Manufacturer_Listing__c listing : group) {
                allListingIds.add(listing.Id);
            }
        }

        // Query 3 - "is a case already open?", asked once for the whole batch.
        Set<Id> listingsWithOpenCases = caseSelector.listingIdsWithOpenCases(allListingIds);

        Id priceChangeRt = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Price_Change')
            .getRecordTypeId();

        for (Id itemId : byItemId.keySet()) {
            Repricing repricing = byItemId.get(itemId);
            Catalogue_Item__c item = items.get(itemId);
            if (item == null) {
                continue;
            }

            List<Manufacturer_Listing__c> listings =
                listingsByItem.containsKey(itemId)
                    ? listingsByItem.get(itemId)
                    : new List<Manufacturer_Listing__c>();

            for (Manufacturer_Listing__c listing : listings) {
                // Register a fresh sObject carrying ONLY what we intend to change.
                // The queried record also holds Catalogue_Item__c - a non-reparentable
                // master-detail, createable but never updateable - and including it in
                // an update payload gets the whole DML refused. A unit of work should
                // carry the fields it means to write and nothing else.
                uow.registerDirty(new Manufacturer_Listing__c(
                    Id              = listing.Id,
                    Listed_Price__c = repricing.newPrice,
                    Needs_Review__c = true,
                    Last_Synced__c  = System.now()
                ));
                outcome.listingsUpdated++;

                if (listingsWithOpenCases.contains(listing.Id)) {
                    continue;
                }

                uow.registerNew(new Case(
                    RecordTypeId            = priceChangeRt,
                    Subject                 = 'Price change: ' + item.Item_Code__c,
                    Description             = 'Catalogue price moved from ' + repricing.previousPrice +
                                              ' to ' + repricing.newPrice + '.',
                    Status                  = 'New',
                    Origin                  = 'Internal',
                    Sub_Status__c           = 'Awaiting Manufacturer',
                    Catalogue_Item__c       = item.Id,
                    Manufacturer_Listing__c = listing.Id,
                    Automation_Source__c    = 'CataloguePricingService'
                ));
                outcome.casesRaised++;
            }
        }

        outcome.queriesUsed = Limits.getQueries() - queriesBefore;
        return outcome;
    }
}

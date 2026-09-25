/**
 * The far side of the seam.
 *
 * This runs in its own transaction with its own limits. If it fails, the price
 * change that caused it has already committed and stays committed - which is the
 * behaviour you want, and the opposite of what the broken chain does.
 *
 * System mode is used here on purpose and it is the only place in the rebuilt
 * package that does. Platform event subscribers run as the Automated Process
 * user, which holds essentially no object permissions, so user-mode DML would
 * fail for reasons that have nothing to do with security intent. The exception is
 * named, justified and greppable. That is the difference between an exception and
 * a habit.
 */
public with sharing class RepricingEventHandler {

    private static final String HANDLER = 'RepricingEventHandler';

    public static void handle(List<Listing_Repricing__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        Set<String> uuids = new Set<String>();
        for (Listing_Repricing__e e : events) {
            uuids.add(e.Event_Uuid__c);
        }

        // Query 1 - have we already applied any of these?
        Set<String> alreadyDone = IdempotencyLedger.alreadyProcessed(uuids);

        List<CataloguePricingService.Repricing> work = new List<CataloguePricingService.Repricing>();
        Set<String> toLedger = new Set<String>();

        for (Listing_Repricing__e e : events) {
            if (alreadyDone.contains(e.Event_Uuid__c) || toLedger.contains(e.Event_Uuid__c)) {
                continue;
            }
            toLedger.add(e.Event_Uuid__c);
            work.add(new CataloguePricingService.Repricing(
                (Id) e.Catalogue_Item_Id__c, e.New_Price__c, e.Previous_Price__c));
        }

        if (work.isEmpty()) {
            return;
        }

        AipUnitOfWork uow = new AipUnitOfWork(
            new List<SObjectType>{
                Manufacturer_Listing__c.SObjectType,
                Case.SObjectType,
                Processed_Event__c.SObjectType
            },
            AccessLevel.SYSTEM_MODE,
            'Platform event subscriber runs as Automated Process, which holds no object ' +
            'permissions. Access is constrained by the event payload, not by the running user.');

        // Queries 2, 3 and 4 - all inside the service, all set-based.
        CataloguePricingService.Outcome outcome =
            new CataloguePricingService().applyRepricings(work, uow, AccessLevel.SYSTEM_MODE);

        uow.registerNew(IdempotencyLedger.entriesFor(toLedger, HANDLER));
        uow.commitWork();

        System.debug(LoggingLevel.INFO,
            'Repricing applied. events=' + events.size() +
            ' listings=' + outcome.listingsUpdated +
            ' cases=' + outcome.casesRaised +
            ' queriesInService=' + outcome.queriesUsed +
            ' totalQueries=' + Limits.getQueries());
    }
}

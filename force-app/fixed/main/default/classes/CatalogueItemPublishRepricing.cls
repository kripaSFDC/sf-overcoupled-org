/**
 * Replaces CatalogueItemTriggerHandler.
 *
 * Compare them side by side on camera. The broken one queries, mutates children
 * and starts a cascade. This one answers one question - did the price actually
 * move - and publishes a fact. Zero SOQL. One DML, whether you saved one record
 * or two hundred.
 *
 * The cascade does not get shorter here. It gets CUT. Whatever happens next
 * happens in its own transaction, with its own limits, and if it fails it fails
 * on its own without taking the price change down with it.
 */
public with sharing class CatalogueItemPublishRepricing implements TriggerAction.AfterUpdate {

    private static final Set<SObjectField> WATCHED = new Set<SObjectField>{
        Catalogue_Item__c.Current_Price__c
    };

    public void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<SObject> moved = ChangeDetector.changed(newList, oldMap, WATCHED);
        if (moved.isEmpty()) {
            return;
        }

        List<Listing_Repricing__e> events = new List<Listing_Repricing__e>();
        String requestId = System.Request.getCurrent().getRequestId();

        for (SObject record : moved) {
            Catalogue_Item__c item  = (Catalogue_Item__c) record;
            Catalogue_Item__c prior = (Catalogue_Item__c) oldMap.get(item.Id);

            events.add(new Listing_Repricing__e(
                // Deterministic, not random. A retry of the same save produces the
                // same UUID, so the ledger on the other side recognises it and does
                // nothing. Idempotency is a property of the key, not of the code.
                Event_Uuid__c        = requestId + ':' + item.Id,
                Catalogue_Item_Id__c = item.Id,
                New_Price__c         = item.Current_Price__c,
                Previous_Price__c    = prior.Current_Price__c
            ));
        }

        EventBus.publish(events);
    }
}

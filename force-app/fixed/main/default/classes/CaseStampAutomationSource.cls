/**
 * Replaces CaseTriggerHandler - and notice what is missing: it does not write
 * back to Catalogue Item. That single deletion is what opens the cycle.
 *
 * The merchandising team still gets their flag. It is set in before-update on the
 * catalogue item itself, by CatalogueItemStampReview, at the moment the price
 * changes - which is where it always belonged.
 */
public with sharing class CaseStampAutomationSource implements TriggerAction.BeforeInsert {

    public void beforeInsert(List<SObject> newList) {
        Integer depth = MetadataTriggerHandler.currentDepth('Case', 'BEFORE_INSERT');
        for (SObject record : newList) {
            Case c = (Case) record;
            if (String.isBlank(c.Automation_Source__c)) {
                c.Automation_Source__c = 'Manual';
            }
            c.Trigger_Depth__c = depth;
            if (String.isBlank(c.Sub_Status__c)) {
                c.Sub_Status__c = 'Awaiting Manufacturer';
            }
        }
    }
}

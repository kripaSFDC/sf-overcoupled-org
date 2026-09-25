public inherited sharing class CaseSelector extends SelectorBase {

    public override SObjectType getSObjectType() {
        return Case.SObjectType;
    }

    public override List<SObjectField> getFields() {
        return new List<SObjectField>{
            Case.Id,
            Case.CaseNumber,
            Case.Subject,
            Case.Status,
            Case.IsClosed,
            Case.RecordTypeId,
            Case.Catalogue_Item__c,
            Case.Manufacturer_Listing__c,
            Case.Sub_Status__c,
            Case.Automation_Source__c
        };
    }

    /**
     * "Is there already an open case?" - asked once, for the whole batch,
     * instead of once per listing.
     */
    public Set<Id> listingIdsWithOpenCases(Set<Id> listingIds) {
        Set<Id> out = new Set<Id>();
        if (listingIds == null || listingIds.isEmpty()) {
            return out;
        }
        for (Case row : (List<Case>) run(
                'SELECT Id, Manufacturer_Listing__c FROM Case ' +
                'WHERE Manufacturer_Listing__c IN :listingIds AND IsClosed = false',
                new Map<String, Object>{ 'listingIds' => listingIds })) {
            out.add(row.Manufacturer_Listing__c);
        }
        return out;
    }
}

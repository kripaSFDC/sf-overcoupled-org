public inherited sharing class ManufacturerListingSelector extends SelectorBase {

    public override SObjectType getSObjectType() {
        return Manufacturer_Listing__c.SObjectType;
    }

    public override List<SObjectField> getFields() {
        return new List<SObjectField>{
            Manufacturer_Listing__c.Id,
            Manufacturer_Listing__c.Name,
            Manufacturer_Listing__c.Catalogue_Item__c,
            Manufacturer_Listing__c.Manufacturer__c,
            Manufacturer_Listing__c.Listed_Price__c,
            Manufacturer_Listing__c.Pack_Size__c,
            Manufacturer_Listing__c.Compliance_Status__c,
            Manufacturer_Listing__c.Needs_Review__c,
            Manufacturer_Listing__c.Source_Key__c,
            Manufacturer_Listing__c.Last_Synced__c
        };
    }

    /**
     * The single most important method in the rebuilt package.
     *
     * One query for every parent in the batch, grouped in memory. The broken
     * version asked this same question once per record, and that is the entire
     * difference between 1 query and 200.
     */
    public Map<Id, List<Manufacturer_Listing__c>> mapByCatalogueItemIds(Set<Id> itemIds) {
        Map<Id, List<Manufacturer_Listing__c>> out = new Map<Id, List<Manufacturer_Listing__c>>();
        if (itemIds == null || itemIds.isEmpty()) {
            return out;
        }
        for (Manufacturer_Listing__c row : (List<Manufacturer_Listing__c>) run(
                baseQuery() + ' WHERE Catalogue_Item__c IN :itemIds ORDER BY Catalogue_Item__c',
                new Map<String, Object>{ 'itemIds' => itemIds })) {
            if (!out.containsKey(row.Catalogue_Item__c)) {
                out.put(row.Catalogue_Item__c, new List<Manufacturer_Listing__c>());
            }
            out.get(row.Catalogue_Item__c).add(row);
        }
        return out;
    }
}

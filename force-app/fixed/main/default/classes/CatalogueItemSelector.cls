public inherited sharing class CatalogueItemSelector extends SelectorBase {

    public override SObjectType getSObjectType() {
        return Catalogue_Item__c.SObjectType;
    }

    public override List<SObjectField> getFields() {
        return new List<SObjectField>{
            Catalogue_Item__c.Id,
            Catalogue_Item__c.Name,
            Catalogue_Item__c.Item_Code__c,
            Catalogue_Item__c.Current_Price__c,
            Catalogue_Item__c.Storage_Temp__c,
            Catalogue_Item__c.Status__c,
            Catalogue_Item__c.Needs_Review__c,
            Catalogue_Item__c.Last_Price_Change__c
        };
    }

    public Map<Id, Catalogue_Item__c> mapByIds(Set<Id> ids) {
        return new Map<Id, Catalogue_Item__c>((List<Catalogue_Item__c>) selectByIds(ids));
    }

    public Map<String, Catalogue_Item__c> mapByItemCodes(Set<String> codes) {
        Map<String, Catalogue_Item__c> out = new Map<String, Catalogue_Item__c>();
        if (codes == null || codes.isEmpty()) {
            return out;
        }
        for (Catalogue_Item__c row : (List<Catalogue_Item__c>) run(
                baseQuery() + ' WHERE Item_Code__c IN :codes',
                new Map<String, Object>{ 'codes' => codes })) {
            out.put(row.Item_Code__c, row);
        }
        return out;
    }
}

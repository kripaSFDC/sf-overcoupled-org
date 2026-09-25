/**
 * Builds a catalogue big enough to hurt.
 *
 * Defaults are 200 items with 3 listings each, because 200 is the chunk size the
 * platform hands a trigger and 101 is the query ceiling. One query per record in
 * a loop dies on record 101, which means it dies on a load of 200 and survives a
 * load of 100 - and that is exactly why this kind of bug reaches production. It
 * passes every test anyone bothered to write.
 */
public with sharing class DemoDataFactory {

    private static final List<String> FORMS = new List<String>{
        'Amoxicillin 500mg Caps', 'Metformin 850mg Tabs', 'Salbutamol 100mcg Inhaler',
        'Atorvastatin 20mg Tabs', 'Insulin Glargine 100u/mL', 'Paracetamol 500mg Tabs',
        'Omeprazole 20mg Caps', 'Sertraline 50mg Tabs', 'Influenza Vaccine 0.5mL',
        'Amlodipine 5mg Tabs'
    };
    private static final List<String> TEMPS = new List<String>{
        'Ambient', 'Cold Chain 2-8C', 'Frozen -20C', 'Controlled Substance'
    };

    public static Integer build(Integer itemCount, Integer listingsPerItem) {
        List<Account> manufacturers = new List<Account>();
        for (Integer i = 0; i < 8; i++) {
            manufacturers.add(new Account(Name = 'Manufacturer ' + String.valueOf(i + 1).leftPad(2, '0')));
        }
        insert manufacturers;

        List<Catalogue_Item__c> items = new List<Catalogue_Item__c>();
        for (Integer i = 0; i < itemCount; i++) {
            items.add(new Catalogue_Item__c(
                Name             = FORMS[Math.mod(i, FORMS.size())] + ' #' + (i + 1),
                Item_Code__c     = 'CAT-' + String.valueOf(i + 1).leftPad(5, '0'),
                Current_Price__c = 5 + Math.mod(i, 90) + 0.50,
                Storage_Temp__c  = TEMPS[Math.mod(i, TEMPS.size())],
                Status__c        = 'Active'
            ));
        }
        insert items;

        List<Manufacturer_Listing__c> listings = new List<Manufacturer_Listing__c>();
        for (Integer i = 0; i < items.size(); i++) {
            for (Integer j = 0; j < listingsPerItem; j++) {
                listings.add(new Manufacturer_Listing__c(
                    Catalogue_Item__c    = items[i].Id,
                    Manufacturer__c      = manufacturers[Math.mod(i + j, manufacturers.size())].Id,
                    Listed_Price__c      = items[i].Current_Price__c,
                    Pack_Size__c         = 28 * (j + 1),
                    Compliance_Status__c = 'Compliant',
                    Source_Key__c        = items[i].Item_Code__c + '|M' + (j + 1),
                    Last_Synced__c       = System.now()
                ));
            }
        }
        insert listings;

        return manufacturers.size() + items.size() + listings.size();
    }

    /** Bumps every catalogue price. This is the save that decides the episode. */
    public static List<Catalogue_Item__c> repriceAll(Decimal delta) {
        List<Catalogue_Item__c> items = [
            SELECT Id, Current_Price__c FROM Catalogue_Item__c ORDER BY Item_Code__c
        ];
        for (Catalogue_Item__c item : items) {
            item.Current_Price__c = item.Current_Price__c + delta;
        }
        return items;
    }
}

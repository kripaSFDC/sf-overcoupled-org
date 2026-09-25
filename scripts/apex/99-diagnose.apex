// ============================================================
//  Diagnostic for: "fields being inaccessible on Manufacturer_Listing__c"
//  Run:  sf apex run -f scripts/apex/99-diagnose.apex
//  Then read the DEBUG lines starting with ###
// ============================================================

User me = [SELECT Id, Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug(LoggingLevel.ERROR, '### running as: ' + me.Name + ' / profile: ' + me.Profile.Name);
System.debug(LoggingLevel.ERROR, '### fixed package deployed? MetadataTriggerHandler = '
    + (Type.forName('MetadataTriggerHandler') != null));

// ---- object level
Schema.DescribeSObjectResult objD = Manufacturer_Listing__c.SObjectType.getDescribe();
System.debug(LoggingLevel.ERROR, '### object  updateable=' + objD.isUpdateable()
    + ' createable=' + objD.isCreateable() + ' accessible=' + objD.isAccessible());

// ---- every field on the object
Map<String, Schema.SObjectField> fmap = objD.fields.getMap();
for (String k : new List<String>(fmap.keySet())) {
    Schema.DescribeFieldResult f = fmap.get(k).getDescribe();
    if (!f.isCustom()) { continue; }
    System.debug(LoggingLevel.ERROR, '### field ' + f.getName()
        + '  accessible=' + f.isAccessible()
        + '  updateable=' + f.isUpdateable()
        + '  createable=' + f.isCreateable());
}

// ---- A: can we update a listing DIRECTLY, outside any trigger?
Manufacturer_Listing__c l = [SELECT Id, Listed_Price__c FROM Manufacturer_Listing__c LIMIT 1];
try {
    update new Manufacturer_Listing__c(Id = l.Id, Needs_Review__c = true, Last_Synced__c = System.now());
    System.debug(LoggingLevel.ERROR, '### A: direct listing update SUCCEEDED');
} catch (DmlException e) {
    System.debug(LoggingLevel.ERROR, '### A: direct listing update FAILED: ' + e.getMessage());
    for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug(LoggingLevel.ERROR, '###    status=' + e.getDmlStatusCode(i)
            + ' fields=' + e.getDmlFieldNames(i));
    }
}

// ---- B: the real thing - update the parent and let the chain run
Catalogue_Item__c item = [SELECT Id, Current_Price__c FROM Catalogue_Item__c LIMIT 1];
try {
    item.Current_Price__c = (item.Current_Price__c == null ? 1 : item.Current_Price__c) + 1;
    update item;
    System.debug(LoggingLevel.ERROR, '### B: parent update SUCCEEDED - chain ran clean');
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '### B: parent update FAILED: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, '###    message: ' + e.getMessage());
    if (e instanceof DmlException) {
        DmlException d = (DmlException) e;
        for (Integer i = 0; i < d.getNumDml(); i++) {
            System.debug(LoggingLevel.ERROR, '###    status=' + d.getDmlStatusCode(i)
                + ' fields=' + d.getDmlFieldNames(i));
        }
    }
}

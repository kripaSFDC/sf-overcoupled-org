/**
 * The promoter.
 *
 * The lesson from the real remediation, stated plainly: a staging object on its
 * own does not fix anything. What fixes it is that promotion is
 *
 *   - idempotent   : upsert on an external id, so replaying a file is harmless
 *   - bounded      : three attempts, then it stops trying and waits for a human
 *   - non-throwing : a bad row becomes Failed data, not an exception that takes
 *                    the other 199 rows down with it
 *
 * Get those three wrong and staging is just a slower way to have the same outage.
 */
public with sharing class StagingPromoter implements Database.Batchable<SObject>, Database.Stateful {

    private static final Integer MAX_ATTEMPTS = 3;

    public Integer promoted = 0;
    public Integer failed = 0;

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        Integer maxAttempts = MAX_ATTEMPTS;
        return Database.getQueryLocator([
            SELECT Id, Source_Key__c, Catalogue_Item_Code__c, Raw_Payload__c,
                   Status__c, Attempt_Count__c, Error_Message__c
            FROM Inbound_Listing_Staging__c
            WHERE Status__c IN ('New', 'Failed')
              AND Attempt_Count__c < :maxAttempts
            ORDER BY CreatedDate
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Inbound_Listing_Staging__c> rows) {
        Set<String> codes = new Set<String>();
        for (Inbound_Listing_Staging__c row : rows) {
            if (String.isNotBlank(row.Catalogue_Item_Code__c)) {
                codes.add(row.Catalogue_Item_Code__c);
            }
        }

        // One query for the whole chunk.
        Map<String, Catalogue_Item__c> itemsByCode =
            new CatalogueItemSelector().mapByItemCodes(codes);

        List<Manufacturer_Listing__c> toUpsert = new List<Manufacturer_Listing__c>();
        List<Inbound_Listing_Staging__c> toSave = new List<Inbound_Listing_Staging__c>();

        for (Inbound_Listing_Staging__c row : rows) {
            row.Attempt_Count__c = (row.Attempt_Count__c == null ? 0 : row.Attempt_Count__c) + 1;
            row.Processed_At__c = System.now();

            Catalogue_Item__c parent = itemsByCode.get(row.Catalogue_Item_Code__c);
            if (parent == null) {
                row.Status__c = 'Failed';
                row.Error_Message__c = 'No catalogue item with code ' + row.Catalogue_Item_Code__c +
                                       '. Row kept - fix the catalogue and it will retry.';
                toSave.add(row);
                failed++;
                continue;
            }

            try {
                Map<String, Object> payload =
                    (Map<String, Object>) JSON.deserializeUntyped(row.Raw_Payload__c);

                toUpsert.add(new Manufacturer_Listing__c(
                    Source_Key__c        = row.Source_Key__c,
                    Catalogue_Item__c    = parent.Id,
                    Listed_Price__c      = toDecimal(payload.get('listedPrice')),
                    Pack_Size__c         = toDecimal(payload.get('packSize')),
                    Compliance_Status__c = 'Pending Review',
                    Last_Synced__c       = System.now()
                ));
                row.Status__c = 'Promoted';
                row.Error_Message__c = null;
                toSave.add(row);
                promoted++;

            } catch (Exception e) {
                row.Status__c = 'Failed';
                row.Error_Message__c = trim(e.getTypeName() + ': ' + e.getMessage());
                toSave.add(row);
                failed++;
            }
        }

        if (!toUpsert.isEmpty()) {
            SecureDb.doUpsert(toUpsert, Manufacturer_Listing__c.Source_Key__c, false,
                              AccessLevel.SYSTEM_MODE);
        }
        if (!toSave.isEmpty()) {
            SecureDb.doUpdateAsSystem(toSave, false,
                'Batch promoter updates its own inbox rows regardless of the running user.');
        }
    }

    public void finish(Database.BatchableContext ctx) {
        System.debug(LoggingLevel.INFO,
            'StagingPromoter finished. promoted=' + promoted + ' failed=' + failed);
    }

    private Decimal toDecimal(Object value) {
        if (value == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    private String trim(String value) {
        return value.length() > 255 ? value.substring(0, 255) : value;
    }
}

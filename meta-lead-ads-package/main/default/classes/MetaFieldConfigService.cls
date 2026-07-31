/**
 * MetaFieldConfigService.cls
 *
 * Centralised service that reads org-specific Lead field API names
 * from Meta_Integration_Settings__mdt.
 *
 * All Apex classes call this instead of hardcoding purpl__ field names.
 * Admins configure the field APIs once via the PurplSync Settings LWC.
 */
public without sharing class MetaFieldConfigService {

    // Cached config per transaction
    private static FieldConfig cachedConfig = null;

    public class FieldConfig {
        public String projectFieldApi;        // e.g. Project_Interested__c
        public String utmSourceFieldApi;      // e.g. utm_source__c
        public String utmCampaignFieldApi;    // e.g. utm_campaign__c
        public String utmMediumFieldApi;      // e.g. utm_medium__c
        public String utmTermFieldApi;        // e.g. utm_term__c
        public String utmContentFieldApi;     // e.g. utm_content__c
        public String customLeadSourceFieldApi; // e.g. Lead_Source__c (custom)

        public FieldConfig() {
            this.projectFieldApi          = '';
            this.utmSourceFieldApi        = '';
            this.utmCampaignFieldApi      = '';
            this.utmMediumFieldApi        = '';
            this.utmTermFieldApi          = '';
            this.utmContentFieldApi       = '';
            this.customLeadSourceFieldApi = '';
        }
    }

    /**
     * Returns the field configuration. Cached per transaction for performance.
     */
    public static FieldConfig getConfig() {
        if (cachedConfig != null) return cachedConfig;

        cachedConfig = new FieldConfig();
        try {
            List<SObject> rows = Database.query(
                'SELECT Project_Field_API__c, UTM_Source_Field_API__c, UTM_Campaign_Field_API__c, ' +
                'UTM_Medium_Field_API__c, UTM_Term_Field_API__c, UTM_Content_Field_API__c, ' +
                'Custom_Lead_Source_Field_API__c ' +
                'FROM Meta_Integration_Settings__mdt WHERE DeveloperName = \'Default\' LIMIT 1'
            );
            if (!rows.isEmpty()) {
                SObject row = rows[0];
                String p  = (String)row.get('Project_Field_API__c');
                String us = (String)row.get('UTM_Source_Field_API__c');
                String uc = (String)row.get('UTM_Campaign_Field_API__c');
                String um = (String)row.get('UTM_Medium_Field_API__c');
                String ut = (String)row.get('UTM_Term_Field_API__c');
                String un = (String)row.get('UTM_Content_Field_API__c');
                String cl = (String)row.get('Custom_Lead_Source_Field_API__c');

                if (String.isNotBlank(p))  cachedConfig.projectFieldApi          = p.trim();
                if (String.isNotBlank(us)) cachedConfig.utmSourceFieldApi        = us.trim();
                if (String.isNotBlank(uc)) cachedConfig.utmCampaignFieldApi      = uc.trim();
                if (String.isNotBlank(um)) cachedConfig.utmMediumFieldApi        = um.trim();
                if (String.isNotBlank(ut)) cachedConfig.utmTermFieldApi          = ut.trim();
                if (String.isNotBlank(un)) cachedConfig.utmContentFieldApi       = un.trim();
                if (String.isNotBlank(cl)) cachedConfig.customLeadSourceFieldApi = cl.trim();
            }
        } catch (Exception e) {
            System.debug('MetaFieldConfigService.getConfig error: ' + e.getMessage());
        }
        return cachedConfig;
    }

    /**
     * Safely sets a value on an SObject using a configured field API name.
     * Does nothing if fieldApi is blank or the field doesn't exist on the object.
     */
    public static void safeSetField(SObject obj, String fieldApi, String value) {
        if (String.isBlank(fieldApi) || String.isBlank(value) || obj == null) return;
        try {
            obj.put(fieldApi, value);
        } catch (Exception e) {
            System.debug('MetaFieldConfigService.safeSetField: Could not set ' + fieldApi + ' → ' + e.getMessage());
        }
    }

    /**
     * Safely gets a String value from an SObject using a configured field API name.
     * Returns blank if field is not configured or doesn't exist.
     */
    public static String safeGetField(SObject obj, String fieldApi) {
        if (String.isBlank(fieldApi) || obj == null) return '';
        try {
            Object val = obj.get(fieldApi);
            return val != null ? String.valueOf(val) : '';
        } catch (Exception e) {
            return '';
        }
    }
}

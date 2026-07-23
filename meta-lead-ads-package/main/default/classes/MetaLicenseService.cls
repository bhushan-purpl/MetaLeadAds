public with sharing class MetaLicenseService {
    
    // Get the configured License Server URL
    private static String getLicenseServerUrl() {
        // Hardcoded to prevent customers from seeing or modifying the endpoint
        return 'https://purplstack.com/license.php';
    }

    // Register Trial on first open
    @AuraEnabled
    public static Meta_License_Settings__c registerTrial() {
        Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
        if (settings != null && settings.Id != null) {
            return settings; // Already registered
        }

        String orgId = UserInfo.getOrganizationId();
        String companyName = UserInfo.getOrganizationName();
        String adminEmail = UserInfo.getUserEmail();

        Map<String, Object> payload = new Map<String, Object>{
            'org_id' => orgId,
            'company_name' => companyName,
            'admin_email' => adminEmail
        };

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(getLicenseServerUrl() + '?action=register');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> respData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (respData.containsKey('status')) {
                    settings = new Meta_License_Settings__c(
                        Status__c = (String) respData.get('status'),
                        Expiration_Date__c = Date.valueOf((String) respData.get('expiry')),
                        Max_Pages_Allowed__c = (Integer) respData.get('maxPages')
                    );
                    insert settings;
                    return settings;
                }
            }
        } catch (Exception e) {
            System.debug('Failed to register trial: ' + e.getMessage());
        }
        return null;
    }

    // Validate License Key from UI
    @AuraEnabled
    public static Map<String, Object> validateLicense(String licenseKey) {
        String orgId = UserInfo.getOrganizationId();
        Map<String, Object> payload = new Map<String, Object>{
            'org_id' => orgId,
            'license_key' => licenseKey
        };

        Map<String, Object> result = new Map<String, Object>();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(getLicenseServerUrl() + '?action=validate');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> respData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (respData.containsKey('error')) {
                    result.put('success', false);
                    result.put('message', respData.get('error'));
                } else {
                    Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
                    if (settings == null) {
                        settings = new Meta_License_Settings__c();
                    }
                    settings.License_Key__c = licenseKey;
                    settings.Status__c = (String) respData.get('status');
                    settings.Expiration_Date__c = Date.valueOf((String) respData.get('expiry'));
                    settings.Max_Pages_Allowed__c = (Integer) respData.get('maxPages');
                    upsert settings;

                    result.put('success', true);
                    result.put('settings', settings);
                }
            } else {
                result.put('success', false);
                result.put('message', 'Server returned ' + res.getStatusCode());
            }
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', e.getMessage());
        }
        return result;
    }

    // Check if license is active (for backend enforcement)
    public static Boolean isLicenseActive() {
        Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            return false;
        }
        if (settings.Expiration_Date__c != null && settings.Expiration_Date__c < Date.today()) {
            return false;
        }
        return (settings.Status__c == 'Active' || settings.Status__c == 'Trial');
    }

    // Get max pages allowed
    public static Integer getMaxPages() {
        Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
        if (settings == null || settings.Max_Pages_Allowed__c == null) {
            return 0; // Or some hardcoded default trial value like 1
        }
        return Integer.valueOf(settings.Max_Pages_Allowed__c);
    }
}

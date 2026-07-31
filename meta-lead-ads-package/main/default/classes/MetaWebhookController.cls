/**
 * MetaWebhookController
 *
 * AuraEnabled Apex controller for the metaWebhookSetup LWC.
 * Dynamic token resolution from Meta_Page__c, Meta_Auth_Token__c, and Metadata.
 */
public with sharing class MetaWebhookController {

    private static final String GRAPH_BASE = 'https://graph.facebook.com';

    private static String getApiVersion() {
        Meta_Integration_Settings__mdt s = Meta_Integration_Settings__mdt.getInstance('Default');
        return (s != null && String.isNotBlank(s.Graph_API_Version__c)) ? s.Graph_API_Version__c : 'v25.0';
    }

    private static String getPageToken(String pageId) {
        if (String.isNotBlank(pageId)) {
            List<Meta_Page__c> pages = [SELECT Access_Token__c FROM Meta_Page__c WHERE Page_ID__c = :pageId AND Active__c = true LIMIT 1];
            if (!pages.isEmpty() && String.isNotBlank(pages[0].Access_Token__c)) {
                return pages[0].Access_Token__c.trim();
            }
            List<Meta_Page_Subscription__c> subs = [SELECT Page_Access_Token__c FROM Meta_Page_Subscription__c WHERE Page_ID__c = :pageId AND Status__c = 'Active' LIMIT 1];
            if (!subs.isEmpty() && String.isNotBlank(subs[0].Page_Access_Token__c)) {
                return subs[0].Page_Access_Token__c.trim();
            }
        }
        // Fall back to User Auth Token
        List<Meta_Auth_Token__c> tokens = [SELECT User_Access_Token__c FROM Meta_Auth_Token__c LIMIT 1];
        if (!tokens.isEmpty() && String.isNotBlank(tokens[0].User_Access_Token__c)) {
            return tokens[0].User_Access_Token__c.trim();
        }
        // Fall back to Metadata
        Meta_Integration_Settings__mdt config = Meta_Integration_Settings__mdt.getInstance('Default');
        if (config != null && String.isNotBlank(config.Page_Access_Token__c)) {
            return config.Page_Access_Token__c.trim();
        }
        // Fall back to any active page token
        List<Meta_Page__c> anyPage = [SELECT Access_Token__c FROM Meta_Page__c WHERE Active__c = true LIMIT 1];
        if (!anyPage.isEmpty() && String.isNotBlank(anyPage[0].Access_Token__c)) {
            return anyPage[0].Access_Token__c.trim();
        }
        return null;
    }

    // ── Load initial config for the UI ──
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getConfig() {
        Map<String, String> config = new Map<String, String>();
        try {
            Meta_Integration_Settings__mdt settings = Meta_Integration_Settings__mdt.getInstance('Default');
            String token = getPageToken(null);
            Boolean hasToken = String.isNotBlank(token);

            config.put('hasToken',   String.valueOf(hasToken));
            config.put('apiVersion', getApiVersion());

            // Masked token preview (last 6 chars only)
            config.put('tokenPreview', hasToken
                ? '••••••••' + token.right(Math.min(6, token.length()))
                : 'Not Configured');

            String verifyToken = (settings != null && String.isNotBlank(settings.Verify_Token__c))
                                 ? settings.Verify_Token__c : 'Purplstack2026';
            config.put('verifyToken', verifyToken);

            // Auto-detect Page ID from Meta_Page__c or most recent log
            String pageId = '';
            try {
                List<Meta_Page__c> pages = [SELECT Page_ID__c FROM Meta_Page__c WHERE Active__c = true ORDER BY LastModifiedDate DESC LIMIT 1];
                if (!pages.isEmpty()) {
                    pageId = pages[0].Page_ID__c;
                } else {
                    List<Meta_Lead_Log__c> logs = [
                        SELECT Page_ID__c FROM Meta_Lead_Log__c
                        WHERE Page_ID__c != null
                        ORDER BY CreatedDate DESC LIMIT 1
                    ];
                    if (!logs.isEmpty()) pageId = logs[0].Page_ID__c;
                }
            } catch (Exception ex) { /* ignore */ }
            config.put('pageId', pageId);

            String generatedRedirectUri = getGeneratedRedirectUri();
            config.put('redirectUrl', generatedRedirectUri);

            String webhookUrl = generatedRedirectUri.replace('/metaAuthCallback', '/metaLead');
            config.put('webhookUrl', webhookUrl);

            Url u = new Url(generatedRedirectUri);
            config.put('domainUrl', u.getHost());

        } catch (Exception e) {
            config.put('error', e.getMessage());
        }
        return config;
    }

    // ── Generate Dynamic Redirect URI ──
    public static String getGeneratedRedirectUri() {
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        String className = MetaWebhookController.class.getName();
        String namespace = '';
        if (className.contains('.')) {
            namespace = className.substringBefore('.');
        } else {
            Organization org = [SELECT NamespacePrefix FROM Organization LIMIT 1];
            if (String.isNotBlank(org.NamespacePrefix)) {
                namespace = org.NamespacePrefix;
            }
        }
        String restPrefix = String.isNotBlank(namespace) ? '/services/apexrest/' + namespace : '/services/apexrest';

        String baseUrl = orgUrl;
        
        String currentSiteUrl = Site.getBaseUrl();
        if (String.isNotBlank(currentSiteUrl)) {
            baseUrl = currentSiteUrl;
        } else {
            baseUrl = orgUrl.replace('.sandbox.my.salesforce.com', '.sandbox.my.salesforce-sites.com')
                            .replace('.scratch.my.salesforce.com', '.scratch.my.salesforce-sites.com')
                            .replace('.my.salesforce.com', '.my.salesforce-sites.com')
                            .replace('.salesforce.com', '.my.site.com');
            try {
                List<Site> sites = [SELECT UrlPathPrefix FROM Site WHERE Status = 'Active' LIMIT 1];
                if (!sites.isEmpty() && String.isNotBlank(sites[0].UrlPathPrefix)) {
                    baseUrl += '/' + sites[0].UrlPathPrefix;
                }
            } catch (Exception ex) { /* fallback */ }
        }

        return baseUrl + restPrefix + '/metaAuthCallback';
    }

    // ── Check subscription status ──
    @AuraEnabled
    public static Map<String, Object> checkSubscriptionStatus(String pageId) {
        try {
            String token = getPageToken(pageId);
            if (String.isBlank(token)) {
                throw new AuraHandledException('No Access Token found for Page. Please connect your Facebook Account on Meta Setup.');
            }
            String endpoint = GRAPH_BASE + '/' + getApiVersion() + '/' + pageId
                            + '/subscribed_apps?access_token='
                            + EncodingUtil.urlEncode(token, 'UTF-8');
            return callGraph(endpoint, 'GET', null);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking status: ' + e.getMessage());
        }
    }

    // ── Subscribe page to leadgen webhook ──
    @AuraEnabled
    public static Map<String, Object> subscribeWebhook(String pageId) {
        try {
            String token = getPageToken(pageId);
            if (String.isBlank(token)) {
                throw new AuraHandledException('No Access Token found for Page. Please connect your Facebook Account on Meta Setup.');
            }
            String endpoint = GRAPH_BASE + '/' + getApiVersion() + '/' + pageId + '/subscribed_apps';
            String reqBody  = 'subscribed_fields=leadgen&access_token='
                            + EncodingUtil.urlEncode(token, 'UTF-8');
            return callGraph(endpoint, 'POST', reqBody);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error subscribing: ' + e.getMessage());
        }
    }

    // ── Unsubscribe page from webhook ──
    @AuraEnabled
    public static Map<String, Object> unsubscribeWebhook(String pageId) {
        try {
            String token = getPageToken(pageId);
            if (String.isBlank(token)) {
                throw new AuraHandledException('No Access Token found for Page. Please connect your Facebook Account on Meta Setup.');
            }
            String endpoint = GRAPH_BASE + '/' + getApiVersion() + '/' + pageId
                            + '/subscribed_apps?access_token='
                            + EncodingUtil.urlEncode(token, 'UTF-8');
            return callGraph(endpoint, 'DELETE', null);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error unsubscribing: ' + e.getMessage());
        }
    }

    // ── Internal HTTP helper ──
    private static Map<String, Object> callGraph(String endpoint, String method, String reqBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setTimeout(30000);
        if (String.isNotBlank(reqBody)) {
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(reqBody);
        }

        HttpResponse res    = new Http().send(req);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (res.getStatusCode() != 200) {
            String errMsg = 'Facebook API Error';
            if (result.containsKey('error')) {
                Map<String, Object> err = (Map<String, Object>) result.get('error');
                errMsg = 'Facebook API Error: ' + (String) err.get('message');
            }
            throw new AuraHandledException(errMsg);
        }
        return result;
    }

    // ── Get Org Field Configuration (field API names) ──
    @AuraEnabled(cacheable=false)
    public static Map<String, String> getFieldConfig() {
        Map<String, String> cfg = new Map<String, String>{
            'projectFieldApi'       => '',
            'utmSourceFieldApi'     => '',
            'utmCampaignFieldApi'   => '',
            'utmMediumFieldApi'     => '',
            'utmTermFieldApi'       => '',
            'utmContentFieldApi'    => '',
            'customLeadSourceFieldApi' => '',
            'integrationSourceFieldApi' => ''
        };
        try {
            List<SObject> rows = Database.query(
                'SELECT Project_Field_API__c, UTM_Source_Field_API__c, UTM_Campaign_Field_API__c, ' +
                'UTM_Medium_Field_API__c, UTM_Term_Field_API__c, UTM_Content_Field_API__c, ' +
                'Custom_Lead_Source_Field_API__c, Integration_Source_Field_API__c ' +
                'FROM Meta_Integration_Settings__mdt WHERE DeveloperName = \'Default\' LIMIT 1'
            );
            if (!rows.isEmpty()) {
                SObject row = rows[0];
                if (row.get('Project_Field_API__c')         != null) cfg.put('projectFieldApi',          (String)row.get('Project_Field_API__c'));
                if (row.get('UTM_Source_Field_API__c')      != null) cfg.put('utmSourceFieldApi',         (String)row.get('UTM_Source_Field_API__c'));
                if (row.get('UTM_Campaign_Field_API__c')    != null) cfg.put('utmCampaignFieldApi',       (String)row.get('UTM_Campaign_Field_API__c'));
                if (row.get('UTM_Medium_Field_API__c')      != null) cfg.put('utmMediumFieldApi',         (String)row.get('UTM_Medium_Field_API__c'));
                if (row.get('UTM_Term_Field_API__c')        != null) cfg.put('utmTermFieldApi',           (String)row.get('UTM_Term_Field_API__c'));
                if (row.get('UTM_Content_Field_API__c')     != null) cfg.put('utmContentFieldApi',        (String)row.get('UTM_Content_Field_API__c'));
                if (row.get('Custom_Lead_Source_Field_API__c') != null) cfg.put('customLeadSourceFieldApi', (String)row.get('Custom_Lead_Source_Field_API__c'));
                if (row.get('Integration_Source_Field_API__c') != null) cfg.put('integrationSourceFieldApi', (String)row.get('Integration_Source_Field_API__c'));
            }
        } catch (Exception e) {
            System.debug('getFieldConfig error: ' + e.getMessage());
        }
        return cfg;
    }

    // ── Save Org Field Configuration via Metadata API ──
    @AuraEnabled
    public static String saveFieldConfig(String configJson) {
        try {
            Map<String, Object> cfg = (Map<String, Object>) JSON.deserializeUntyped(configJson);

            // Dynamically determine namespace
            String ns = '';
            if (Schema.getGlobalDescribe().containsKey('purpl__Meta_Integration_Settings__mdt')) {
                ns = 'purpl__';
            }

            // Use Metadata API to update Custom Metadata record
            Metadata.CustomMetadata mdt = new Metadata.CustomMetadata();
            mdt.fullName = ns + 'Meta_Integration_Settings__mdt.Default';
            mdt.label = 'Default';

            Map<String, String> fieldMap = new Map<String, String>{
                'projectFieldApi'          => ns + 'Project_Field_API__c',
                'utmSourceFieldApi'        => ns + 'UTM_Source_Field_API__c',
                'utmCampaignFieldApi'      => ns + 'UTM_Campaign_Field_API__c',
                'utmMediumFieldApi'        => ns + 'UTM_Medium_Field_API__c',
                'utmTermFieldApi'          => ns + 'UTM_Term_Field_API__c',
                'utmContentFieldApi'       => ns + 'UTM_Content_Field_API__c',
                'customLeadSourceFieldApi' => ns + 'Custom_Lead_Source_Field_API__c',
                'integrationSourceFieldApi'=> ns + 'Integration_Source_Field_API__c'
            };

            for (String jsKey : fieldMap.keySet()) {
                Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
                val.field = fieldMap.get(jsKey);
                val.value = cfg.containsKey(jsKey) ? (String)cfg.get(jsKey) : '';
                mdt.values.add(val);
            }

            Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
            deployContainer.addMetadata(mdt);
            Metadata.Operations.enqueueDeployment(deployContainer, null);
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException('Save failed: ' + e.getMessage());
        }
    }
}
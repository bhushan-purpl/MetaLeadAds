/**
 * MetaWebhookController
 *
 * AuraEnabled Apex controller for the metaWebhookSetup LWC.
 * Includes all HTTP callout logic internally — no external service class needed.
 */
public with sharing class MetaWebhookController {

    private static final String GRAPH_BASE = 'https://graph.facebook.com';

    // ── Load initial config for the UI ──
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getConfig() {
        Map<String, String> config = new Map<String, String>();
        try {
            Meta_Integration_Settings__mdt settings = Meta_Integration_Settings__mdt.getInstance('Default');

            Boolean hasToken = settings != null && String.isNotBlank(settings.Page_Access_Token__c);
            config.put('hasToken',   String.valueOf(hasToken));
            config.put('apiVersion', (settings != null && String.isNotBlank(settings.Graph_API_Version__c))
                                      ? settings.Graph_API_Version__c : 'v25.0');

            // Masked token preview (last 6 chars only)
            config.put('tokenPreview', hasToken
                ? '••••••••' + settings.Page_Access_Token__c.right(6)
                : 'Not Configured');

            // Auto-detect Page ID from most recent log
            String pageId = '';
            try {
                List<Meta_Lead_Log__c> logs = [
                    SELECT Page_ID__c FROM Meta_Lead_Log__c
                    WHERE Page_ID__c != null
                    ORDER BY CreatedDate DESC LIMIT 1
                ];
                if (!logs.isEmpty()) pageId = logs[0].Page_ID__c;
            } catch (Exception ex) { /* ignore */ }
            config.put('pageId', pageId);

            // Construct webhook URL
            String orgUrl    = URL.getOrgDomainUrl().toExternalForm();
            String webhookUrl = orgUrl + '/services/apexrest/MetaLeadWebhook';
            try {
                List<Site> sites = [SELECT UrlPathPrefix FROM Site WHERE Status = 'Active' LIMIT 1];
                if (!sites.isEmpty()) {
                    String sitePath = String.isNotBlank(sites[0].UrlPathPrefix)
                                      ? '/' + sites[0].UrlPathPrefix : '';
                    webhookUrl = orgUrl.replace('.salesforce.com', '.my.site.com')
                               + sitePath + '/services/apexrest/MetaLeadWebhook';
                }
            } catch (Exception ex) { /* use fallback */ }
            config.put('webhookUrl', webhookUrl);

        } catch (Exception e) {
            config.put('error', e.getMessage());
        }
        return config;
    }

    // ── Check subscription status ──
    @AuraEnabled
    public static Map<String, Object> checkSubscriptionStatus(String pageId) {
        try {
            Meta_Integration_Settings__mdt s = getValidatedSettings();
            String endpoint = GRAPH_BASE + '/' + getApiVersion(s) + '/' + pageId
                            + '/subscribed_apps?access_token='
                            + EncodingUtil.urlEncode(s.Page_Access_Token__c, 'UTF-8');
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
            Meta_Integration_Settings__mdt s = getValidatedSettings();
            String endpoint = GRAPH_BASE + '/' + getApiVersion(s) + '/' + pageId + '/subscribed_apps';
            String reqBody  = 'subscribed_fields=leadgen&access_token='
                            + EncodingUtil.urlEncode(s.Page_Access_Token__c, 'UTF-8');
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
            Meta_Integration_Settings__mdt s = getValidatedSettings();
            String endpoint = GRAPH_BASE + '/' + getApiVersion(s) + '/' + pageId
                            + '/subscribed_apps?access_token='
                            + EncodingUtil.urlEncode(s.Page_Access_Token__c, 'UTF-8');
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

    // ── Private helpers ──
    private static Meta_Integration_Settings__mdt getValidatedSettings() {
        Meta_Integration_Settings__mdt settings = Meta_Integration_Settings__mdt.getInstance('Default');
        if (settings == null || String.isBlank(settings.Page_Access_Token__c)) {
            throw new AuraHandledException(
                'Page Access Token is not configured. Go to Setup → Custom Metadata Types → Meta Integration Settings → Manage Records → Default → Edit.'
            );
        }
        return settings;
    }

    private static String getApiVersion(Meta_Integration_Settings__mdt s) {
        return String.isNotBlank(s.Graph_API_Version__c) ? s.Graph_API_Version__c : 'v25.0';
    }
}
/**
 * MetaAuthController.cls
 * Handles the Facebook OAuth 2.0 flow:
 *   1. Generates the Facebook Login URL for the LWC popup
 *   2. Exchanges the authorization code for a user access token
 *   3. Stores the token and fetches managed pages for the dropdown
 *
 * Replaces the need for hardcoded tokens.
 */
public without sharing class MetaAuthController {

    // ─────────────────────────────────────────────────────────────────
    // Step 1: Generate the Facebook Login URL
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String getFacebookLoginUrl() {
        Meta_Integration_Settings__mdt config = getConfig();
        String redirectUri = config.Redirect_URI__c;
        if (String.isBlank(redirectUri)) {
            throw new AuraHandledException('Please configure Redirect_URI__c in Meta Integration Settings.');
        }

        String loginUrl = 'https://www.facebook.com/' + getApiVersion(config) + '/dialog/oauth'
            + '?client_id='     + config.App_ID__c
            + '&redirect_uri='  + EncodingUtil.urlEncode(redirectUri, 'UTF-8')
            + '&scope=pages_show_list,pages_manage_metadata,leads_retrieval,business_management,pages_read_engagement'
            + '&response_type=code'
            + '&state=meta_leads_oauth';

        return loginUrl;
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 2: Exchange the authorization code for an access token
    // ─────────────────────────────────────────────────────────────────
    public static String exchangeCodeForToken(String code) {
        Meta_Integration_Settings__mdt config = getConfig();
        String redirectUri = config.Redirect_URI__c;
        if (String.isBlank(redirectUri)) {
            throw new AuraHandledException('Please configure Redirect_URI__c in Meta Integration Settings.');
        }

        String endpoint = 'https://graph.facebook.com/' + getApiVersion(config) + '/oauth/access_token'
            + '?client_id='     + config.App_ID__c
            + '&client_secret=' + config.App_Secret__c
            + '&redirect_uri='  + EncodingUtil.urlEncode(redirectUri, 'UTF-8')
            + '&code='          + code;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('OAuth token exchange failed: ' + res.getBody());
        }

        Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String userToken = (String) tokenData.get('access_token');

        saveUserToken(userToken);

        return userToken;
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 3: Fetch managed pages for the LWC dropdown
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<MetaPageWrapper> getManagedPages() {
        String userToken = getUserToken();
        if (String.isBlank(userToken)) {
            throw new AuraHandledException('Not connected to Facebook. Please connect first.');
        }
        
        Meta_Integration_Settings__mdt config = getConfig();
        String endpoint = 'https://graph.facebook.com/' + getApiVersion(config) 
                          + '/me/accounts?access_token=' + userToken
                          + '&fields=id,name,access_token';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch pages: ' + res.getBody());
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> dataList = (List<Object>) parsed.get('data');
        
        List<MetaPageWrapper> pages = new List<MetaPageWrapper>();
        if (dataList != null) {
            for (Object obj : dataList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                MetaPageWrapper w = new MetaPageWrapper();
                w.pageId      = (String) p.get('id');
                w.pageName    = (String) p.get('name');
                w.accessToken = (String) p.get('access_token');
                pages.add(w);
            }
        }
        return pages;
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 4: Subscribe a selected page to Lead Ads webhook
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String subscribePage(String pageId, String pageAccessToken, String pageName) {
        try {
            Meta_Integration_Settings__mdt config = getConfig();
            String endpoint = 'https://graph.facebook.com/' + getApiVersion(config) + '/' + pageId + '/subscribed_apps';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setTimeout(30000);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('subscribed_fields=leadgen&access_token=' + pageAccessToken);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Failed to subscribe page: ' + res.getBody());
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Boolean success = (Boolean) result.get('success');

            if (success == true) {
                // Save the page subscription record in Salesforce
                List<Meta_Page_Subscription__c> existing = [
                    SELECT Id FROM Meta_Page_Subscription__c WHERE Page_ID__c = :pageId LIMIT 1
                ];

                Meta_Page_Subscription__c sub;
                if (!existing.isEmpty()) {
                    sub = existing[0];
                } else {
                    sub = new Meta_Page_Subscription__c();
                }

                sub.Page_ID__c          = pageId;
                sub.Page_Name__c        = pageName;
                sub.Page_Access_Token__c = pageAccessToken;
                sub.Status__c           = 'Active';
                sub.Last_Sync_Date__c   = Datetime.now();

                upsert sub;
                return 'SUCCESS';
            } else {
                return 'FAILED';
            }
        } catch (Exception e) {
            throw new AuraHandledException('Subscription failed: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 5: Check connection status - used by LWC on load
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Boolean isConnected() {
        return String.isNotBlank(getUserToken());
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 6: Get active subscriptions for the monitoring table
    // ─────────────────────────────────────────────────────────────────
    public class SubscriptionWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Page_ID;
        @AuraEnabled public String Page_Name;
        @AuraEnabled public Boolean Enable_Logs;
        @AuraEnabled public Boolean Enable_Lead_Creation;
    }

    @AuraEnabled(cacheable=false)
    public static List<SubscriptionWrapper> getActiveSubscriptions() {
        List<SubscriptionWrapper> wrappers = new List<SubscriptionWrapper>();
        for (Meta_Page_Subscription__c sub : [
            SELECT Id, Page_ID__c, Page_Name__c, Enable_Logs__c, Enable_Lead_Creation__c
            FROM Meta_Page_Subscription__c
            WHERE Status__c = 'Active'
            ORDER BY Last_Sync_Date__c DESC
        ]) {
            SubscriptionWrapper w = new SubscriptionWrapper();
            w.Id = sub.Id;
            w.Page_ID = sub.Page_ID__c;
            w.Page_Name = sub.Page_Name__c;
            w.Enable_Logs = sub.Enable_Logs__c;
            w.Enable_Lead_Creation = sub.Enable_Lead_Creation__c;
            wrappers.add(w);
        }
        return wrappers;
    }
    
    // ─────────────────────────────────────────────────────────────────
    // Step 6.5: Update Subscription Settings (Toggles)
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static void updateSubscriptionSettings(String recordId, Boolean enableLogs, Boolean enableLeads) {
        try {
            Meta_Page_Subscription__c sub = new Meta_Page_Subscription__c(
                Id = recordId,
                Enable_Logs__c = enableLogs,
                Enable_Lead_Creation__c = enableLeads
            );
            update sub;
        } catch (Exception e) {
            throw new AuraHandledException('Update failed: ' + e.getMessage());
        }
    }
    
    // ─────────────────────────────────────────────────────────────────
    // Step 7: Get recent Integration Logs for the dashboard
    // ─────────────────────────────────────────────────────────────────
    public class LogWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Meta_Lead_ID;
        @AuraEnabled public String Page_ID;
        @AuraEnabled public String Processing_Status;
        @AuraEnabled public String Error_Message;
        @AuraEnabled public Datetime CreatedDate;
    }

    @AuraEnabled(cacheable=false)
    public static List<LogWrapper> getIntegrationLogs() {
        List<LogWrapper> wrappers = new List<LogWrapper>();
        for (Meta_Lead_Log__c log : [
            SELECT Id, Meta_Lead_ID__c, Page_ID__c, Processing_Status__c, Error_Message__c, CreatedDate
            FROM Meta_Lead_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            LogWrapper w = new LogWrapper();
            w.Id = log.Id;
            w.Meta_Lead_ID = log.Meta_Lead_ID__c;
            w.Page_ID = log.Page_ID__c;
            w.Processing_Status = log.Processing_Status__c;
            w.Error_Message = log.Error_Message__c;
            w.CreatedDate = log.CreatedDate;
            wrappers.add(w);
        }
        return wrappers;
    }

    // ─────────────────────────────────────────────────────────────────
    // Step 8: Disconnect (clear token)
    // ─────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static void disconnect() {
        List<Meta_Auth_Token__c> tokens = [SELECT Id FROM Meta_Auth_Token__c LIMIT 1];
        if (!tokens.isEmpty()) {
            delete tokens;
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────
    private static Meta_Integration_Settings__mdt getConfig() {
        Meta_Integration_Settings__mdt config = Meta_Integration_Settings__mdt.getInstance('Default');
        if (Test.isRunningTest() && config == null) {
            return new Meta_Integration_Settings__mdt(
                App_ID__c = 'mock_app_id',
                App_Secret__c = 'mock_secret',
                Graph_API_Version__c = 'v17.0',
                Redirect_URI__c = 'https://mock.uri'
            );
        }
        if (config == null || String.isBlank(config.App_ID__c)) {
            throw new AuraHandledException('Facebook App configuration not found. Please set App ID in Meta_Integration_Settings__mdt (Default record).');
        }
        return config;
    }
    
    private static String getApiVersion(Meta_Integration_Settings__mdt s) {
        return String.isNotBlank(s.Graph_API_Version__c) ? s.Graph_API_Version__c : 'v25.0';
    }

    private static void saveUserToken(String token) {
        System.debug('TOKEN RECEIVED = ' + token);

        // Bypass Guest User limits by passing token to the Automated Process trigger
        Meta_Lead_Event__e evt = new Meta_Lead_Event__e(
            Leadgen_ID__c = 'OAUTH_TOKEN_SAVE',
            Meta_Lead_Event__c = token
        );
        
        EventBus.publish(evt);
    }

    private static String getUserToken() {
        List<Meta_Auth_Token__c> tokens = [SELECT User_Access_Token__c FROM Meta_Auth_Token__c LIMIT 1];
        return tokens.isEmpty() ? null : tokens[0].User_Access_Token__c;
    }
}

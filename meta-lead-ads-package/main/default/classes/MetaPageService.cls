public without sharing class MetaPageService {

    private static String getApiVersion() {
        Meta_Integration_Settings__mdt s = Meta_Integration_Settings__mdt.getInstance('Default');
        return (s != null && String.isNotBlank(s.Graph_API_Version__c)) ? s.Graph_API_Version__c : 'v25.0';
    }

    private static String getUserToken() {
        // First try the new Auth Token custom object
        List<Meta_Auth_Token__c> tokens = [SELECT User_Access_Token__c FROM Meta_Auth_Token__c LIMIT 1];
        if (!tokens.isEmpty() && String.isNotBlank(tokens[0].User_Access_Token__c)) {
            return tokens[0].User_Access_Token__c.trim();
        }
        
        // Fall back to Custom Metadata (if user saved token there manually)
        Meta_Integration_Settings__mdt config = Meta_Integration_Settings__mdt.getInstance('Default');
        if (config != null && String.isNotBlank(config.Page_Access_Token__c)) {
            return config.Page_Access_Token__c.trim();
        }
        
        return null;
    }

    // Called from LWC to sync all pages the user manages
    @AuraEnabled
    public static List<Meta_Page__c> syncPages() {
        String token = getUserToken();
        if (String.isBlank(token)) throw new AuraHandledException('Not connected to Facebook.');

        String endpoint = 'https://graph.facebook.com/' + getApiVersion() + '/me/accounts?access_token=' + token + '&fields=id,name,access_token';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) throw new AuraHandledException('Failed to fetch pages: ' + res.getBody());

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> data = (List<Object>) parsed.get('data');

        List<Meta_Page__c> pagesToUpsert = new List<Meta_Page__c>();
        if (data != null) {
            for (Object obj : data) {
                Map<String, Object> p = (Map<String, Object>) obj;
                Meta_Page__c page = new Meta_Page__c();
                page.Page_ID__c      = (String) p.get('id');
                page.Page_Name__c    = (String) p.get('name');
                page.Access_Token__c = (String) p.get('access_token');
                page.Status__c       = 'Connected';
                page.Active__c       = true;
                page.Last_Sync__c    = Datetime.now();
                pagesToUpsert.add(page);
            }
        }

        if (!pagesToUpsert.isEmpty()) {
            upsert pagesToUpsert Page_ID__c;
        }

        return [SELECT Id, Page_ID__c, Page_Name__c, Status__c, Active__c, Last_Sync__c, Forms_Count__c FROM Meta_Page__c WHERE Active__c = true ORDER BY Page_Name__c];
    }

    @AuraEnabled(cacheable=false)
    public static List<Meta_Page__c> getPages() {
        return [SELECT Id, Page_ID__c, Page_Name__c, Status__c, Active__c, Last_Sync__c, Forms_Count__c FROM Meta_Page__c WHERE Active__c = true ORDER BY Page_Name__c];
    }

    // Update form count per page
    public static void refreshPageFormCounts() {
        List<AggregateResult> counts = [
            SELECT Page_ID__c, COUNT(Id) cnt 
            FROM Meta_Form__c 
            GROUP BY Page_ID__c
        ];
        Map<String, Integer> countMap = new Map<String, Integer>();
        for (AggregateResult ar : counts) {
            countMap.put((String) ar.get('Page_ID__c'), (Integer) ar.get('cnt'));
        }
        List<Meta_Page__c> pages = [SELECT Id, Page_ID__c, Forms_Count__c FROM Meta_Page__c];
        for (Meta_Page__c pg : pages) {
            pg.Forms_Count__c = countMap.containsKey(pg.Page_ID__c) ? countMap.get(pg.Page_ID__c) : 0;
        }
        if (!pages.isEmpty()) update pages;
    }
}
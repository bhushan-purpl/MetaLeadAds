public with sharing class MetaMarketingApiService {
    
    public class MarketingApiException extends Exception {}

    public static String getAccessToken() {
        // Query dynamic auth token from Meta_Auth_Token__c custom setting/object
        List<Meta_Auth_Token__c> tokens = [SELECT User_Access_Token__c FROM Meta_Auth_Token__c LIMIT 1];
        if (!tokens.isEmpty() && String.isNotBlank(tokens[0].User_Access_Token__c)) {
            return tokens[0].User_Access_Token__c;
        }
        
        // Fallback to Meta_Page__c page access token
        List<Meta_Page__c> pages = [SELECT Access_Token__c FROM Meta_Page__c LIMIT 50];
        for (Meta_Page__c p : pages) {
            if (String.isNotBlank(p.Access_Token__c)) {
                return p.Access_Token__c;
            }
        }

        return '';
    }

    @AuraEnabled
    public static List<Map<String, String>> fetchAdAccounts() {
        String token = getAccessToken();
        if (String.isBlank(token)) {
            return new List<Map<String, String>>();
        }

        String endpoint = 'https://graph.facebook.com/v19.0/me/adaccounts?fields=id,name,account_id,currency,account_status&access_token=' + EncodingUtil.urlEncode(token, 'UTF-8');
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(20000);

        List<Map<String, String>> adAccounts = new List<Map<String, String>>();

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (body.containsKey('data')) {
                    List<Object> dataList = (List<Object>) body.get('data');
                    for (Object obj : dataList) {
                        Map<String, Object> accMap = (Map<String, Object>) obj;
                        Map<String, String> item = new Map<String, String>();
                        item.put('id', String.valueOf(accMap.get('id')));
                        item.put('name', String.valueOf(accMap.get('name')));
                        item.put('account_id', String.valueOf(accMap.get('account_id')));
                        item.put('currency', String.valueOf(accMap.get('currency')));
                        adAccounts.add(item);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Meta Marketing API Callout Error: ' + e.getMessage());
        }

        return adAccounts;
    }

    public static String executeMarketingCallout(String endpointPath, Map<String, String> params) {
        String token = getAccessToken();
        String url = 'https://graph.facebook.com/v19.0/' + endpointPath + '?access_token=' + EncodingUtil.urlEncode(token, 'UTF-8');
        
        if (params != null) {
            for (String key : params.keySet()) {
                url += '&' + key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8');
            }
        }

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(url);
        request.setMethod('GET');
        request.setTimeout(20000);

        HttpResponse response = http.send(request);
        return response.getBody();
    }
}

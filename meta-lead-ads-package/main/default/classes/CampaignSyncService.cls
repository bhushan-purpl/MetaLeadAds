public with sharing class CampaignSyncService {

    public static Boolean syncCampaignData(String adAccountId) {
        if (String.isBlank(adAccountId)) return false;

        try {
            // Fetch campaigns from Meta Graph API
            Map<String, String> params = new Map<String, String>{
                'fields' => 'id,name,status,daily_budget,lifetime_budget'
            };
            String resBody = MetaMarketingApiService.executeMarketingCallout(adAccountId + '/campaigns', params);
            
            if (String.isNotBlank(resBody)) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(resBody);
                if (body.containsKey('data')) {
                    List<Object> dataList = (List<Object>) body.get('data');
                    List<Meta_Campaign_Analytics__c> recordsToUpsert = new List<Meta_Campaign_Analytics__c>();
                    
                    for (Object obj : dataList) {
                        Map<String, Object> campMap = (Map<String, Object>) obj;
                        String campId = String.valueOf(campMap.get('id'));
                        String campName = String.valueOf(campMap.get('name'));
                        
                        Meta_Campaign_Analytics__c mca = new Meta_Campaign_Analytics__c();
                        mca.Campaign_Id__c = campId;
                        mca.Campaign_Name__c = campName;
                        mca.Ad_Account_Id__c = adAccountId;
                        mca.Analytics_Date__c = Date.today();
                        
                        if (campMap.containsKey('daily_budget')) {
                            mca.Budget__c = Decimal.valueOf(String.valueOf(campMap.get('daily_budget'))) / 100;
                        }
                        
                        recordsToUpsert.add(mca);
                    }

                    if (!recordsToUpsert.isEmpty()) {
                        Schema.SObjectField externalIdField = Meta_Campaign_Analytics__c.Fields.Campaign_Id__c;
                        Database.upsert(recordsToUpsert, externalIdField, false);
                    }
                }
            }
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CampaignSyncService Error: ' + e.getMessage());
            return false;
        }
    }
}

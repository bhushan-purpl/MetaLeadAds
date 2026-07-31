public with sharing class InsightsSyncService {

    public static Boolean syncInsightsData(String adAccountId, String datePreset) {
        if (String.isBlank(adAccountId)) return false;
        if (String.isBlank(datePreset)) datePreset = 'last_30d';

        try {
            Map<String, String> params = new Map<String, String>{
                'fields' => 'campaign_id,campaign_name,spend,clicks,impressions,reach,ctr,cpc,cpm,actions,date_start,date_stop',
                'level' => 'campaign',
                'date_preset' => datePreset
            };
            
            String resBody = MetaMarketingApiService.executeMarketingCallout(adAccountId + '/insights', params);
            
            if (String.isNotBlank(resBody)) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(resBody);
                if (body.containsKey('data')) {
                    List<Object> dataList = (List<Object>) body.get('data');
                    List<Meta_Campaign_Analytics__c> campAnalytics = new List<Meta_Campaign_Analytics__c>();
                    List<Meta_Daily_Analytics__c> dailyAnalytics = new List<Meta_Daily_Analytics__c>();

                    for (Object obj : dataList) {
                        Map<String, Object> insMap = (Map<String, Object>) obj;
                        
                        String campId = String.valueOf(insMap.get('campaign_id'));
                        String campName = String.valueOf(insMap.get('campaign_name'));
                        Decimal spend = insMap.containsKey('spend') ? Decimal.valueOf(String.valueOf(insMap.get('spend'))) : 0;
                        Integer clicks = insMap.containsKey('clicks') ? Integer.valueOf(String.valueOf(insMap.get('clicks'))) : 0;
                        Integer impressions = insMap.containsKey('impressions') ? Integer.valueOf(String.valueOf(insMap.get('impressions'))) : 0;
                        Integer reach = insMap.containsKey('reach') ? Integer.valueOf(String.valueOf(insMap.get('reach'))) : 0;
                        Decimal ctr = insMap.containsKey('ctr') ? Decimal.valueOf(String.valueOf(insMap.get('ctr'))) : 0;
                        Decimal cpc = insMap.containsKey('cpc') ? Decimal.valueOf(String.valueOf(insMap.get('cpc'))) : 0;
                        Decimal cpm = insMap.containsKey('cpm') ? Decimal.valueOf(String.valueOf(insMap.get('cpm'))) : 0;
                        
                        Integer leads = 0;
                        if (insMap.containsKey('actions')) {
                            List<Object> actions = (List<Object>) insMap.get('actions');
                            for (Object actObj : actions) {
                                Map<String, Object> actMap = (Map<String, Object>) actObj;
                                String actType = String.valueOf(actMap.get('action_type'));
                                if (actType == 'lead' || actType == 'offsite_conversion.fb_pixel_lead') {
                                    leads += Integer.valueOf(String.valueOf(actMap.get('value')));
                                }
                            }
                        }

                        Decimal cpl = (leads > 0) ? (spend / leads).setScale(2, System.RoundingMode.HALF_UP) : 0;
                        Decimal scaledCtr = ctr.setScale(2, System.RoundingMode.HALF_UP);
                        Decimal scaledCpc = cpc.setScale(2, System.RoundingMode.HALF_UP);
                        Decimal scaledCpm = cpm.setScale(2, System.RoundingMode.HALF_UP);

                        // Upsert Campaign Analytics Record
                        Meta_Campaign_Analytics__c mca = new Meta_Campaign_Analytics__c();
                        mca.Campaign_Id__c = campId;
                        mca.Campaign_Name__c = campName;
                        mca.Ad_Account_Id__c = adAccountId;
                        mca.Spend__c = spend;
                        mca.Clicks__c = clicks;
                        mca.Impressions__c = impressions;
                        mca.Reach__c = reach;
                        mca.CTR__c = scaledCtr;
                        mca.CPC__c = scaledCpc;
                        mca.CPM__c = scaledCpm;
                        mca.CPL__c = cpl;
                        mca.Leads__c = leads;
                        mca.Analytics_Date__c = Date.today();
                        campAnalytics.add(mca);

                        // Daily Trend Analytics Record
                        Meta_Daily_Analytics__c mda = new Meta_Daily_Analytics__c();
                        mda.Analytics_Date__c = Date.today();
                        mda.Campaign_Id__c = campId;
                        mda.Spend__c = spend;
                        mda.Clicks__c = clicks;
                        mda.Impressions__c = impressions;
                        mda.Leads__c = leads;
                        mda.CTR__c = scaledCtr;
                        mda.CPL__c = cpl;
                        dailyAnalytics.add(mda);
                    }

                    if (!campAnalytics.isEmpty()) {
                        Schema.SObjectField externalIdField = Meta_Campaign_Analytics__c.Fields.Campaign_Id__c;
                        Database.upsert(campAnalytics, externalIdField, false);
                    }

                    if (!dailyAnalytics.isEmpty()) {
                        insert dailyAnalytics;
                    }
                }
            }
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InsightsSyncService Error: ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            throw new IllegalArgumentException(e.getMessage());
        }
    }
}

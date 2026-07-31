public with sharing class AnalyticsScheduler implements Schedulable {
    
    public String adAccountId;

    public AnalyticsScheduler() {}
    
    public AnalyticsScheduler(String adAccountId) {
        this.adAccountId = adAccountId;
    }

    public void execute(SchedulableContext sc) {
        String targetAccId = this.adAccountId;
        if (String.isBlank(targetAccId)) {
            List<Meta_Campaign_Analytics__c> lastRecs = [SELECT Ad_Account_Id__c FROM Meta_Campaign_Analytics__c WHERE Ad_Account_Id__c != null LIMIT 1];
            if (!lastRecs.isEmpty()) {
                targetAccId = lastRecs[0].Ad_Account_Id__c;
            }
        }

        if (String.isNotBlank(targetAccId)) {
            executeAsync(targetAccId);
        }
    }

    @future(callout=true)
    public static void executeAsync(String adAccountId) {
        if (String.isNotBlank(adAccountId)) {
            // Callouts MUST occur before DML in Salesforce Apex
            InsightsSyncService.syncInsightsData(adAccountId, 'last_30d');
            CampaignSyncService.syncCampaignData(adAccountId);
        }
    }
}

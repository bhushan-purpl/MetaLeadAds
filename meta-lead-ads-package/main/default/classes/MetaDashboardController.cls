public without sharing class MetaDashboardController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new Map<String, Object>();

        // Connected pages
        stats.put('connectedPages', [SELECT COUNT() FROM Meta_Page__c WHERE Active__c = true]);

        // Forms synced
        Integer totalForms  = [SELECT COUNT() FROM Meta_Form__c WHERE Status__c = 'Active'];
        Integer mappedForms = [SELECT COUNT() FROM Meta_Form__c WHERE Is_Mapped__c = true AND Status__c = 'Active'];
        stats.put('totalForms',    totalForms);
        stats.put('mappedForms',   mappedForms);
        stats.put('unmappedForms', totalForms - mappedForms);

        // Last lead received
        List<Meta_Lead_Log__c> lastLead = [
            SELECT CreatedDate, Processing_Status__c 
            FROM Meta_Lead_Log__c 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        stats.put('lastLeadDate',   lastLead.isEmpty() ? null : lastLead[0].CreatedDate);
        stats.put('lastLeadStatus', lastLead.isEmpty() ? 'None' : lastLead[0].Processing_Status__c);

        // Last sync time
        List<Meta_Page__c> lastSync = [SELECT Last_Sync__c FROM Meta_Page__c ORDER BY Last_Sync__c DESC LIMIT 1];
        stats.put('lastSyncDate', lastSync.isEmpty() ? null : lastSync[0].Last_Sync__c);

        // Recent logs
        List<Meta_Lead_Log__c> rawLogs = [
            SELECT Id, Meta_Lead_ID__c, Page_ID__c, Form_ID__c, Processing_Status__c, Error_Message__c, CreatedDate
            FROM Meta_Lead_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        List<MetaAuthController.LogWrapper> wrappedLogs = new List<MetaAuthController.LogWrapper>();
        for (Meta_Lead_Log__c log : rawLogs) {
            MetaAuthController.LogWrapper w = new MetaAuthController.LogWrapper();
            w.Id = log.Id;
            w.Meta_Lead_ID = log.Meta_Lead_ID__c;
            w.Page_ID = log.Page_ID__c;
            w.Form_ID = log.Form_ID__c;
            w.Processing_Status = log.Processing_Status__c;
            w.Error_Message = log.Error_Message__c;
            w.CreatedDate = log.CreatedDate;
            wrappedLogs.add(w);
        }
        stats.put('recentLogs', wrappedLogs);

        return stats;
    }

    @AuraEnabled
    public static void retryLead(Id logId) {
        if (logId == null) {
            throw new AuraHandledException('Log ID is missing.');
        }

        List<Meta_Lead_Log__c> logs = [
            SELECT Id, Processing_Status__c, Retry_Count__c
            FROM Meta_Lead_Log__c 
            WHERE Id = :logId
        ];
        
        if (logs.isEmpty()) {
            throw new AuraHandledException('Lead Log not found.');
        }

        Meta_Lead_Log__c log = logs[0];
        
        if (log.Processing_Status__c != 'Failed') {
            throw new AuraHandledException('Only Failed leads can be retried.');
        }

        log.Processing_Status__c = 'Processing';
        log.Retry_Count__c = (log.Retry_Count__c == null ? 0 : log.Retry_Count__c) + 1;
        log.Last_Retry_Date__c = System.now();
        log.Retried_By__c = UserInfo.getUserId();
        update log;

        // Enqueue existing callout job
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{ log.Id }));
    }
}
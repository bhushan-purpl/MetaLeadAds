/**
 * MetaLeadRetryBatch
 * 
 * Scheduled Batch job to automatically retry failed Meta Lead Graph API callouts.
 * This ensures temporary Graph API errors or token issues don't result in permanent data loss.
 */
public class MetaLeadRetryBatch implements Database.Batchable<sObject>, Schedulable {
    
    // Schedulable method allows scheduling via UI
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new MetaLeadRetryBatch(), 50);
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Query failed logs from the last 7 days
        return Database.getQueryLocator([
            SELECT Id
            FROM Meta_Lead_Log__c
            WHERE Processing_Status__c = 'Failed'
            AND CreatedDate = LAST_N_DAYS:7
        ]);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Id> logIds = new List<Id>();
        for (SObject obj : scope) {
            logIds.add((Id)obj.get('Id'));
        }
        
        if (!logIds.isEmpty() && !Test.isRunningTest()) {
            // Hand off to our newly bulkified Queueable class
            // (Limit: 1 Queueable enqueue allowed per batch execute)
            System.enqueueJob(new MetaLeadCalloutJob(logIds));
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('MetaLeadRetryBatch completed.');
    }
}

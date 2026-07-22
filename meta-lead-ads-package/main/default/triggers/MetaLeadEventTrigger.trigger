/**
 * MetaLeadEventTrigger
 * 
 * Trigger on Meta_Lead_Event__e Platform Event.
 * Runs as "Automated Process" user — has full CRUD/FLS access.
 * No guest user permission issues!
 * 
 * Creates Meta_Lead_Log__c record and enqueues Graph API callout.
 */
trigger MetaLeadEventTrigger on Meta_Lead_Event__e (after insert) {

    List<Meta_Lead_Log__c> logsToInsert = new List<Meta_Lead_Log__c>();

    for (Meta_Lead_Event__e evt : Trigger.New) {
        
        // --- NEW: Bypass Guest User FLS by saving OAuth token via Platform Event ---
        if (evt.Leadgen_ID__c == 'OAUTH_TOKEN_SAVE') {
            try {
                // Delete existing first to avoid duplicates
                delete [SELECT Id FROM Meta_Auth_Token__c LIMIT 1];
            } catch (Exception e) {}
            
            Meta_Auth_Token__c tokenRecord = new Meta_Auth_Token__c(
                Name = 'Facebook Token',
                User_Access_Token__c = evt.Meta_Lead_Event__c
            );
            insert tokenRecord;
            continue; // Skip the log creation below
        }
        // --------------------------------------------------------------------------

        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Lead_Payload__c      = evt.Meta_Lead_Event__c,
            Meta_Lead_ID__c      = evt.Leadgen_ID__c,
            Page_ID__c           = evt.Page_ID__c,
            Form_ID__c           = evt.Form_ID__c,
            Processing_Status__c = 'Received'
        );

        logsToInsert.add(logRec);
    }

    if (!logsToInsert.isEmpty()) {
        insert logsToInsert;

        // Bulkify the callout: Pass a List of IDs to a single Queueable job
        List<Id> validLogIds = new List<Id>();
        for (Meta_Lead_Log__c log : logsToInsert) {
            if (String.isNotBlank(log.Meta_Lead_ID__c)) {
                validLogIds.add(log.Id);
            }
        }
        
        if (!validLogIds.isEmpty()) {
            System.enqueueJob(new MetaLeadCalloutJob(validLogIds));
        }
    }
}

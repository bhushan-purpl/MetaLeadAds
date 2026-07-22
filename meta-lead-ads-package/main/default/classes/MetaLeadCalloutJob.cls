/**
 * MetaLeadCalloutJob
 * 
 * Queueable class that makes an HTTP callout to the Meta Graph API
 * to fetch actual lead data (name, email, phone) using the leadgen_id
 * received from the webhook notification.
 * 
 * Then creates a Salesforce Lead with the real data and updates the
 * Meta_Lead_Log__c record with the result.
 */
public class MetaLeadCalloutJob implements Queueable, Database.AllowsCallouts {

    private List<Id> logRecordIds;

    public MetaLeadCalloutJob(List<Id> logRecordIds) {
        this.logRecordIds = logRecordIds;
    }

    public void execute(QueueableContext context) {

        // Enforce max 50 callouts per transaction (leaving buffer for other limits)
        List<Id> currentBatchIds = new List<Id>();
        List<Id> nextBatchIds = new List<Id>();
        
        for (Integer i = 0; i < logRecordIds.size(); i++) {
            if (i < 50) {
                currentBatchIds.add(logRecordIds[i]);
            } else {
                nextBatchIds.add(logRecordIds[i]);
            }
        }

        List<Meta_Lead_Log__c> logs = [
            SELECT Id, Meta_Lead_ID__c, Page_ID__c, Form_ID__c,
                   Processing_Status__c, Salesforce_Lead_ID__c,
                   Error_Message__c
            FROM Meta_Lead_Log__c
            WHERE Id IN :currentBatchIds
        ];

        Meta_Integration_Settings__mdt settings = Meta_Integration_Settings__mdt.getInstance('Default');
        String apiVersion = (settings != null && String.isNotBlank(settings.Graph_API_Version__c))
                              ? settings.Graph_API_Version__c
                              : 'v25.0';

        Map<String, String> pageTokenCache = new Map<String, String>();
        
        List<Lead> leadsToInsert = new List<Lead>();
        Map<Integer, Meta_Lead_Log__c> leadIndexToLogMap = new Map<Integer, Meta_Lead_Log__c>();
        List<Meta_Lead_Log__c> logsToUpdate = new List<Meta_Lead_Log__c>();
        List<ContentVersion> cvsToInsert = new List<ContentVersion>();

        for (Meta_Lead_Log__c logRec : logs) {
            // Idempotency check
            if (String.isNotBlank(logRec.Salesforce_Lead_ID__c)) {
                continue; 
            }

            try {
                String leadgenId = logRec.Meta_Lead_ID__c;

                String accessToken = pageTokenCache.get(logRec.Page_ID__c);
                Boolean isLeadCreationEnabled = true;

                if (accessToken == null) {
                    // Try new object first
                    String pageIdStr = logRec.Page_ID__c;
                    List<SObject> pages = Database.query('SELECT Access_Token__c FROM Meta_Page__c WHERE Page_ID__c = :pageIdStr AND Active__c = true LIMIT 1');
                    if (!pages.isEmpty() && String.isNotBlank((String)pages[0].get('Access_Token__c'))) {
                        accessToken = (String)pages[0].get('Access_Token__c');
                    } 
                    
                    // ALWAYS fetch subscription to check toggle status
                    List<Meta_Page_Subscription__c> subPages = [
                        SELECT Page_Access_Token__c, Enable_Lead_Creation__c
                        FROM Meta_Page_Subscription__c 
                        WHERE Page_ID__c = :logRec.Page_ID__c 
                        AND Status__c = 'Active' 
                        LIMIT 1
                    ];
                    
                    if (!subPages.isEmpty()) {
                        isLeadCreationEnabled = subPages[0].Enable_Lead_Creation__c;
                        // Use this token if we didn't find one in Meta_Page__c
                        if (String.isBlank(accessToken) && String.isNotBlank(subPages[0].Page_Access_Token__c)) {
                            accessToken = subPages[0].Page_Access_Token__c;
                        }
                    }

                    if (String.isNotBlank(accessToken)) {
                        pageTokenCache.put(logRec.Page_ID__c, accessToken);
                    } else {
                        throw new MetaLeadException('No active Page Subscription found for Page ID: ' + logRec.Page_ID__c);
                    }
                }

                if (isLeadCreationEnabled == false) {
                    logRec.Processing_Status__c = 'Success - Lead Creation Disabled';
                    logRec.Error_Message__c = 'Lead creation is disabled for this page via UI toggle.';
                    logsToUpdate.add(logRec);
                    continue; // Skip callout and lead creation
                }

                String endpoint = 'https://graph.facebook.com/' + apiVersion + '/' + leadgenId
                                + '?fields=id,created_time,field_data,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,platform,is_organic'
                                + '&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setTimeout(30000);

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() != 200) {
                    throw new MetaLeadException('Graph API Error (' + res.getStatusCode() + '): ' + res.getBody());
                }

                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> fieldData = (List<Object>) responseMap.get('field_data');
                
                if (fieldData == null) {
                    throw new MetaLeadException('No field_data returned in the Graph API response.');
                }

                Map<String, String> leadFields = new Map<String, String>();
                
                // Extract every top-level standard Meta field automatically
                for (String key : responseMap.keySet()) {
                    Object value = responseMap.get(key);
                    if (value != null && !(value instanceof List<Object>) && !(value instanceof Map<String, Object>)) {
                        leadFields.put(key.toLowerCase(), String.valueOf(value));
                    }
                }
                
                for (Object fieldObj : fieldData) {
                    Map<String, Object> field = (Map<String, Object>) fieldObj;
                    String fName = (String) field.get('name');
                    List<Object> fValues = (List<Object>) field.get('values');
                    if (fValues != null && !fValues.isEmpty()) {
                        List<String> strValues = new List<String>();
                        for (Object val : fValues) {
                            if (val != null) strValues.add(String.valueOf(val));
                        }
                        leadFields.put(fName.toLowerCase(), String.join(strValues, ';'));
                    }
                }
                leadFields.put('leadgen_id', leadgenId);

                Lead newLead = new Lead();
                Boolean usedDynamicMapping = false;

                try {
                    List<Meta_Field_Mapping__c> dynamicMappings = [
                        SELECT Facebook_Field__c, Salesforce_Field__c, Is_UTM__c
                        FROM Meta_Field_Mapping__c
                        WHERE Form_ID__c = :logRec.Form_ID__c
                        AND Active__c = true
                    ];

                    if (!dynamicMappings.isEmpty()) {
                        usedDynamicMapping = true;
                        for (Meta_Field_Mapping__c m : dynamicMappings) {
                            String originalFbKey = m.Facebook_Field__c != null ? m.Facebook_Field__c : '';
                            String fbKey  = originalFbKey.toLowerCase();
                            String sfField = m.Salesforce_Field__c;
                            if (String.isBlank(sfField) || String.isBlank(fbKey)) continue;
                            String val;
                            if (fbKey.startsWith('static::')) {
                                val = originalFbKey.length() > 8 ? originalFbKey.substring(8) : '';
                            } else {
                                val = leadFields.get(fbKey);
                            }
                            if (String.isBlank(val)) continue;
                            if (sfField == 'Name' || sfField == 'full_name') {
                                List<String> parts = val.trim().split('\\s+', 2);
                                newLead.FirstName = parts[0];
                                newLead.LastName  = parts.size() > 1 ? parts[1] : parts[0];
                            } else {
                                try { newLead.put(sfField, val); } catch (Exception ex) {}
                            }
                        }
                    }
                } catch (Exception dynEx) {
                    usedDynamicMapping = true;
                }

                if (String.isBlank(newLead.LastName)) {
                    String fullName  = leadFields.get('full_name');
                    String firstName = leadFields.get('first_name');
                    String lastName  = leadFields.get('last_name');
                    if (String.isNotBlank(fullName)) {
                        List<String> nameParts = fullName.trim().split('\\s+', 2);
                        newLead.FirstName = nameParts[0];
                        newLead.LastName  = nameParts.size() > 1 ? nameParts[1] : nameParts[0];
                    } else if (String.isNotBlank(firstName) || String.isNotBlank(lastName)) {
                        newLead.FirstName = firstName;
                        newLead.LastName  = String.isNotBlank(lastName) ? lastName : firstName;
                    } else {
                        newLead.LastName = 'Meta Lead ' + leadgenId;
                    }
                }
                if (String.isBlank(newLead.Email)) {
                    newLead.Email = leadFields.containsKey('email') ? leadFields.get('email') : leadFields.get('work_email');
                }
                if (String.isBlank(newLead.Phone)) {
                    String phoneVal = leadFields.containsKey('phone_number') ? leadFields.get('phone_number') : 
                                      leadFields.containsKey('work_phone_number') ? leadFields.get('work_phone_number') : 
                                      leadFields.get('phone');
                    newLead.Phone = phoneVal;
                    newLead.MobilePhone = phoneVal;
                }
                if (String.isBlank(newLead.Company)) {
                    String co = leadFields.get('company_name');
                    if (String.isBlank(co)) co = leadFields.get('organization');
                    if (String.isBlank(co)) co = leadFields.get('company');
                    if (String.isBlank(co)) co = 'Meta Lead';
                    newLead.Company = co;
                }
                if (String.isBlank(newLead.City))       newLead.City       = leadFields.get('city');
                if (String.isBlank(newLead.State))      newLead.State      = leadFields.get('state');
                if (String.isBlank(newLead.PostalCode)) newLead.PostalCode = leadFields.get('zip_code');
                if (String.isBlank(newLead.Country))    newLead.Country    = leadFields.get('country');

                if (!usedDynamicMapping) {
                    try {
                        String query = 'SELECT Meta_Field_Name__c, Salesforce_Field_API_Name__c';
                        Boolean hasFormIdField = false;
                        Boolean hasStaticValueField = false;
                        try {
                            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('Meta_Field_Mapping__mdt').getDescribe().fields.getMap();
                            if (fieldMap.containsKey('Form_ID__c') || fieldMap.containsKey('form_id__c')) { query += ', Form_ID__c'; hasFormIdField = true; }
                            if (fieldMap.containsKey('Static_Value__c') || fieldMap.containsKey('static_value__c')) { query += ', Static_Value__c'; hasStaticValueField = true; }
                        } catch (Exception ex) {}
                        query += ' FROM Meta_Field_Mapping__mdt';
                        // FIX SOQL Injection: Use bind variables instead of string concatenation
                        String formIdStr = logRec.Form_ID__c;
                        if (hasFormIdField) {
                            query += ' WHERE Form_ID__c = :formIdStr OR Form_ID__c = null';
                        }
                        
                        for (SObject mappingObj : Database.query(query)) {
                            String sfField = (String) mappingObj.get('Salesforce_Field_API_Name__c');
                            if (String.isBlank(sfField)) continue;
                            String finalValue = null;
                            String metaField = (String) mappingObj.get('Meta_Field_Name__c');
                            if (String.isNotBlank(metaField) && leadFields.containsKey(metaField.toLowerCase())) {
                                finalValue = leadFields.get(metaField.toLowerCase());
                            }
                            if (String.isBlank(finalValue) && hasStaticValueField) {
                                finalValue = (String) mappingObj.get('Static_Value__c');
                            }
                            if (String.isNotBlank(finalValue)) {
                                try { newLead.put(sfField, finalValue); } catch (Exception ex) {}
                            }
                        }
                    } catch (Exception e) {}
                }

                try {
                    List<Meta_Lead_Assignment__c> assignments = [
                        SELECT Owner_Type__c, Owner_ID__c
                        FROM Meta_Lead_Assignment__c
                        WHERE Form_ID__c = :logRec.Form_ID__c AND Active__c = true
                        LIMIT 1
                    ];
                    if (!assignments.isEmpty() && String.isNotBlank(assignments[0].Owner_ID__c)) {
                        newLead.OwnerId = (Id) assignments[0].Owner_ID__c;
                    }
                } catch (Exception assignEx) {}

                if (String.isBlank(newLead.LeadSource)) {
                    newLead.LeadSource  = 'Meta Lead Ad';
                }
                newLead.Description = 'Meta LeadGen ID: ' + leadgenId;

                if (responseMap.containsKey('campaign_name')) {
                    newLead.Description += '\nCampaign: ' + String.valueOf(responseMap.get('campaign_name'));
                }
                if (responseMap.containsKey('ad_name')) {
                    newLead.Description += '\nAd: ' + String.valueOf(responseMap.get('ad_name'));
                }

                String prettyJson = JSON.serializePretty(responseMap);
                logRec.Raw_Lead_Data__c = prettyJson.abbreviate(32768);
                
                ContentVersion cv = new ContentVersion();
                cv.Title = 'MetaLead_' + leadgenId + '.json';
                cv.PathOnClient = 'MetaLead_' + leadgenId + '.json';
                cv.VersionData = Blob.valueOf(prettyJson);
                cv.FirstPublishLocationId = logRec.Id;
                cvsToInsert.add(cv);

                leadsToInsert.add(newLead);
                leadIndexToLogMap.put(leadsToInsert.size() - 1, logRec);

            } catch (Exception e) {
                logRec.Processing_Status__c = 'Failed';
                logRec.Error_Message__c     = e.getMessage().abbreviate(255);
                logsToUpdate.add(logRec);
            }
        }
        
        // DML Operations
        if (!leadsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(leadsToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                Meta_Lead_Log__c logRec = leadIndexToLogMap.get(i);
                if (results[i].isSuccess()) {
                    logRec.Salesforce_Lead_ID__c = results[i].getId();
                    logRec.Processing_Status__c  = 'Success';
                    logRec.Error_Message__c      = null;
                } else {
                    String errStr = '';
                    for (Database.Error err : results[i].getErrors()) {
                        errStr += err.getStatusCode() + ': ' + err.getMessage() + ' ';
                    }
                    logRec.Processing_Status__c = 'Failed';
                    logRec.Error_Message__c = ('Lead insert failed: ' + errStr).abbreviate(255);
                }
                logsToUpdate.add(logRec);
            }
        }
        
        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }

        if (!cvsToInsert.isEmpty()) {
            try {
                insert cvsToInsert;
            } catch (Exception ex) {
                System.debug('Failed to insert JSON attachments: ' + ex.getMessage());
            }
        }

        // Chain the Queueable if there are more logs to process
        if (!nextBatchIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new MetaLeadCalloutJob(nextBatchIds));
        }
    }

    public class MetaLeadException extends Exception {}
}

public without sharing class MetaLeadAssignmentService {

    @AuraEnabled(cacheable=false)
    public static Meta_Lead_Assignment__c getAssignment(String formId) {
        List<Meta_Lead_Assignment__c> assignments = [
            SELECT Id, Form__c, Form_ID__c, Owner_Type__c, Owner_ID__c, Owner_Name__c, Active__c
            FROM Meta_Lead_Assignment__c
            WHERE Form_ID__c = :formId AND Active__c = true
            LIMIT 1
        ];
        return assignments.isEmpty() ? null : assignments[0];
    }

    @AuraEnabled
    public static String saveAssignment(String formId, String ownerType, String ownerId, String ownerName) {
        try {
            List<Meta_Form__c> forms = [SELECT Id FROM Meta_Form__c WHERE Form_ID__c = :formId LIMIT 1];
            Id formRecId = forms.isEmpty() ? null : forms[0].Id;

            List<Meta_Lead_Assignment__c> existing = [SELECT Id FROM Meta_Lead_Assignment__c WHERE Form_ID__c = :formId LIMIT 1];
            Meta_Lead_Assignment__c assignment = existing.isEmpty() ? new Meta_Lead_Assignment__c() : existing[0];
            assignment.Form__c       = formRecId;
            assignment.Form_ID__c    = formId;
            assignment.Owner_Type__c = ownerType;
            assignment.Owner_ID__c   = ownerId;
            assignment.Owner_Name__c = ownerName;
            assignment.Active__c     = true;
            upsert assignment;
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException('Save assignment failed: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getQueues() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (Group g : [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND Id IN (SELECT QueueId FROM QueueSobject WHERE SobjectType = 'Lead') ORDER BY Name]) {
            Map<String, String> item = new Map<String, String>();
            item.put('value', g.Id);
            item.put('label', g.Name);
            result.add(item);
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getUsers() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (User u : [SELECT Id, Name FROM User WHERE IsActive = true ORDER BY Name LIMIT 200]) {
            Map<String, String> item = new Map<String, String>();
            item.put('value', u.Id);
            item.put('label', u.Name);
            result.add(item);
        }
        return result;
    }
}
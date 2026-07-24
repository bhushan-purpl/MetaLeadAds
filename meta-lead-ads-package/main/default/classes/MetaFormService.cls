public without sharing class MetaFormService {

    private static String getApiVersion() {
        Meta_Integration_Settings__mdt s = Meta_Integration_Settings__mdt.getInstance('Default');
        return (s != null && String.isNotBlank(s.Graph_API_Version__c)) ? s.Graph_API_Version__c : 'v25.0';
    }

    private static String getPageToken(String pageId) {
        // First try Meta_Page__c (new), then fall back to Meta_Page_Subscription__c (old)
        List<Meta_Page__c> pages = [SELECT Access_Token__c FROM Meta_Page__c WHERE Page_ID__c = :pageId AND Active__c = true LIMIT 1];
        if (!pages.isEmpty() && String.isNotBlank(pages[0].Access_Token__c)) return pages[0].Access_Token__c.trim();
        List<Meta_Page_Subscription__c> subs = [SELECT Page_Access_Token__c FROM Meta_Page_Subscription__c WHERE Page_ID__c = :pageId AND Status__c = 'Active' LIMIT 1];
        if (!subs.isEmpty() && String.isNotBlank(subs[0].Page_Access_Token__c)) return subs[0].Page_Access_Token__c.trim();
        
        // Fall back to Metadata
        Meta_Integration_Settings__mdt config = Meta_Integration_Settings__mdt.getInstance('Default');
        if (config != null && String.isNotBlank(config.Page_Access_Token__c)) {
            return config.Page_Access_Token__c.trim();
        }
        
        throw new AuraHandledException('No access token found for page: ' + pageId);
    }

    public class FormWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Form_ID;
        @AuraEnabled public String Form_Name;
        @AuraEnabled public String Page_ID;
        @AuraEnabled public Decimal Question_Count;
        @AuraEnabled public String Status;
        @AuraEnabled public Boolean Is_Mapped;
        @AuraEnabled public Integer Total_Fields;
        @AuraEnabled public Integer Mapped_Fields;
    }

    private static List<FormWrapper> wrapForms(List<Meta_Form__c> forms) {
        Set<String> formIds = new Set<String>();
        for (Meta_Form__c f : forms) {
            if (String.isNotBlank(f.Form_ID__c)) {
                formIds.add(f.Form_ID__c);
            }
        }
        
        Map<String, Integer> mappedCounts = new Map<String, Integer>();
        if (!formIds.isEmpty()) {
            for (AggregateResult ar : [SELECT Form_ID__c formId, COUNT(Id) cnt FROM Meta_Field_Mapping__c WHERE Form_ID__c IN :formIds AND Active__c = true AND Salesforce_Field__c != null AND (NOT Facebook_Field__c LIKE 'static::%') GROUP BY Form_ID__c]) {
                mappedCounts.put((String)ar.get('formId'), (Integer)ar.get('cnt'));
            }
        }

        List<FormWrapper> wrappers = new List<FormWrapper>();
        for (Meta_Form__c f : forms) {
            FormWrapper w = new FormWrapper();
            w.Id = f.Id;
            w.Form_ID = f.Form_ID__c;
            w.Form_Name = f.Form_Name__c;
            w.Page_ID = f.Page_ID__c;
            w.Question_Count = f.Question_Count__c;
            w.Status = f.Status__c;
            w.Is_Mapped = f.Is_Mapped__c;
            
            w.Mapped_Fields = mappedCounts.containsKey(f.Form_ID__c) ? mappedCounts.get(f.Form_ID__c) : 0;
            
            Integer fbQuestionsCount = 0;
            if (String.isNotBlank(f.Questions_JSON__c)) {
                try {
                    List<Object> qList = (List<Object>) JSON.deserializeUntyped(f.Questions_JSON__c);
                    fbQuestionsCount = qList.size();
                } catch(Exception e) {}
            }
            w.Total_Fields = fbQuestionsCount + 24; // 24 tracking parameters always added

            wrappers.add(w);
        }
        return wrappers;
    }

    @AuraEnabled
    public static List<FormWrapper> syncForms(String pageId) {
        String token = getPageToken(pageId);
        String endpoint = 'https://graph.facebook.com/' + getApiVersion() + '/' + pageId + '/leadgen_forms?access_token=' + token + '&fields=id,name,question_count,status';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) throw new AuraHandledException('Failed to fetch forms: ' + res.getBody());

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> data = (List<Object>) parsed.get('data');

        // Find parent page record Id
        List<Meta_Page__c> pageRecs = [SELECT Id FROM Meta_Page__c WHERE Page_ID__c = :pageId LIMIT 1];
        Id pageRecId = pageRecs.isEmpty() ? null : pageRecs[0].Id;

        List<Meta_Form__c> formsToUpsert = new List<Meta_Form__c>();
        if (data != null) {
            for (Object obj : data) {
                Map<String, Object> f = (Map<String, Object>) obj;
                Meta_Form__c form = new Meta_Form__c();
                form.Form_ID__c       = (String) f.get('id');
                form.Form_Name__c     = (String) f.get('name');
                form.Page_ID__c       = pageId;
                form.Page__c          = pageRecId;
                form.Question_Count__c = f.get('question_count') != null ? Decimal.valueOf(String.valueOf(f.get('question_count'))) : 0;
                form.Status__c        = 'Active';
                formsToUpsert.add(form);
            }
        }
        if (!formsToUpsert.isEmpty()) upsert formsToUpsert Form_ID__c;
        MetaPageService.refreshPageFormCounts();
        List<Meta_Form__c> records = [SELECT Id, Form_ID__c, Form_Name__c, Page_ID__c, Question_Count__c, Status__c, Is_Mapped__c, Questions_JSON__c FROM Meta_Form__c WHERE Page_ID__c = :pageId ORDER BY Form_Name__c];
        return wrapForms(records);
    }

    @AuraEnabled(cacheable=false)
    public static List<FormWrapper> getForms(String pageId) {
        List<Meta_Form__c> records = [SELECT Id, Form_ID__c, Form_Name__c, Page_ID__c, Question_Count__c, Status__c, Is_Mapped__c, Questions_JSON__c FROM Meta_Form__c WHERE Page_ID__c = :pageId ORDER BY Form_Name__c];
        return wrapForms(records);
    }

    @AuraEnabled
    public static List<Map<String, String>> syncFormQuestions(String formId, String pageId) {
        String token = getPageToken(pageId);
        String endpoint = 'https://graph.facebook.com/' + getApiVersion() + '/' + formId + '?fields=questions&access_token=' + token;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) throw new AuraHandledException('Failed to fetch questions: ' + res.getBody());

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> questions = (List<Object>) parsed.get('questions');

        List<Map<String, String>> result = new List<Map<String, String>>();
        String questionsJson = JSON.serialize(questions);

        if (questions != null) {
            for (Object q : questions) {
                Map<String, Object> qMap = (Map<String, Object>) q;
                Map<String, String> item = new Map<String, String>();
                item.put('key',   String.valueOf(qMap.get('key')));
                item.put('label', String.valueOf(qMap.containsKey('label') ? qMap.get('label') : qMap.get('key')));
                item.put('type',  String.valueOf(qMap.containsKey('type')  ? qMap.get('type')  : 'TEXT'));
                result.add(item);
            }
        }

        // Store questions JSON on the form record
        List<Meta_Form__c> forms = [SELECT Id FROM Meta_Form__c WHERE Form_ID__c = :formId LIMIT 1];
        if (!forms.isEmpty()) {
            forms[0].Questions_JSON__c = questionsJson;
            update forms[0];
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getFormQuestions(String formId) {
        List<Meta_Form__c> forms = [SELECT Questions_JSON__c FROM Meta_Form__c WHERE Form_ID__c = :formId LIMIT 1];
        if (forms.isEmpty() || String.isBlank(forms[0].Questions_JSON__c)) return new List<Map<String, String>>();
        List<Object> questions = (List<Object>) JSON.deserializeUntyped(forms[0].Questions_JSON__c);
        List<Map<String, String>> result = new List<Map<String, String>>();
        if (questions != null) {
            for (Object q : questions) {
                Map<String, Object> qMap = (Map<String, Object>) q;
                Map<String, String> item = new Map<String, String>();
                item.put('key',   String.valueOf(qMap.get('key')));
                item.put('label', String.valueOf(qMap.containsKey('label') ? qMap.get('label') : qMap.get('key')));
                result.add(item);
            }
        }
        return result;
    }
}
@isTest
private class MetaFormServiceTest {

    private class FormMock implements HttpCalloutMock {
        private String type;
        public FormMock(String type) { this.type = type; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (type == 'forms') {
                res.setBody('{"data":[{"id":"111","name":"Form1","question_count":3}]}');
            } else {
                res.setBody('{"questions":[{"key":"email","label":"Email","type":"TEXT"}]}');
            }
            return res;
        }
    }

    @testSetup
    static void setupData() {
        Meta_Page__c page = new Meta_Page__c(Page_ID__c = '123', Access_Token__c = 'mocktoken', Active__c = true);
        insert page;

        Meta_Form__c form = new Meta_Form__c(Form_ID__c = '111', Page_ID__c = '123', Questions_JSON__c = '[{"key":"email","label":"Email"}]');
        insert form;
    }

    @isTest
    static void testSyncForms() {
        Test.setMock(HttpCalloutMock.class, new FormMock('forms'));
        Test.startTest();
        List<MetaFormService.FormWrapper> forms = MetaFormService.syncForms('123');
        Test.stopTest();
        System.assert(forms.size() > 0);
    }

    @isTest
    static void testGetForms() {
        Test.startTest();
        List<MetaFormService.FormWrapper> forms = MetaFormService.getForms('123');
        Test.stopTest();
        System.assertEquals(1, forms.size());
    }

    @isTest
    static void testSyncFormQuestions() {
        Test.setMock(HttpCalloutMock.class, new FormMock('questions'));
        Test.startTest();
        List<Map<String, String>> questions = MetaFormService.syncFormQuestions('111', '123');
        Test.stopTest();
        System.assert(questions.size() > 0);
    }

    @isTest
    static void testGetFormQuestions() {
        Test.startTest();
        List<Map<String, String>> questions = MetaFormService.getFormQuestions('111');
        Test.stopTest();
        System.assertEquals(1, questions.size());
    }
}

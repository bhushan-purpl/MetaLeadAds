@isTest
private class MetaLeadIntelligenceControllerTest {

    @testSetup
    static void setupData() {
        // Active License
        insert new Meta_License_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(30)
        );

        // Page and Form
        Meta_Page__c page = new Meta_Page__c(Page_ID__c = 'PAGE-123', Page_Name__c = 'Test Facebook Page', Active__c = true);
        insert page;

        Meta_Form__c form = new Meta_Form__c(Form_ID__c = 'FORM-123', Form_Name__c = 'Test Form', Page_ID__c = 'PAGE-123', Page__c = page.Id);
        insert form;

        Lead l1 = new Lead(FirstName = 'Amit', LastName = 'Sharma', Email = 'amit@example.com', Phone = '9876543210', Company = 'Acme', Status = 'Working', LeadSource = 'PurplSync');
        Lead l2 = new Lead(FirstName = 'Rahul', LastName = 'Verma', Email = 'rahul@example.com', Phone = '9876543211', Company = 'Beta', Status = 'Qualified', LeadSource = 'PurplSync');
        
        // Dynamically set Integration_Source__c if present
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        String intSourceApi = leadFields.containsKey('purpl__integration_source__c') ? 'purpl__Integration_Source__c' : 
                              (leadFields.containsKey('integration_source__c') ? 'Integration_Source__c' : null);
        if (intSourceApi != null) {
            l1.put(intSourceApi, 'PurplSync');
            l2.put(intSourceApi, 'PurplSync');
        }

        List<Lead> leads = new List<Lead>{ l1, l2 };
        insert leads;

        // Meta Lead Log
        Meta_Lead_Log__c log1 = new Meta_Lead_Log__c(
            Meta_Lead_ID__c = 'META-LEAD-101',
            Page_ID__c = 'PAGE-123',
            Form_ID__c = 'FORM-123',
            Processing_Status__c = 'Success',
            Salesforce_Lead_ID__c = leads[0].Id
        );
        Meta_Lead_Log__c log2 = new Meta_Lead_Log__c(
            Meta_Lead_ID__c = 'META-LEAD-102',
            Page_ID__c = 'PAGE-123',
            Form_ID__c = 'FORM-123',
            Processing_Status__c = 'Failed',
            Error_Message__c = 'Duplicate Lead'
        );
        insert new List<Meta_Lead_Log__c>{ log1, log2 };
    }

    @isTest
    static void testGetDashboardData() {
        Test.startTest();
        String filterJson = '{"dateRange":"All Time","searchKey":"Amit"}';
        MetaLeadIntelligenceController.DashboardDataWrapper data = MetaLeadIntelligenceController.getDashboardData(filterJson);
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.leads.size() > 0);
        System.assertNotEquals(null, data.kpiStats);
        System.assert(data.funnelStages.size() > 0);
    }

    @isTest
    static void testGetLeadTimeline() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        List<MetaLeadIntelligenceController.TimelineEvent> timeline = MetaLeadIntelligenceController.getLeadTimeline(l.Id);
        Test.stopTest();

        System.assert(timeline.size() > 0);
    }

    @isTest
    static void testExportLeadsCsv() {
        Test.startTest();
        String csv = MetaLeadIntelligenceController.exportLeadsCsv('{}');
        Test.stopTest();

        System.assert(csv.contains('Lead Name'));
    }
}

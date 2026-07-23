@isTest
private class MetaMappingServiceTest {

    @testSetup
    static void setupData() {
        Meta_Form__c form = new Meta_Form__c(
            Form_ID__c = '12345',
            Name = 'Test Form',
            Questions_JSON__c = '[{"key":"email","label":"Email Address","type":"TEXT"},{"key":"custom_q","label":"Custom Question","type":"CUSTOM"}]'
        );
        insert form;

        Meta_Field_Mapping__c mapping = new Meta_Field_Mapping__c(
            Form__c = form.Id,
            Form_ID__c = '12345',
            Facebook_Field__c = 'email',
            Salesforce_Field__c = 'Email',
            Active__c = true
        );
        insert mapping;
    }

    @isTest
    static void testGetFormFieldsForMapping() {
        Test.startTest();
        List<Map<String, Object>> fields = MetaMappingService.getFormFieldsForMapping('12345', 'page1');
        Test.stopTest();
        System.assert(fields.size() > 0, 'Should return fields including tracking params');
    }

    @isTest
    static void testGetAutoSuggestions() {
        Test.startTest();
        List<Map<String, Object>> suggestions = MetaMappingService.getAutoSuggestions('12345', 'page1');
        Test.stopTest();
        System.assert(suggestions.size() > 0, 'Should return suggestions');
    }

    @isTest
    static void testSaveMappings() {
        String jsonMapping = '[{"facebookField":"email","sfField":"Email","category":"standard"},{"facebookField":"utm_source","sfField":"LeadSource","category":"tracking"}]';
        Test.startTest();
        String result = MetaMappingService.saveMappings('12345', jsonMapping);
        Test.stopTest();
        System.assertEquals('SUCCESS', result);
    }

    @isTest
    static void testGetMappings() {
        Test.startTest();
        List<MetaMappingService.MappingWrapper> mappings = MetaMappingService.getMappings('12345');
        Test.stopTest();
        System.assertEquals(1, mappings.size());
    }

    @isTest
    static void testGetLeadFields() {
        Test.startTest();
        List<Map<String, String>> fields = MetaMappingService.getLeadFields();
        Test.stopTest();
        System.assert(fields.size() > 0, 'Should return Lead fields');
    }

    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<Map<String, String>> picklistValues = MetaMappingService.getPicklistValues('LeadSource');
        List<Map<String, String>> invalidPicklist = MetaMappingService.getPicklistValues('InvalidFieldXYZ');
        Test.stopTest();
        System.assert(picklistValues.size() > 0, 'Should return picklist values for LeadSource');
    }
}

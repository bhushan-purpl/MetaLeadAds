@isTest
private class MetaDashboardControllerTest {
    @testSetup
    static void setupData() {
        insert new Meta_Page__c(Page_ID__c = '111', Active__c = true, Last_Sync__c = Datetime.now());
        insert new Meta_Form__c(Form_ID__c = '222', Status__c = 'Active', Is_Mapped__c = true);
        insert new Meta_Lead_Log__c(Meta_Lead_ID__c = '333', Processing_Status__c = 'Received');
    }

    @isTest
    static void testGetDashboardStats() {
        Test.startTest();
        Map<String, Object> stats = MetaDashboardController.getDashboardStats();
        Test.stopTest();

        System.assertEquals(1, stats.get('connectedPages'));
        System.assertEquals(1, stats.get('totalForms'));
        System.assertEquals(1, stats.get('mappedForms'));
        System.assertEquals('Received', stats.get('lastLeadStatus'));
        System.assertNotEquals(null, stats.get('lastSyncDate'));
        System.assertEquals(1, ((List<Meta_Lead_Log__c>) stats.get('recentLogs')).size());
    }
}

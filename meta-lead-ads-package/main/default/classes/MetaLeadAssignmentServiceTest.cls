@isTest
private class MetaLeadAssignmentServiceTest {

    @testSetup
    static void setupData() {
        insert new Meta_Form__c(Form_ID__c = '111', Name = 'Form1');
    }

    @isTest
    static void testGetSaveAssignment() {
        Test.startTest();
        String res = MetaLeadAssignmentService.saveAssignment('111', 'User', UserInfo.getUserId(), 'Test User');
        System.assertEquals('SUCCESS', res);
        
        Meta_Lead_Assignment__c assignment = MetaLeadAssignmentService.getAssignment('111');
        System.assertNotEquals(null, assignment);
        
        List<Map<String, String>> users = MetaLeadAssignmentService.getUsers();
        System.assert(users.size() > 0);
        
        List<Map<String, String>> queues = MetaLeadAssignmentService.getQueues();
        Test.stopTest();
    }
}

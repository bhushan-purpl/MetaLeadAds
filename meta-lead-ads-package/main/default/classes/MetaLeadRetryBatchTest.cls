@isTest
private class MetaLeadRetryBatchTest {

    @isTest
    static void testBatchExecution() {
        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c = '123456789012',
            Page_ID__c = '1001180569754985',
            Processing_Status__c = 'Failed',
            Error_Message__c = 'Initial error'
        );
        insert logRec;

        Test.startTest();
        MetaLeadRetryBatch batch = new MetaLeadRetryBatch();
        Database.executeBatch(batch);

        // Also test Schedulable execute
        String cronExpr = '0 0 0 15 3 ? 2030';
        System.schedule('TestMetaLeadRetryBatchSched', cronExpr, new MetaLeadRetryBatch());
        Test.stopTest();

        System.assertEquals(1, [SELECT count() FROM Meta_Lead_Log__c WHERE Processing_Status__c = 'Failed']);
    }
}

@isTest
private class MetaPackageUninstallHandlerTest {
    @isTest
    static void testUninstallHandler() {
        // Schedule a dummy job so that there is a CronTrigger to abort.
        // It's tricky to schedule an actual class if it requires callouts or complex setup, 
        // but we can schedule AnalyticsScheduler which is part of our package.
        
        Test.startTest();
        String cronExp = '0 0 0 15 3 ? 2042';
        System.schedule('TestAnalyticsScheduler', cronExp, new AnalyticsScheduler());
        
        MetaPackageUninstallHandler handler = new MetaPackageUninstallHandler();
        Test.testUninstall(handler);
        Test.stopTest();
        
        // Assert that the scheduled job was aborted. We can check if any CronTrigger with that name still exists
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'TestAnalyticsScheduler'];
        System.assertEquals(0, jobs.size(), 'Scheduled job should be aborted upon uninstallation');
    }
}

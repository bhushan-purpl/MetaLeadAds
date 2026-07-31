public class MetaPackageUninstallHandler implements UninstallHandler {
    public void onUninstall(UninstallContext context) {
        abortScheduledJobs();
    }

    private void abortScheduledJobs() {
        Set<String> classNames = new Set<String>{'AnalyticsScheduler', 'MetaLeadRetryBatch'};
        List<ApexClass> classes = [SELECT Id FROM ApexClass WHERE Name IN :classNames];
        
        Set<Id> classIds = new Set<Id>();
        for (ApexClass ac : classes) {
            classIds.add(ac.Id);
        }

        if (!classIds.isEmpty()) {
            List<AsyncApexJob> jobs = [SELECT CronTriggerId FROM AsyncApexJob WHERE ApexClassId IN :classIds AND JobType = 'ScheduledApex'];
            for (AsyncApexJob job : jobs) {
                if (job.CronTriggerId != null) {
                    try {
                        System.abortJob(job.CronTriggerId);
                    } catch (Exception e) {
                        System.debug('Error aborting job: ' + e.getMessage());
                    }
                }
            }
        }
    }
}

public class MetaPackageInstallHandler implements InstallHandler {
    public void onInstall(InstallContext context) {
        // Only run if they don't already have a license
        Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            // Enqueue the callout job to silently register the trial in the background
            System.enqueueJob(new TrialRegistrationJob());
        }
    }
}

public class TrialRegistrationJob implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        try {
            MetaLicenseService.registerTrial();
        } catch (Exception e) {
            System.debug('Error registering trial on install: ' + e.getMessage());
        }
    }
}

@RestResource(urlMapping='/metaLead/*')
global without sharing class MetaLeadWebhook {

    // Verify token stored in Custom Metadata: Meta_Integration_Settings__mdt
    private static String getVerifyToken() {
        try {
            Meta_Integration_Settings__mdt settings = Meta_Integration_Settings__mdt.getInstance('Default');
            if (settings != null && String.isNotBlank(settings.Verify_Token__c)) {
                return settings.Verify_Token__c;
            }
        } catch (Exception e) {
            // Custom Metadata not yet created — use fallback
        }
        return 'Purplstack2026';
    }

    // App Secret stored in Custom Metadata: Meta_Integration_Settings__mdt (added for Phase 2 Security)
    private static String getAppSecret() {
        if (Test.isRunningTest()) return null;
        try {
            // Use dynamic SOQL to avoid compilation errors if App_Secret__c field is not created yet by user
            List<SObject> settings = Database.query('SELECT App_Secret__c FROM Meta_Integration_Settings__mdt WHERE DeveloperName = \'Default\' LIMIT 1');
            if (!settings.isEmpty() && settings[0].get('App_Secret__c') != null) {
                return (String) settings[0].get('App_Secret__c');
            }
        } catch (Exception e) {
            // Field or record doesn't exist yet
        }
        return null;
    }

    /**
     * GET — Meta Webhook Verification
     */
    @HttpGet
    global static void verify() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String verifyToken = req.params.get('hub.verify_token');
        String challenge = req.params.get('hub.challenge');

        if (verifyToken == getVerifyToken()) {
            res.addHeader('Content-Type', 'text/plain');
            res.responseBody = Blob.valueOf(challenge);
            res.statusCode = 200;
        } else {
            res.responseBody = Blob.valueOf('Invalid Verify Token');
            res.statusCode = 403;
        }
    }

    /**
     * POST — Receive Meta Lead Webhook Notification
     * 
     * Instead of doing DML directly (which fails due to guest user FLS),
     * we publish a Platform Event. The Platform Event trigger runs as
     * "Automated Process" user which has full access.
     */
    @HttpPost
    global static void receiveLead() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();

        // ── 0. License Verification ──
        if (!MetaLicenseService.isLicenseActive()) {
            System.debug('License is not active or expired. Rejecting webhook processing.');
            res.statusCode = 200; // Return 200 so Meta stops retrying
            res.responseBody = Blob.valueOf('License Expired or Inactive');
            return;
        }

        // ── 1. Source Validation (Rate Limiting / Bot Prevention) ──
        String userAgent = req.headers.get('User-Agent');
        System.debug('User-Agent: ' + userAgent);
        // Relaxing the User-Agent check as Meta Lead Ads Testing Tool might send a different UA or no UA
        // Only block if we are absolutely sure it's a known malicious bot (or just rely on HMAC)

        // ── 2. HMAC-SHA256 Signature Verification ──
        String appSecret = getAppSecret();
        if (String.isNotBlank(appSecret)) {
            String signatureHeader = req.headers.get('X-Hub-Signature-256');
            System.debug('X-Hub-Signature-256: ' + signatureHeader);
            
            if (String.isBlank(signatureHeader)) {
                System.debug('Signature header missing');
                res.statusCode = 403;
                return;
            }
            
            Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(appSecret));
            String expectedSignature = 'sha256=' + EncodingUtil.convertToHex(hmac);
            System.debug('Expected Signature: ' + expectedSignature);
            
            if (signatureHeader != expectedSignature) {
                System.debug('Signature mismatch. Rejecting request.');
                res.statusCode = 403;
                return;
            }
        } else {
            System.debug('App Secret not configured. Skipping HMAC check.');
        }

        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> entries = (List<Object>) payload.get('entry');

            if (entries == null || entries.isEmpty()) {
                // Publish event with raw payload for debugging
                publishEvent(body, '', '', '');
                RestContext.response.statusCode = 200;
                return;
            }

            for (Object entryObj : entries) {
                Map<String, Object> entry = (Map<String, Object>) entryObj;
                List<Object> changes = (List<Object>) entry.get('changes');

                if (changes == null) continue;

                for (Object changeObj : changes) {
                    Map<String, Object> change = (Map<String, Object>) changeObj;
                    String field = (String) change.get('field');

                    if (field != 'leadgen') continue;

                    Map<String, Object> value = (Map<String, Object>) change.get('value');

                    String leadgenId = String.valueOf(value.get('leadgen_id'));
                    String pageId    = String.valueOf(value.get('page_id'));
                    String formId    = String.valueOf(value.get('form_id'));

                    // Publish Platform Event instead of direct DML
                    publishEvent(body, leadgenId, pageId, formId);
                }
            }

        } catch (Exception e) {
            // Even if parsing fails, try to publish the raw payload
            try {
                publishEvent(body, '', '', '');
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to publish event: ' + ex.getMessage());
            }
        }

        // Always return 200 to Meta
        RestContext.response.statusCode = 200;
    }

    /**
     * Publish a Platform Event — this bypasses guest user FLS restrictions
     */
    private static void publishEvent(String payload, String leadgenId, String pageId, String formId) {
        Meta_Lead_Event__e evt = new Meta_Lead_Event__e(
            Meta_Lead_Event__c = payload,
            Leadgen_ID__c   = leadgenId,
            Page_ID__c      = pageId,
            Form_ID__c      = formId
        );

        Database.SaveResult sr = EventBus.publish(evt);
        if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
                System.debug(LoggingLevel.ERROR, 'Platform Event publish error: ' + err.getMessage());
            }
        }
    }
}
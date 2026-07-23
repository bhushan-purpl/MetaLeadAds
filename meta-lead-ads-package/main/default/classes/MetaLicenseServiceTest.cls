@isTest
private class MetaLicenseServiceTest {
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public MockHttpResponse(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    @isTest
    static void testRegisterTrial_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"Trial", "expiry":"2030-01-01", "maxPages":1, "licenseKey":"TRIAL-123"}'));

        Test.startTest();
        Map<String, Object> result = MetaLicenseService.registerTrial();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Trial', result.get('Status__c'));
        System.assertEquals(1, result.get('Max_Pages_Allowed__c'));
    }

    @isTest
    static void testRegisterTrial_AlreadyRegistered() {
        Meta_License_Settings__c settings = new Meta_License_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Status__c = 'Active',
            License_Key__c = 'KEY-123',
            Max_Pages_Allowed__c = 5,
            Expiration_Date__c = Date.today().addDays(30)
        );
        insert settings;

        Test.startTest();
        Map<String, Object> result = MetaLicenseService.registerTrial();
        Test.stopTest();

        System.assertEquals('Active', result.get('Status__c'));
        System.assertEquals(5, result.get('Max_Pages_Allowed__c'));
    }

    @isTest
    static void testValidateLicense_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"Active", "expiry":"2030-01-01", "maxPages":10, "licenseKey":"NEW-KEY"}'));

        Test.startTest();
        Map<String, Object> result = MetaLicenseService.validateLicense('NEW-KEY');
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        Map<String, Object> settings = (Map<String, Object>) result.get('settings');
        System.assertEquals('Active', settings.get('Status__c'));
        System.assertEquals(10, settings.get('Max_Pages_Allowed__c'));
    }

    @isTest
    static void testValidateLicense_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, '{"error":"Invalid key"}'));

        Test.startTest();
        Map<String, Object> result = MetaLicenseService.validateLicense('BAD-KEY');
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assertEquals('Server returned 400', result.get('message'));
    }

    @isTest
    static void testIsLicenseActive_And_GetMaxPages() {
        System.assertEquals(false, MetaLicenseService.isLicenseActive());
        System.assertEquals(0, MetaLicenseService.getMaxPages());

        Meta_License_Settings__c settings = new Meta_License_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Status__c = 'Trial',
            Max_Pages_Allowed__c = 1,
            Expiration_Date__c = Date.today().addDays(14)
        );
        insert settings;

        System.assertEquals(true, MetaLicenseService.isLicenseActive());
        System.assertEquals(1, MetaLicenseService.getMaxPages());

        settings.Expiration_Date__c = Date.today().addDays(-1);
        update settings;

        System.assertEquals(false, MetaLicenseService.isLicenseActive());
    }
}

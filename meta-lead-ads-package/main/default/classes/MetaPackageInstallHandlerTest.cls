@isTest
private class MetaPackageInstallHandlerTest {
    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Trial", "expiry":"2030-01-01", "maxPages":1, "licenseKey":"TRIAL-123"}');
            return res;
        }
    }

    @isTest
    static void testInstallScript() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        MetaPackageInstallHandler handler = new MetaPackageInstallHandler();
        
        Test.startTest();
        Test.testInstall(handler, null);
        Test.stopTest();

        // Verify that the TrialRegistrationJob ran and inserted the settings
        Meta_License_Settings__c settings = Meta_License_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.Id);
        System.assertEquals('Trial', settings.Status__c);
    }
}

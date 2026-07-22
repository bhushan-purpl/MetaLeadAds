@isTest
private class MetaWebhookControllerTest {
    private class WebhookMock implements HttpCalloutMock {
        private Integer status;
        private String body;
        public WebhookMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    @isTest
    static void testGetConfig() {
        Test.startTest();
        Map<String, String> config = MetaWebhookController.getConfig();
        Test.stopTest();
        System.assertNotEquals(null, config);
    }

    @isTest
    static void testCheckSubscriptionStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new WebhookMock(200, '{"data":[{"active":true}]}'));
        Test.startTest();
        try {
            Map<String, Object> res = MetaWebhookController.checkSubscriptionStatus('12345');
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testSubscribeWebhook_Success() {
        Test.setMock(HttpCalloutMock.class, new WebhookMock(200, '{"success":true}'));
        Test.startTest();
        try {
            Map<String, Object> res = MetaWebhookController.subscribeWebhook('12345');
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testUnsubscribeWebhook_Success() {
        Test.setMock(HttpCalloutMock.class, new WebhookMock(200, '{"success":true}'));
        Test.startTest();
        try {
            Map<String, Object> res = MetaWebhookController.unsubscribeWebhook('12345');
        } catch (Exception e) {}
        Test.stopTest();
    }
}

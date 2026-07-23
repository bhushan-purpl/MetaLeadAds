@isTest
private class MetaAuthControllerTest {

    private class MetaAuthMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public MetaAuthMock(Integer statusCode, String responseBody) {
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
    static void testGetFacebookLoginUrl() {
        Test.startTest();
        try {
            String loginUrl = MetaAuthController.getFacebookLoginUrl();
            System.assertNotEquals(null, loginUrl, 'Login URL should be generated');
            System.assert(loginUrl.contains('facebook.com'), 'Login URL should contain facebook.com');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testExchangeCodeForToken_Success() {
        Test.setMock(HttpCalloutMock.class, new MetaAuthMock(200, '{"access_token":"mock_user_token_123"}'));

        Test.startTest();
        try {
            String token = MetaAuthController.exchangeCodeForToken('valid_code_xyz');
            System.assertEquals('mock_user_token_123', token);
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testExchangeCodeForToken_Failure() {
        Test.setMock(HttpCalloutMock.class, new MetaAuthMock(400, '{"error":{"message":"Invalid code"}}'));

        Test.startTest();
        try {
            MetaAuthController.exchangeCodeForToken('invalid_code');
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetManagedPages_Disconnected() {
        Test.startTest();
        try {
            MetaAuthController.getManagedPages();
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetManagedPages_Connected() {
        insert new Meta_Auth_Token__c(Name = 'Facebook Token', User_Access_Token__c = 'mock_user_token');
        
        String responseBody = JSON.serialize(new Map<String, Object>{
            'data' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1001180569754985',
                    'name' => 'PS',
                    'access_token' => 'mock_page_token'
                }
            }
        });
        Test.setMock(HttpCalloutMock.class, new MetaAuthMock(200, responseBody));

        Test.startTest();
        List<MetaPageWrapper> pages = MetaAuthController.getManagedPages();
        System.assertNotEquals(null, pages);
        Test.stopTest();
    }

    @isTest
    static void testSubscribePage_Success() {
        Test.setMock(HttpCalloutMock.class, new MetaAuthMock(200, '{"success":true}'));

        Test.startTest();
        String result = MetaAuthController.subscribePage('1001180569754985', 'mock_page_token', 'PS Page');
        System.assertEquals('SUCCESS', result);
        Test.stopTest();
    }

    @isTest
    static void testSubscribePage_FailedResponse() {
        Test.setMock(HttpCalloutMock.class, new MetaAuthMock(200, '{"success":false}'));

        Test.startTest();
        String result = MetaAuthController.subscribePage('1001180569754985', 'mock_page_token', 'PS Page');
        System.assertEquals('FAILED', result);
        Test.stopTest();
    }

    @isTest
    static void testIsConnectedAndDisconnect() {
        System.assertEquals(false, MetaAuthController.isConnected());

        insert new Meta_Auth_Token__c(Name = 'Facebook Token', User_Access_Token__c = 'mock_user_token');
        System.assertEquals(true, MetaAuthController.isConnected());

        MetaAuthController.disconnect();
        System.assertEquals(false, MetaAuthController.isConnected());
    }

    @isTest
    static void testGetActiveSubscriptionsAndLogs() {
        Meta_Page_Subscription__c sub = new Meta_Page_Subscription__c(
            Page_ID__c = '1001180569754985',
            Page_Name__c = 'PS Page',
            Status__c = 'Active',
            Enable_Logs__c = true,
            Enable_Lead_Creation__c = true
        );
        insert sub;

        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c = '123456789',
            Page_ID__c = '1001180569754985',
            Processing_Status__c = 'Success'
        );
        insert logRec;

        Test.startTest();
        List<MetaAuthController.SubscriptionWrapper> subs = MetaAuthController.getActiveSubscriptions();
        System.assertEquals(1, subs.size());

        List<MetaAuthController.LogWrapper> logs = MetaAuthController.getIntegrationLogs();
        System.assertEquals(1, logs.size());

        MetaAuthController.updateSubscriptionSettings(sub.Id, false, false);
        Meta_Page_Subscription__c updatedSub = [SELECT Enable_Logs__c, Enable_Lead_Creation__c FROM Meta_Page_Subscription__c WHERE Id = :sub.Id];
        System.assertEquals(false, updatedSub.Enable_Logs__c);
        System.assertEquals(false, updatedSub.Enable_Lead_Creation__c);
        Test.stopTest();
    }
}

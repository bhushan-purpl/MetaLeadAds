@isTest
private class MetaLeadWebhookTest {

    // ═══════════════════════════════════════════
    // GET Verification Tests
    // ═══════════════════════════════════════════

    @isTest
    static void testVerify_ValidToken() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'Purplstack2026');
        req.params.put('hub.challenge', 'test_challenge_string');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.verify();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 for valid token');
        System.assertEquals('test_challenge_string', res.responseBody.toString(),
            'Should echo back the challenge string');
    }

    @isTest
    static void testVerify_InvalidToken() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'WrongToken');
        req.params.put('hub.challenge', 'test_challenge_string');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.verify();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Should return 403 for invalid token');
    }

    // ═══════════════════════════════════════════
    // POST Lead Reception Tests
    // ═══════════════════════════════════════════

    @isTest
    static void testReceiveLead_ValidPayload() {
        String payload = JSON.serialize(new Map<String, Object>{
            'object' => 'page',
            'entry' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1001180569754985',
                    'time' => 1234567890,
                    'changes' => new List<Object>{
                        new Map<String, Object>{
                            'field' => 'leadgen',
                            'value' => new Map<String, Object>{
                                'leadgen_id' => '2317987479029977',
                                'page_id'    => '1001180569754985',
                                'form_id'    => '915088084913625'
                            }
                        }
                    }
                }
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'POST';
        req.headers.put('User-Agent', 'facebookexternalua');
        req.requestBody = Blob.valueOf(payload);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.receiveLead();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should always return 200');
    }

    @isTest
    static void testReceiveLead_NoEntries() {
        String payload = JSON.serialize(new Map<String, Object>{
            'object' => 'page',
            'entry' => new List<Object>()
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'POST';
        req.headers.put('User-Agent', 'facebookexternalua');
        req.requestBody = Blob.valueOf(payload);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.receiveLead();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testReceiveLead_MalformedPayload() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'POST';
        req.headers.put('User-Agent', 'facebookexternalua');
        req.requestBody = Blob.valueOf('this is not json');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.receiveLead();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should still return 200 even on parse error');
    }

    @isTest
    static void testReceiveLead_NonLeadgenField() {
        String payload = JSON.serialize(new Map<String, Object>{
            'object' => 'page',
            'entry' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1001180569754985',
                    'time' => 1234567890,
                    'changes' => new List<Object>{
                        new Map<String, Object>{
                            'field' => 'feed',
                            'value' => new Map<String, Object>{
                                'item' => 'post'
                            }
                        }
                    }
                }
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'POST';
        req.headers.put('User-Agent', 'facebookexternalua');
        req.requestBody = Blob.valueOf(payload);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.receiveLead();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    // ═══════════════════════════════════════════
    // Platform Event Trigger Test
    // ═══════════════════════════════════════════

    @isTest
    static void testPlatformEventTrigger() {
        Meta_Lead_Event__e evt = new Meta_Lead_Event__e(
            Meta_Lead_Event__c = '{"test":"payload"}',
            Leadgen_ID__c   = '2317987479029977',
            Page_ID__c      = '1001180569754985',
            Form_ID__c      = '915088084913625'
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), 'Event should publish successfully');

        // Verify log was created by the trigger
        List<Meta_Lead_Log__c> logs = [
            SELECT Meta_Lead_ID__c, Page_ID__c, Form_ID__c, Processing_Status__c
            FROM Meta_Lead_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should create one log record');
        System.assertEquals('2317987479029977', logs[0].Meta_Lead_ID__c);
        System.assertEquals('Received', logs[0].Processing_Status__c);
    }

    // ═══════════════════════════════════════════
    // Callout Job Tests (with HTTP Mock)
    // ═══════════════════════════════════════════

    @isTest
    static void testCalloutJob_Success() {
        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '2317987479029977',
            Page_ID__c           = '1001180569754985',
            Form_ID__c           = '915088084913625',
            Processing_Status__c = 'Received',
            Lead_Payload__c      = '{"test":"payload"}'
        );
        insert logRec;

        Test.setMock(HttpCalloutMock.class, new MetaGraphAPIMock(true));

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{logRec.Id}));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog = [
            SELECT Processing_Status__c, Salesforce_Lead_ID__c, Error_Message__c
            FROM Meta_Lead_Log__c
            WHERE Id = :logRec.Id
        ];

        System.assertNotEquals(null, updatedLog.Processing_Status__c,
            'Processing status should be updated');
    }

    @isTest
    static void testReceiveLead_HMACMissingSignatureHeader() {
        // Test when getAppSecret() returns a value (or mock request with secret)
        String payload = '{"object":"page","entry":[]}';
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/metaLead';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MetaLeadWebhook.receiveLead();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testCalloutJob_FallbackFieldData() {
        Meta_Page_Subscription__c sub = new Meta_Page_Subscription__c(
            Page_ID__c = '1001180569754985',
            Page_Name__c = 'PS Page',
            Page_Access_Token__c = 'mock_page_token',
            Status__c = 'Active',
            Enable_Lead_Creation__c = true
        );
        insert sub;

        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '9876543210123',
            Page_ID__c           = '1001180569754985',
            Form_ID__c           = '915088084913625',
            Processing_Status__c = 'Received',
            Lead_Payload__c      = '{"test":"payload"}'
        );
        insert logRec;

        // Custom HttpMock returning fallback fields (first_name, last_name, work_email, work_phone_number, company, city, state, zip_code, country)
        Test.setMock(HttpCalloutMock.class, new MetaGraphAPIFallbackMock());

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{logRec.Id}));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog = [SELECT Processing_Status__c, Salesforce_Lead_ID__c FROM Meta_Lead_Log__c WHERE Id = :logRec.Id];
        System.assertEquals('Success', updatedLog.Processing_Status__c);
    }

    @isTest
    static void testCalloutJob_DynamicMappingAndAssignment() {
        Meta_Page_Subscription__c sub = new Meta_Page_Subscription__c(
            Page_ID__c = '1001180569754985',
            Page_Name__c = 'PS Page',
            Page_Access_Token__c = 'mock_page_token',
            Status__c = 'Active',
            Enable_Lead_Creation__c = true
        );
        insert sub;

        Meta_Field_Mapping__c map1 = new Meta_Field_Mapping__c(
            Form_ID__c = '915088084913625',
            Facebook_Field__c = 'full_name',
            Salesforce_Field__c = 'Name',
            Active__c = true
        );
        Meta_Field_Mapping__c map2 = new Meta_Field_Mapping__c(
            Form_ID__c = '915088084913625',
            Facebook_Field__c = 'static::Test Company',
            Salesforce_Field__c = 'Company',
            Active__c = true
        );
        insert new List<Meta_Field_Mapping__c>{ map1, map2 };

        Meta_Lead_Assignment__c assign = new Meta_Lead_Assignment__c(
            Form_ID__c = '915088084913625',
            Owner_Type__c = 'User',
            Owner_ID__c = UserInfo.getUserId(),
            Active__c = true
        );
        insert assign;

        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '2317987479029977',
            Page_ID__c           = '1001180569754985',
            Form_ID__c           = '915088084913625',
            Processing_Status__c = 'Received',
            Lead_Payload__c      = '{"test":"payload"}'
        );
        insert logRec;

        Test.setMock(HttpCalloutMock.class, new MetaGraphAPIMock(true));

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{logRec.Id}));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog = [
            SELECT Processing_Status__c, Salesforce_Lead_ID__c
            FROM Meta_Lead_Log__c
            WHERE Id = :logRec.Id
        ];
        System.assertEquals('Success', updatedLog.Processing_Status__c);
        System.assertNotEquals(null, updatedLog.Salesforce_Lead_ID__c);
    }

    @isTest
    static void testCalloutJob_IdempotencyAndNoAccessToken() {
        Meta_Lead_Log__c logRec1 = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '111111111111',
            Page_ID__c           = '1001180569754985',
            Salesforce_Lead_ID__c = '00Q000000000001AAA',
            Processing_Status__c = 'Success'
        );
        Meta_Lead_Log__c logRec2 = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '222222222222',
            Page_ID__c           = 'UNKNOWN_PAGE_ID',
            Processing_Status__c = 'Received'
        );
        insert new List<Meta_Lead_Log__c>{ logRec1, logRec2 };

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{ logRec1.Id, logRec2.Id }));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog2 = [SELECT Processing_Status__c, Error_Message__c FROM Meta_Lead_Log__c WHERE Id = :logRec2.Id];
        System.assertEquals('Failed', updatedLog2.Processing_Status__c);
    }

    @isTest
    static void testCalloutJob_DisabledLeadCreation() {
        Meta_Page_Subscription__c sub = new Meta_Page_Subscription__c(
            Page_ID__c = '1001180569754985',
            Page_Name__c = 'PS Page',
            Page_Access_Token__c = 'mock_page_token',
            Status__c = 'Active',
            Enable_Lead_Creation__c = false
        );
        insert sub;

        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '2317987479029977',
            Page_ID__c           = '1001180569754985',
            Form_ID__c           = '915088084913625',
            Processing_Status__c = 'Received',
            Lead_Payload__c      = '{"test":"payload"}'
        );
        insert logRec;

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{logRec.Id}));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog = [
            SELECT Processing_Status__c, Error_Message__c
            FROM Meta_Lead_Log__c
            WHERE Id = :logRec.Id
        ];

        System.assertEquals('Success - Lead Creation Disabled', updatedLog.Processing_Status__c);
    }

    @isTest
    static void testPlatformEvent_OAuthTokenSave() {
        Meta_Lead_Event__e evt = new Meta_Lead_Event__e(
            Leadgen_ID__c = 'OAUTH_TOKEN_SAVE',
            Meta_Lead_Event__c = 'mock_token_abc'
        );

        Test.startTest();
        EventBus.publish(evt);
        Test.stopTest();

        List<Meta_Auth_Token__c> tokens = [SELECT User_Access_Token__c FROM Meta_Auth_Token__c];
        System.assertEquals(1, tokens.size());
        System.assertEquals('mock_token_abc', tokens[0].User_Access_Token__c);
    }

    @isTest
    static void testCalloutJob_APIError() {
        Meta_Lead_Log__c logRec = new Meta_Lead_Log__c(
            Meta_Lead_ID__c      = '9999999999999',
            Page_ID__c           = '1001180569754985',
            Form_ID__c           = '915088084913625',
            Processing_Status__c = 'Received',
            Lead_Payload__c      = '{"test":"payload"}'
        );
        insert logRec;

        Test.setMock(HttpCalloutMock.class, new MetaGraphAPIMock(false));

        Test.startTest();
        System.enqueueJob(new MetaLeadCalloutJob(new List<Id>{logRec.Id}));
        Test.stopTest();

        Meta_Lead_Log__c updatedLog = [
            SELECT Processing_Status__c, Error_Message__c
            FROM Meta_Lead_Log__c
            WHERE Id = :logRec.Id
        ];

        System.assertEquals('Failed', updatedLog.Processing_Status__c);
        System.assertNotEquals(null, updatedLog.Error_Message__c);
    }

    // ═══════════════════════════════════════════
    // HTTP Mock
    // ═══════════════════════════════════════════

    private class MetaGraphAPIMock implements HttpCalloutMock {

        private Boolean isSuccess;

        public MetaGraphAPIMock(Boolean isSuccess) {
            this.isSuccess = isSuccess;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            if (isSuccess) {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'id' => '2317987479029977',
                    'created_time' => '2026-06-20T10:00:00+0000',
                    'field_data' => new List<Object>{
                        new Map<String, Object>{
                            'name' => 'full_name',
                            'values' => new List<String>{ 'Bhushan Chavan' }
                        },
                        new Map<String, Object>{
                            'name' => 'email',
                            'values' => new List<String>{ 'bhushan@test.com' }
                        },
                        new Map<String, Object>{
                            'name' => 'phone_number',
                            'values' => new List<String>{ '9876543210' }
                        },
                        new Map<String, Object>{
                            'name' => 'company_name',
                            'values' => new List<String>{ 'Test Company Pvt Ltd' }
                        }
                    }
                }));
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":{"message":"Invalid lead ID","type":"OAuthException","code":100}}');
            }

            return res;
        }
    }

    private class MetaGraphAPIFallbackMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'id' => '9876543210123',
                'created_time' => '2026-06-20T10:00:00+0000',
                'campaign_name' => 'Test Campaign',
                'ad_name' => 'Test Ad',
                'field_data' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'first_name',
                        'values' => new List<String>{ 'John' }
                    },
                    new Map<String, Object>{
                        'name' => 'last_name',
                        'values' => new List<String>{ 'Doe' }
                    },
                    new Map<String, Object>{
                        'name' => 'work_email',
                        'values' => new List<String>{ 'johndoe@test.com' }
                    },
                    new Map<String, Object>{
                        'name' => 'work_phone_number',
                        'values' => new List<String>{ '1234567890' }
                    },
                    new Map<String, Object>{
                        'name' => 'organization',
                        'values' => new List<String>{ 'Acme Inc' }
                    },
                    new Map<String, Object>{
                        'name' => 'city',
                        'values' => new List<String>{ 'San Francisco' }
                    },
                    new Map<String, Object>{
                        'name' => 'state',
                        'values' => new List<String>{ 'CA' }
                    },
                    new Map<String, Object>{
                        'name' => 'zip_code',
                        'values' => new List<String>{ '94105' }
                    },
                    new Map<String, Object>{
                        'name' => 'country',
                        'values' => new List<String>{ 'US' }
                    }
                }
            }));
            return res;
        }
    }
}

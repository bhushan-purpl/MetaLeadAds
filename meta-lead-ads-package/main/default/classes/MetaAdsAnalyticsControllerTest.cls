@isTest
private class MetaAdsAnalyticsControllerTest {

    private class MarketingApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/adaccounts')) {
                res.setBody('{"data":[{"id":"act_123456789","name":"Test Ad Account","account_id":"123456789","currency":"USD"}]}');
            } else if (req.getEndpoint().contains('/insights')) {
                res.setBody('{"data":[{"campaign_id":"camp_111","campaign_name":"Test Campaign 1","spend":"500.00","clicks":"120","impressions":"5000","reach":"4000","ctr":"2.4","cpc":"4.16","cpm":"100.00","actions":[{"action_type":"lead","value":"15"}]}]}');
            } else if (req.getEndpoint().contains('/campaigns')) {
                res.setBody('{"data":[{"id":"camp_111","name":"Test Campaign 1","daily_budget":"10000"}]}');
            } else {
                res.setBody('{"data":[]}');
            }
            return res;
        }
    }

    @testSetup
    static void setupData() {
        insert new Meta_Auth_Token__c(Name = 'Facebook Token', User_Access_Token__c = 'mock_user_token_123');

        Meta_Campaign_Analytics__c mca = new Meta_Campaign_Analytics__c(
            Campaign_Id__c = 'camp_111',
            Campaign_Name__c = 'Test Campaign 1',
            Ad_Account_Id__c = 'act_123456789',
            Spend__c = 500.00,
            Clicks__c = 120,
            Impressions__c = 5000,
            Reach__c = 4000,
            Leads__c = 15,
            Analytics_Date__c = Date.today()
        );
        insert mca;

        Meta_Daily_Analytics__c mda = new Meta_Daily_Analytics__c(
            Analytics_Date__c = Date.today(),
            Campaign_Id__c = 'camp_111',
            Spend__c = 500.00,
            Clicks__c = 120,
            Impressions__c = 5000,
            Leads__c = 15
        );
        insert mda;
    }

    @isTest
    static void testGetAdAccountsAndConnection() {
        Test.setMock(HttpCalloutMock.class, new MarketingApiMock());
        
        Test.startTest();
        List<Map<String, String>> accs = MetaAdsAnalyticsController.getAdAccounts();
        Map<String, Object> connRes = MetaAdsAnalyticsController.testMarketingApiConnection();
        Test.stopTest();

        System.assertEquals(1, accs.size());
        System.assertEquals('act_123456789', accs[0].get('id'));
        System.assertEquals(true, connRes.get('success'));
    }

    @isTest
    static void testSyncCampaignsNow() {
        Test.setMock(HttpCalloutMock.class, new MarketingApiMock());

        Test.startTest();
        Map<String, Object> syncCampRes = MetaAdsAnalyticsController.syncNow('act_123456789', 'campaigns');
        Test.stopTest();

        System.assertEquals(true, syncCampRes.get('success'), (String) syncCampRes.get('message'));
    }

    @isTest
    static void testSyncInsightsNow() {
        Test.setMock(HttpCalloutMock.class, new MarketingApiMock());

        Test.startTest();
        Map<String, Object> syncInsRes = MetaAdsAnalyticsController.syncNow('act_123456789', 'insights');
        Test.stopTest();

        System.assertEquals(true, syncInsRes.get('success'), (String) syncInsRes.get('message'));
    }

    @isTest
    static void testGetDashboardAnalytics() {
        Test.startTest();
        MetaAdsAnalyticsController.DashboardMetricsWrapper metrics = MetaAdsAnalyticsController.getDashboardAnalytics('{}');
        Test.stopTest();

        System.assertNotEquals(null, metrics);
        System.assertEquals(500.00, metrics.totalSpend);
        System.assertEquals(120, metrics.totalClicks);
        System.assertEquals(15, metrics.totalLeads);
    }

    @isTest
    static void testAnalyticsScheduler() {
        Test.setMock(HttpCalloutMock.class, new MarketingApiMock());

        Test.startTest();
        AnalyticsScheduler scheduler = new AnalyticsScheduler('act_123456789');
        String cronExp = '0 0 0 * * ?';
        System.schedule('TestAnalyticsSchedulerJob', cronExp, scheduler);
        Test.stopTest();

        System.assert(true);
    }
}

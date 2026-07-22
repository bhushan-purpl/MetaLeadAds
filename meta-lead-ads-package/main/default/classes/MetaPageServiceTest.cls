@isTest
private class MetaPageServiceTest {
    private class PageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"111","name":"Page1","access_token":"token1"}]}');
            return res;
        }
    }

    @isTest
    static void testSyncPages() {
        insert new Meta_Auth_Token__c(Name = 'Facebook Token', User_Access_Token__c = 'mock_user_token');
        Test.setMock(HttpCalloutMock.class, new PageMock());
        
        Test.startTest();
        List<Meta_Page__c> pages = MetaPageService.syncPages();
        Test.stopTest();
        
        System.assert(pages.size() > 0);
    }

    @isTest
    static void testGetPages() {
        insert new Meta_Page__c(Page_ID__c = '111', Page_Name__c = 'Page1', Active__c = true);
        
        Test.startTest();
        List<Meta_Page__c> pages = MetaPageService.getPages();
        Test.stopTest();
        
        System.assertEquals(1, pages.size());
    }
}

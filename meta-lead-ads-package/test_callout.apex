HttpRequest req = new HttpRequest();
req.setEndpoint('https://power-momentum-7033-dev-ed.scratch.my.salesforce-sites.com/meta/services/apexrest/purpl/metaLead?hub.mode=subscribe&hub.challenge=1158201444&hub.verify_token=meta_lead_verify_token');
req.setMethod('GET');
Http http = new Http();
try {
    HttpResponse res = http.send(req);
    System.debug('HTTP_STATUS: ' + res.getStatusCode());
    System.debug('HTTP_BODY: ' + res.getBody());
} catch(Exception e) {
    System.debug('HTTP_ERROR: ' + e.getMessage());
}

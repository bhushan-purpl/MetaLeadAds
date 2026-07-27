List<Site> sites = [SELECT Id, Name, Subdomain, UrlPathPrefix FROM Site];
for (Site s : sites) {
    SiteDetail sd = [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :s.Id];
    System.debug('SITE_SECURE_URL: ' + sd.SecureUrl);
}

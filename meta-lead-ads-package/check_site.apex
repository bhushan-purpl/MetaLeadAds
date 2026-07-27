List<Site> sites = [SELECT Name, Subdomain, UrlPathPrefix, GuestUserId FROM Site];
for (Site s : sites) {
    System.debug('SITE_INFO: Name=' + s.Name + ', Subdomain=' + s.Subdomain + ', PathPrefix=' + s.UrlPathPrefix);
}

Organization org = [SELECT NamespacePrefix FROM Organization];
System.debug('ORG_NAMESPACE: ' + org.NamespacePrefix);

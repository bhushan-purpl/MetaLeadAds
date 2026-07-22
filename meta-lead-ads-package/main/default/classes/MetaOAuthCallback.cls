/**
 * MetaOAuthCallback.cls
 * Handles the OAuth redirect from Facebook after user login.
 * Facebook redirects the user here with ?code=xxx
 * This exchanges the code for an access token and closes the popup.
 *
 * URL: https://your-site.force.com/services/apexrest/metaAuthCallback
 */
@RestResource(urlMapping='/metaAuthCallback/*')
global without sharing class MetaOAuthCallback {

    @HttpGet
    global static void handleCallback() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        String code  = req.params.get('code');
        String error = req.params.get('error');

        res.addHeader('Content-Type', 'text/html');

        if (String.isNotBlank(error)) {
            res.statusCode  = 200;
            res.responseBody = Blob.valueOf(buildHtml('error', 'Facebook login was cancelled.'));
            return;
        }

        if (String.isBlank(code)) {
            res.statusCode  = 400;
            res.responseBody = Blob.valueOf(buildHtml('error', 'No authorization code received.'));
            return;
        }

        try {
            MetaAuthController.exchangeCodeForToken(code);

            res.statusCode  = 200;
            res.responseBody = Blob.valueOf(buildHtml('success', 'Connected successfully! You can close this window.'));

        } catch (Exception e) {
            res.statusCode  = 500;
            res.responseBody = Blob.valueOf(buildHtml('error', 'Error: ' + e.getMessage()));
        }
    }

    private static String buildHtml(String status, String message) {
        return '<!DOCTYPE html>'
            + '<html>'
            + '<head><title>Facebook Login</title></head>'
            + '<body style="font-family:sans-serif;text-align:center;padding:40px;">'
            + '<h2>' + (status == 'success' ? '✅' : '❌') + ' ' + message + '</h2>'
            + '<script>'
            + '  if (window.opener) {'
            + '    window.opener.postMessage({ type: "META_AUTH_CALLBACK", status: "' + status + '" }, "*");'
            + '    setTimeout(function() { window.close(); }, 1500);'
            + '  }'
            + '</script>'
            + '</body>'
            + '</html>';
    }
}
Map<String, String> config = MetaWebhookController.getConfig();
System.debug('CONFIG_WEBHOOK_URL: ' + config.get('webhookUrl'));
System.debug('CONFIG_REDIRECT_URL: ' + config.get('redirectUrl'));

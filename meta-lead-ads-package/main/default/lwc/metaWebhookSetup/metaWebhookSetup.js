import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfig from '@salesforce/apex/MetaWebhookController.getConfig';
import checkSubscriptionStatus from '@salesforce/apex/MetaWebhookController.checkSubscriptionStatus';
import subscribeWebhook from '@salesforce/apex/MetaWebhookController.subscribeWebhook';
import unsubscribeWebhook from '@salesforce/apex/MetaWebhookController.unsubscribeWebhook';

export default class MetaWebhookSetup extends LightningElement {

    // Config
    @track webhookUrl    = 'Loading...';
    @track redirectUrl   = 'Loading...';
    @track domainUrl     = 'Loading...';
    @track verifyToken   = 'Loading...';
    @track pageId        = '';
    @track hasToken      = false;
    @track tokenPreview  = '';

    // UI State
    @track isLoading      = false;
    @track isSubscribing  = false;
    @track isUnsubscribing = false;
    @track isSubscribed   = false;
    @track statusChecked  = false;
    @track copiedUrl      = false;
    @track copiedRedirect = false;
    @track copiedDomain   = false;
    @track copiedToken    = false;

    // ── Lifecycle ──
    connectedCallback() {
        this.loadConfig();
    }

    async loadConfig() {
        try {
            const config = await getConfig();
            this.webhookUrl   = config.webhookUrl   || 'Could not auto-detect. Check your Salesforce Site settings.';
            this.redirectUrl  = config.redirectUrl  || '';
            this.domainUrl    = config.domainUrl    || '';
            this.verifyToken  = config.verifyToken  || 'Purplstack2026';
            this.pageId       = config.pageId       || '';
            this.hasToken     = config.hasToken === 'true';
            this.tokenPreview = config.tokenPreview || 'Not Configured';

            // Auto-check status if we already have a page ID
            if (this.pageId) {
                await this.checkStatus();
            }
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        }
    }

    // ── Handlers ──
    handlePageIdChange(event) {
        this.pageId = event.target.value;
        // Reset status when page ID changes
        this.statusChecked = false;
        this.isSubscribed  = false;
    }

    async checkStatus() {
        if (!this.validatePageId()) return;
        this.isLoading = true;
        try {
            const result = await checkSubscriptionStatus({ pageId: this.pageId });
            this.isSubscribed  = this.isLeadgenSubscribed(result);
            this.statusChecked = true;
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async subscribe() {
        if (!this.validatePageId()) return;
        this.isLoading     = true;
        this.isSubscribing = true;
        try {
            const result = await subscribeWebhook({ pageId: this.pageId });
            if (result.success === true) {
                this.isSubscribed  = true;
                this.statusChecked = true;
                this.toast('Success', '🎉 Webhook subscribed! Facebook leads will now flow into Salesforce automatically.', 'success');
            } else {
                this.toast('Error', 'Unexpected response from Facebook: ' + JSON.stringify(result), 'error');
            }
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading     = false;
            this.isSubscribing = false;
        }
    }

    async unsubscribe() {
        if (!this.validatePageId()) return;
        this.isLoading       = true;
        this.isUnsubscribing = true;
        try {
            const result = await unsubscribeWebhook({ pageId: this.pageId });
            if (result.success === true) {
                this.isSubscribed  = false;
                this.statusChecked = true;
                this.toast('Info', 'Webhook unsubscribed. Leads will no longer be captured from this page.', 'info');
            } else {
                this.toast('Error', 'Unexpected response: ' + JSON.stringify(result), 'error');
            }
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading       = false;
            this.isUnsubscribing = false;
        }
    }

    copyWebhookUrl() {
        this.copyToClipboard(this.webhookUrl);
        this.copiedUrl = true;
        setTimeout(() => { this.copiedUrl = false; }, 2000);
    }

    copyRedirectUrl() {
        this.copyToClipboard(this.redirectUrl);
        this.copiedRedirect = true;
        setTimeout(() => { this.copiedRedirect = false; }, 2000);
    }

    copyDomainUrl() {
        this.copyToClipboard(this.domainUrl);
        this.copiedDomain = true;
        setTimeout(() => { this.copiedDomain = false; }, 2000);
    }

    copyVerifyToken() {
        this.copyToClipboard(this.verifyToken);
        this.copiedToken = true;
        setTimeout(() => { this.copiedToken = false; }, 2000);
    }

    // ── Helpers ──
    validatePageId() {
        if (!this.pageId || this.pageId.trim() === '') {
            this.toast('Warning', 'Please enter your Facebook Page ID first.', 'warning');
            return false;
        }
        return true;
    }

    isLeadgenSubscribed(result) {
        const data = result.data || [];
        return data.some(app => {
            const fields = app.subscribed_fields || [];
            return fields.includes('leadgen');
        });
    }

    copyToClipboard(text) {
        try {
            const el = document.createElement('textarea');
            el.value = text;
            el.style.position = 'fixed';
            el.style.opacity  = '0';
            document.body.appendChild(el);
            el.focus();
            el.select();
            document.execCommand('copy');
            document.body.removeChild(el);
        } catch (e) {
            console.error('Copy failed', e);
        }
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ── Computed Properties ──
    get tokenBadgeClass() {
        return this.hasToken ? 'token-badge token-badge--ok' : 'token-badge token-badge--error';
    }

    get tokenBadgeText() {
        return this.hasToken ? '🔑 Token Configured' : '⚠️ Token Missing';
    }

    get statusBannerClass() {
        return this.isSubscribed
            ? 'status-banner status-banner--success'
            : 'status-banner status-banner--warning';
    }
}
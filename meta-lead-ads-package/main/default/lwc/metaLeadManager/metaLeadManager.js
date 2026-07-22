import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFacebookLoginUrl    from '@salesforce/apex/MetaAuthController.getFacebookLoginUrl';
import isConnected            from '@salesforce/apex/MetaAuthController.isConnected';
import getManagedPages        from '@salesforce/apex/MetaAuthController.getManagedPages';
import subscribePage          from '@salesforce/apex/MetaAuthController.subscribePage';
import getActiveSubscriptions from '@salesforce/apex/MetaAuthController.getActiveSubscriptions';
import disconnect             from '@salesforce/apex/MetaAuthController.disconnect';
import getIntegrationLogs     from '@salesforce/apex/MetaAuthController.getIntegrationLogs';
import updateSubscriptionSettings from '@salesforce/apex/MetaAuthController.updateSubscriptionSettings';

export default class MetaLeadManager extends LightningElement {

    // Card Title (configurable from App Builder)
    @api cardTitle = 'Meta Lead Ads Manager';

    // ─── State tracking ──────────────────────────────────────────────
    @track isConnected     = false;
    @track isDisconnected  = true;
    @track isLoadingPages  = false;
    @track isSubscribing   = false;

    // ─── Data ─────────────────────────────────────────────────────────
    @track pageOptions          = [];
    @track selectedPageId       = '';
    @track selectedPageToken    = '';
    @track selectedPageName     = '';
    @track activeSubscriptions  = [];
    @track integrationLogs      = [];
    @track errorMessage         = '';

    // ─── Column definitions ───────────────────────────────────────────
    logColumns = [
        { label: 'Leadgen ID',   fieldName: 'Meta_Lead_ID__c',  type: 'text' },
        { label: 'Page ID',      fieldName: 'Page_ID__c',       type: 'text' },
        { label: 'Status',       fieldName: 'Processing_Status__c', type: 'text',
          cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Error Message',fieldName: 'Error_Message__c', type: 'text' },
        { label: 'Created',      fieldName: 'CreatedDate',      type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } }
    ];

    // ─── Lifecycle: Load on connect ───────────────────────────────────
    connectedCallback() {
        this.checkConnectionStatus();

        // Listen for the postMessage from the OAuth popup callback
        window.addEventListener('message', this.handleOAuthMessage.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleOAuthMessage.bind(this));
    }

    // ─── Step 1: Check if already connected on load ───────────────────
    async checkConnectionStatus() {
        try {
            const connected = await isConnected();
            this.setConnectedState(connected);
            if (connected) {
                this.loadPages();
                this.loadSubscriptions();
                this.loadLogs();
            }
        } catch (e) {
            this.errorMessage = 'Could not check connection status.';
        }
    }

    // ─── Step 2: Open Facebook Login Popup ───────────────────────────
    async handleConnectFacebook() {
        try {
            const loginUrl = await getFacebookLoginUrl();
            const popup = window.open(
                loginUrl,
                'FacebookLogin',
                'width=600,height=700,top=100,left=300'
            );
            if (!popup) {
                this.errorMessage = 'Popup was blocked! Please allow popups for this site.';
            }
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : e.message;
        }
    }

    // ─── Step 3: Handle the callback message from the popup ──────────
    handleOAuthMessage(event) {
        if (event.data && event.data.type === 'META_AUTH_CALLBACK') {
            if (event.data.status === 'success') {
                this.setConnectedState(true);
                this.showToast('Success', 'Facebook connected successfully!', 'success');
                this.loadPages();
                this.loadSubscriptions();
                this.loadLogs();
            } else {
                this.errorMessage = 'Facebook login was cancelled or failed.';
            }
        }
    }

    // ─── Step 4: Load Facebook Pages into dropdown ───────────────────
    async loadPages() {
        this.isLoadingPages = true;
        try {
            const pages = await getManagedPages();
            this.pageOptions = pages.map(p => ({
                label: p.pageName,
                value: p.pageId,
                token: p.accessToken
            }));
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load Facebook pages.';
        } finally {
            this.isLoadingPages = false;
        }
    }

    // ─── Step 5: Handle page selection ───────────────────────────────
    handlePageChange(event) {
        this.selectedPageId = event.detail.value;
        const selected = this.pageOptions.find(p => p.value === this.selectedPageId);
        if (selected) {
            this.selectedPageToken = selected.token;
            this.selectedPageName  = selected.label;
        }
    }

    // ─── Step 6: Subscribe the selected page ─────────────────────────
    async handleSubscribe() {
        if (!this.selectedPageId) return;
        this.isSubscribing = true;

        try {
            const result = await subscribePage({
                pageId:          this.selectedPageId,
                pageAccessToken: this.selectedPageToken,
                pageName:        this.selectedPageName
            });

            if (result === 'SUCCESS') {
                this.showToast('Subscribed!', `${this.selectedPageName} is now subscribed to Lead Ads.`, 'success');
                this.loadSubscriptions();
            } else {
                this.errorMessage = 'Subscription failed. Please try again.';
            }
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Subscription failed.';
        } finally {
            this.isSubscribing = false;
        }
    }

    // ─── Handle Toggle Changes for Logs and Leads ─────────────────────
    async handleToggleChange(event) {
        const recordId = event.target.dataset.id;
        const toggleType = event.target.dataset.type;
        const isChecked = event.target.checked;
        
        let sub = this.activeSubscriptions.find(s => s.Id === recordId);
        if (sub) {
            // Optimistic update
            if (toggleType === 'logs') sub.Enable_Logs__c = isChecked;
            if (toggleType === 'leads') sub.Enable_Lead_Creation__c = isChecked;
            
            // Force reactivity by cloning the array
            this.activeSubscriptions = [...this.activeSubscriptions];
            
            try {
                await updateSubscriptionSettings({
                    recordId: recordId,
                    enableLogs: sub.Enable_Logs__c,
                    enableLeads: sub.Enable_Lead_Creation__c
                });
                this.showToast('Success', 'Settings saved.', 'success');
            } catch (error) {
                this.showToast('Error', 'Failed to save settings.', 'error');
                // Revert on failure
                if (toggleType === 'logs') sub.Enable_Logs__c = !isChecked;
                if (toggleType === 'leads') sub.Enable_Lead_Creation__c = !isChecked;
                this.activeSubscriptions = [...this.activeSubscriptions];
            }
        }
    }

    // ─── Step 6: Load Active Subscriptions ────────────────────────────
    async loadSubscriptions() {
        try {
            this.activeSubscriptions = await getActiveSubscriptions();
        } catch (e) {
            // Non-critical
        }
    }

    // ─── Step 8: Load integration logs ───────────────────────────────
    async loadLogs() {
        try {
            const logs = await getIntegrationLogs();
            this.integrationLogs = logs.map(log => ({
                ...log,
                statusClass: log.Processing_Status__c === 'Success' ? 'slds-text-color_success' : 
                             log.Processing_Status__c === 'Failed'  ? 'slds-text-color_error' : ''
            }));
        } catch (e) {
            // Non-critical
        }
    }

    // ─── Disconnect ───────────────────────────────────────────────────
    async handleDisconnect() {
        try {
            await disconnect();
            this.setConnectedState(false);
            this.pageOptions = [];
            this.activeSubscriptions = [];
            this.integrationLogs = [];
            this.showToast('Disconnected', 'Facebook account has been disconnected.', 'info');
        } catch (e) {
            this.errorMessage = 'Failed to disconnect.';
        }
    }

    // ─── Helper: Set UI state ─────────────────────────────────────────
    setConnectedState(connected) {
        this.isConnected    = connected;
        this.isDisconnected = !connected;
        this.errorMessage   = '';
    }

    // ─── Helper: Show toast notification ─────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─── Computed properties ──────────────────────────────────────────
    get subscribeButtonLabel() {
        return this.isSubscribing ? 'Subscribing...' : 'Subscribe to Lead Ads';
    }

    get isSubscribeDisabled() {
        return !this.selectedPageId || this.isSubscribing;
    }

    get hasSubscriptions() {
        return this.activeSubscriptions && this.activeSubscriptions.length > 0;
    }

    get hasLogs() {
        return this.integrationLogs && this.integrationLogs.length > 0;
    }
}

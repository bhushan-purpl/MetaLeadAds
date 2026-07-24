import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getFacebookLoginUrl    from '@salesforce/apex/MetaAuthController.getFacebookLoginUrl';
import isConnected            from '@salesforce/apex/MetaAuthController.isConnected';
import getManagedPages        from '@salesforce/apex/MetaAuthController.getManagedPages';
import subscribePage          from '@salesforce/apex/MetaAuthController.subscribePage';
import getActiveSubscriptions from '@salesforce/apex/MetaAuthController.getActiveSubscriptions';
import disconnect             from '@salesforce/apex/MetaAuthController.disconnect';
import getIntegrationLogs     from '@salesforce/apex/MetaAuthController.getIntegrationLogs';
import getDashboardData       from '@salesforce/apex/MetaAuthController.getDashboardData';
import retryLead              from '@salesforce/apex/MetaAuthController.retryLead';
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
    // ─── Dashboard Data ───────────────────────────────────────────────
    @track dashboard = {
        totalReceived: 0,
        totalSuccess: 0,
        totalFailed: 0,
        todayReceived: 0
    };
    @track allLogs = [];
    @track displayedLogs = [];
    @track errorMessage = '';
    
    // ─── Dashboard State ──────────────────────────────────────────────
    @track dateFilter = 'Last 7 Days';
    @track statusFilter = 'All';
    @track searchQuery = '';
    
    @track isModalOpen = false;
    @track selectedLog = null;
    @track autoRefreshEnabled = true;
    
    // Pagination
    @track currentPage = 1;
    @track rowsPerPage = 10;
    
    dateOptions = [
        { label: 'Today', value: 'Today' },
        { label: 'Yesterday', value: 'Yesterday' },
        { label: 'Last 7 Days', value: 'Last 7 Days' },
        { label: 'Last 30 Days', value: 'Last 30 Days' },
        { label: 'This Month', value: 'This Month' },
        { label: 'Last Month', value: 'Last Month' },
        { label: 'Custom Range', value: 'Custom Range' }
    ];
    
    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Success', value: 'Success' },
        { label: 'Failed', value: 'Failed' }
    ];
    
    rowsOptions = [
        { label: '10', value: '10' },
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];
    
    refreshIntervalId;

    // ─── Column definitions ───────────────────────────────────────────
    // ─── Computed Dashboard Properties ───────────────────────────────
    get successRate() {
        if (this.dashboard.totalReceived === 0) return 0;
        return Math.round((this.dashboard.totalSuccess / this.dashboard.totalReceived) * 100);
    }
    
    get failedRate() {
        if (this.dashboard.totalReceived === 0) return 0;
        return Math.round((this.dashboard.totalFailed / this.dashboard.totalReceived) * 100);
    }

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
                this.loadDashboardData();
                this.startAutoRefresh();
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
                this.loadDashboardData();
                this.startAutoRefresh();
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
            if (toggleType === 'logs') sub.Enable_Logs = isChecked;
            if (toggleType === 'leads') sub.Enable_Lead_Creation = isChecked;
            
            // Force reactivity by cloning the array
            this.activeSubscriptions = [...this.activeSubscriptions];
            
            try {
                await updateSubscriptionSettings({
                    recordId: recordId,
                    enableLogs: sub.Enable_Logs,
                    enableLeads: sub.Enable_Lead_Creation
                });
                this.showToast('Success', 'Settings saved.', 'success');
            } catch (error) {
                this.showToast('Error', 'Failed to save settings.', 'error');
                // Revert on failure
                if (toggleType === 'logs') sub.Enable_Logs = !isChecked;
                if (toggleType === 'leads') sub.Enable_Lead_Creation = !isChecked;
                this.activeSubscriptions = [...this.activeSubscriptions];
            }
        }
    }

    // ─── Step 6: Load Active Subscriptions ────────────────────────────
    async loadSubscriptions() {
        try {
            const result = await getActiveSubscriptions();
            this.activeSubscriptions = JSON.parse(JSON.stringify(result));
        } catch (e) {
            // Non-critical
        }
    }

    // ─── Dashboard Logic ───────────────────────────────────────────────
    async loadDashboardData() {
        try {
            const data = await getDashboardData({ 
                dateFilter: this.dateFilter, 
                statusFilter: this.statusFilter 
            });
            
            this.dashboard = {
                totalReceived: data.totalReceived,
                totalSuccess: data.totalSuccess,
                totalFailed: data.totalFailed,
                todayReceived: data.todayReceived
            };
            
            // Parse JSON and prepare logs
            this.allLogs = (data.logs || []).map(log => {
                let parsedLead = {};
                let parsedPayload = {};
                try {
                    if (log.Raw_Lead_Data) {
                        parsedLead = JSON.parse(log.Raw_Lead_Data);
                    }
                } catch(e) {}
                
                try {
                    if (log.Lead_Payload) {
                        parsedPayload = JSON.parse(log.Lead_Payload);
                    }
                } catch(e) {}
                
                let formName = 'Unknown Form';
                try {
                    if (parsedLead.form_id) {
                        formName = parsedLead.form_id; // Could be better, but we don't have form name
                    }
                } catch(e) {}

                // Extract fields - case insensitive check
                let email = parsedLead.email || parsedLead.work_email || '';
                let phone = parsedLead.phone_number || parsedLead.work_phone_number || parsedLead.phone || '';
                let fullName = parsedLead.full_name || '';
                if (!fullName) {
                    if (parsedLead.first_name || parsedLead.last_name) {
                        fullName = (parsedLead.first_name || '') + ' ' + (parsedLead.last_name || '');
                    } else {
                        fullName = 'Meta Lead ' + log.Meta_Lead_ID;
                    }
                }
                
                let statusBadgeClass = 'slds-badge ';
                if (log.Processing_Status === 'Success') statusBadgeClass += 'slds-theme_success';
                else if (log.Processing_Status === 'Failed') statusBadgeClass += 'slds-theme_error';
                else if (log.Processing_Status === 'Duplicate') statusBadgeClass += 'slds-theme_warning';
                else statusBadgeClass += 'slds-theme_default';

                // Prettify JSON strings for the modal
                let prettyPayload = log.Lead_Payload ? JSON.stringify(parsedPayload, null, 2) : '';
                let prettyRaw = log.Raw_Lead_Data ? JSON.stringify(parsedLead, null, 2) : '';

                return {
                    ...log,
                    LeadName: fullName,
                    Email: email,
                    Phone: phone,
                    FormName: log.Form_ID, // Use ID as fallback
                    ReceivedOn: new Date(log.CreatedDate).toLocaleString(),
                    StatusBadgeClass: statusBadgeClass,
                    isFailed: log.Processing_Status === 'Failed',
                    PrettyPayload: prettyPayload,
                    PrettyRaw: prettyRaw,
                    Salesforce_Lead_URL: log.Salesforce_Lead_ID ? '/' + log.Salesforce_Lead_ID : ''
                };
            });
            
            this.applyFiltersAndPagination();
        } catch (e) {
            console.error('Error loading dashboard', e);
        }
    }
    
    handleFilterChange(event) {
        const field = event.target.name;
        if (field === 'dateFilter') this.dateFilter = event.detail.value;
        if (field === 'statusFilter') this.statusFilter = event.detail.value;
        if (field === 'searchQuery') this.searchQuery = event.target.value;
        
        this.currentPage = 1; // reset on filter
        
        // If it's date or status, we need to query server
        if (field === 'dateFilter' || field === 'statusFilter') {
            this.loadDashboardData();
        } else {
            // Just search locally
            this.applyFiltersAndPagination();
        }
    }
    
    applyFiltersAndPagination() {
        let filtered = [...this.allLogs];
        
        // Local Search
        if (this.searchQuery) {
            const sq = this.searchQuery.toLowerCase();
            filtered = filtered.filter(l => 
                (l.LeadName && l.LeadName.toLowerCase().includes(sq)) ||
                (l.Email && l.Email.toLowerCase().includes(sq)) ||
                (l.Phone && l.Phone.toLowerCase().includes(sq)) ||
                (l.FormName && l.FormName.toLowerCase().includes(sq))
            );
        }
        
        // Pagination
        const start = (this.currentPage - 1) * parseInt(this.rowsPerPage);
        const end = start + parseInt(this.rowsPerPage);
        this.displayedLogs = filtered.slice(start, end);
    }
    
    handleRowsChange(event) {
        this.rowsPerPage = event.detail.value;
        this.currentPage = 1;
        this.applyFiltersAndPagination();
    }
    
    handleNextPage() {
        this.currentPage++;
        this.applyFiltersAndPagination();
    }
    
    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.applyFiltersAndPagination();
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        const filteredCount = this.searchQuery ? 
            this.allLogs.filter(l => (l.LeadName||'').toLowerCase().includes(this.searchQuery.toLowerCase())).length : 
            this.allLogs.length;
        return (this.currentPage * parseInt(this.rowsPerPage)) >= filteredCount;
    }
    
    // Auto Refresh
    startAutoRefresh() {
        if (this.refreshIntervalId) clearInterval(this.refreshIntervalId);
        if (this.autoRefreshEnabled) {
            this.refreshIntervalId = setInterval(() => {
                this.loadDashboardData();
            }, 30000);
        }
    }
    
    handleAutoRefreshToggle(event) {
        this.autoRefreshEnabled = event.target.checked;
        if (this.autoRefreshEnabled) {
            this.startAutoRefresh();
        } else {
            if (this.refreshIntervalId) clearInterval(this.refreshIntervalId);
        }
    }
    
    // Modal
    async handleRetryClick(event) {
        const logId = event.currentTarget.dataset.id;
        
        const result = await LightningConfirm.open({
            message: 'This will attempt to create the failed Meta Lead in Salesforce again using the current mapping and business logic.',
            variant: 'headerless',
            label: 'Retry Lead Creation?',
            theme: 'warning'
        });
        
        if (result) {
            try {
                await retryLead({ logId: logId });
                this.showToast('Retry Initiated', 'The lead is being reprocessed.', 'success');
                setTimeout(() => {
                    this.loadDashboardData();
                }, 2000);
            } catch (error) {
                this.showToast('Retry Failed', error.body ? error.body.message : error.message, 'error');
            }
        }
    }

    openLogModal(event) {
        const logId = event.currentTarget.dataset.id;
        this.selectedLog = this.allLogs.find(l => l.Id === logId);
        this.isModalOpen = true;
    }
    
    closeLogModal() {
        this.isModalOpen = false;
        this.selectedLog = null;
    }
    
    handleCopyJson(event) {
        const type = event.currentTarget.dataset.type;
        const text = type === 'payload' ? this.selectedLog.PrettyPayload : this.selectedLog.PrettyRaw;
        
        navigator.clipboard.writeText(text).then(() => {
            this.showToast('Copied', 'JSON copied to clipboard', 'success');
        });
    }

    // ─── Disconnect ───────────────────────────────────────────────────
    async handleDisconnect() {
        try {
            await disconnect();
            this.setConnectedState(false);
            this.pageOptions = [];
            this.activeSubscriptions = [];
            this.allLogs = [];
            this.displayedLogs = [];
            if (this.refreshIntervalId) clearInterval(this.refreshIntervalId);
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
        return this.displayedLogs && this.displayedLogs.length > 0;
    }
}

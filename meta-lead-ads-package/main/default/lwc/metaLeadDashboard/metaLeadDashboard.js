import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardStats   from '@salesforce/apex/MetaDashboardController.getDashboardStats';
import isConnected         from '@salesforce/apex/MetaAuthController.isConnected';
import getFacebookLoginUrl from '@salesforce/apex/MetaAuthController.getFacebookLoginUrl';
import disconnect          from '@salesforce/apex/MetaAuthController.disconnect';
import saveAssignment      from '@salesforce/apex/MetaLeadAssignmentService.saveAssignment';
import getAssignment       from '@salesforce/apex/MetaLeadAssignmentService.getAssignment';
import getQueues           from '@salesforce/apex/MetaLeadAssignmentService.getQueues';
import getUsers            from '@salesforce/apex/MetaLeadAssignmentService.getUsers';

export default class MetaLeadDashboard extends LightningElement {

    // ─── Connection ───────────────────────────────────────────────────
    @track isConnected         = false;

    // ─── Stats ────────────────────────────────────────────────────────
    @track stats = {
        connectedPages: 0, totalForms: 0, mappedForms: 0, unmappedForms: 0,
        lastLeadFormatted: '--', lastSyncFormatted: '--'
    };
    @track recentLogs = [];

    // ─── Navigation ───────────────────────────────────────────────────
    @track activeTab       = 'pages';   // pages | mapping | logs
    @track showFormsView   = false;
    @track selectedPageId  = '';
    @track selectedPageName = '';

    // ─── Assignment modal ─────────────────────────────────────────────
    @track showAssignmentModal = false;
    @track assignmentFormId    = '';
    @track assignmentFormName  = '';
    @track assignmentOwnerType = 'Queue';
    @track assignmentOwnerId   = '';
    @track ownerOptions        = [];
    @track errorMessage        = '';

    ownerTypeOptions = [
        { label: 'Queue',  value: 'Queue' },
        { label: 'User',   value: 'User'  },
    ];

    // ─── Lifecycle ───────────────────────────────────────────────────
    connectedCallback() {
        this.checkConnection();
        this.loadStats();
        window.addEventListener('message', this.handleOAuthMessage.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleOAuthMessage.bind(this));
    }

    // ─── Connection ──────────────────────────────────────────────────
    async checkConnection() {
        try {
            this.isConnected = await isConnected();
        } catch (e) { /* silent */ }
    }

    async handleConnect() {
        try {
            const url = await getFacebookLoginUrl();
            const popup = window.open(url, 'FBLogin', 'width=600,height=700,top=100,left=300');
            if (!popup) this.errorMessage = 'Popup blocked! Please allow popups for this page.';
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Connection failed.';
        }
    }

    handleOAuthMessage(event) {
        if (event.data && event.data.type === 'META_AUTH_CALLBACK' && event.data.status === 'success') {
            this.isConnected = true;
            this.showToast('Success', 'Facebook connected!', 'success');
            this.loadStats();
        }
    }

    async handleDisconnect() {
        try {
            await disconnect();
            this.isConnected = false;
            this.showToast('Disconnected', 'Facebook account disconnected.', 'info');
        } catch (e) {
            this.errorMessage = 'Disconnect failed.';
        }
    }

    // ─── Stats ───────────────────────────────────────────────────────
    async loadStats() {
        try {
            const data = await getDashboardStats();
            this.stats = {
                connectedPages:   data.connectedPages || 0,
                totalForms:       data.totalForms     || 0,
                mappedForms:      data.mappedForms     || 0,
                unmappedForms:    data.unmappedForms   || 0,
                lastLeadFormatted: data.lastLeadDate   ? this.formatDate(data.lastLeadDate) : 'None',
                lastSyncFormatted: data.lastSyncDate   ? this.formatDate(data.lastSyncDate) : 'Never',
            };
            this.recentLogs = (data.recentLogs || []).map(log => ({
                ...log,
                statusClass:   log.Processing_Status__c === 'Success' ? 'badge-success' :
                               log.Processing_Status__c === 'Failed'  ? 'badge-error'   : 'badge-pending',
                formattedDate: log.CreatedDate ? this.formatDate(log.CreatedDate) : '--'
            }));
        } catch (e) { /* silent */ }
    }

    formatDate(isoString) {
        if (!isoString) return '--';
        const d = new Date(isoString);
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
    }

    // ─── Navigation ──────────────────────────────────────────────────
    showPages()   { this.activeTab = 'pages'; }
    showMapping() { this.activeTab = 'mapping'; }
    showLogs()    { this.activeTab = 'logs'; this.loadStats(); }

    handlePageSelect(event) {
        this.selectedPageId   = event.detail.pageId;
        this.selectedPageName = event.detail.pageName;
        this.showFormsView    = true;
    }

    handleBackToPages() {
        this.showFormsView  = false;
        this.selectedPageId = '';
    }

    handleMapForm(event) {
        // Switch to mapping tab with page/form pre-selected
        this.activeTab = 'mapping';
    }

    // ─── Assignment Modal ─────────────────────────────────────────────
    async handleAssignment(event) {
        this.assignmentFormId   = event.detail.formId;
        this.assignmentFormName = event.detail.formName;
        this.assignmentOwnerType = 'Queue';
        this.assignmentOwnerId   = '';

        // Load existing assignment
        try {
            const existing = await getAssignment({ formId: this.assignmentFormId });
            if (existing) {
                this.assignmentOwnerType = existing.Owner_Type__c || 'Queue';
                this.assignmentOwnerId   = existing.Owner_ID__c   || '';
            }
        } catch (e) { /* silent */ }

        await this.loadOwnerOptions();
        this.showAssignmentModal = true;
    }

    async loadOwnerOptions() {
        try {
            if (this.assignmentOwnerType === 'Queue') {
                const queues = await getQueues();
                this.ownerOptions = (queues || []);
            } else {
                const users = await getUsers();
                this.ownerOptions = (users || []);
            }
        } catch (e) { this.ownerOptions = []; }
    }

    handleOwnerTypeChange(event) {
        this.assignmentOwnerType = event.detail.value;
        this.assignmentOwnerId   = '';
        this.loadOwnerOptions();
    }

    handleOwnerChange(event) {
        this.assignmentOwnerId = event.detail.value;
        const selected = this.ownerOptions.find(o => o.value === this.assignmentOwnerId);
        this.assignmentOwnerName = selected ? selected.label : '';
    }

    async handleSaveAssignment() {
        try {
            await saveAssignment({
                formId:    this.assignmentFormId,
                ownerType: this.assignmentOwnerType,
                ownerId:   this.assignmentOwnerId,
                ownerName: this.assignmentOwnerName || ''
            });
            this.showToast('Saved!', 'Lead assignment configured successfully.', 'success');
            this.closeAssignmentModal();
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Save failed.';
        }
    }

    closeAssignmentModal() { this.showAssignmentModal = false; }

    // ─── Helpers ─────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─── Computed ────────────────────────────────────────────────────
    get showPagesTab()  { return this.activeTab === 'pages'; }
    get showMappingTab(){ return this.activeTab === 'mapping'; }
    get showLogsTab()   { return this.activeTab === 'logs'; }
    get hasLogs()       { return this.recentLogs && this.recentLogs.length > 0; }

    get tab1Class() { return 'nav-tab' + (this.activeTab === 'pages'   ? ' nav-tab-active' : ''); }
    get tab2Class() { return 'nav-tab' + (this.activeTab === 'mapping' ? ' nav-tab-active' : ''); }
    get tab3Class() { return 'nav-tab' + (this.activeTab === 'logs'    ? ' nav-tab-active' : ''); }
}
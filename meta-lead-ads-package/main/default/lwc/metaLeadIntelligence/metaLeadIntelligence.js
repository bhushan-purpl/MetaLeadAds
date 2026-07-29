import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/MetaLeadIntelligenceController.getDashboardData';
import getLeadTimeline from '@salesforce/apex/MetaLeadIntelligenceController.getLeadTimeline';
import exportLeadsCsv from '@salesforce/apex/MetaLeadIntelligenceController.exportLeadsCsv';

export default class MetaLeadIntelligence extends LightningElement {

    @track isLoading = true;
    wiredDataResult;

    // Filters
    @track selectedDateRange = 'All Time';
    @track startDate = '';
    @track endDate = '';
    @track selectedProject = '';
    @track selectedStatus = '';
    @track selectedOwner = '';
    @track selectedCampaign = '';
    @track selectedPage = '';
    @track selectedForm = '';
    @track searchKey = '';
    @track selectedKpiKey = '';

    // Data from Controller
    @track rawData = null;
    @track kpiCards = [];
    @track funnelStages = [];
    @track campaignPerformance = [];
    @track projectPerformance = [];
    @track pagePerformance = [];
    @track formPerformance = [];
    @track ownerPerformance = [];
    @track statusDistribution = [];
    @track allLeads = [];
    @track validationFailures = [];
    @track webhookHealth = {};

    // Options
    @track projectOptions = [{ label: 'All Projects', value: '' }];
    @track statusOptions = [{ label: 'All Statuses', value: '' }];
    @track ownerOptions = [{ label: 'All Owners', value: '' }];
    @track campaignOptions = [{ label: 'All Campaigns', value: '' }];
    @track pageOptions = [{ label: 'All Pages', value: '' }];
    @track formOptions = [{ label: 'All Forms', value: '' }];

    // Pagination
    @track currentPage = 1;
    @track pageSize = 15;

    // Modal / Drawer
    @track showLeadDrawer = false;
    @track selectedLeadRecord = {};
    @track selectedLeadTimeline = [];
    @track isTimelineLoading = false;

    dateRangeOptions = [
        { label: 'All Time', value: 'All Time' },
        { label: 'Today', value: 'Today' },
        { label: 'This Week', value: 'This Week' },
        { label: 'This Month', value: 'This Month' },
        { label: 'This Quarter', value: 'This Quarter' },
        { label: 'Custom Date', value: 'Custom' }
    ];

    get filterJsonString() {
        return JSON.stringify({
            dateRange: this.selectedDateRange,
            startDate: this.startDate,
            endDate: this.endDate,
            project: this.selectedProject,
            status: this.selectedStatus,
            ownerId: this.selectedOwner,
            campaign: this.selectedCampaign,
            pageId: this.selectedPage,
            formId: this.selectedForm,
            searchKey: this.searchKey,
            kpiFilter: this.selectedKpiKey
        });
    }

    @wire(getDashboardData, { filterJson: '$filterJsonString' })
    wiredData(result) {
        this.wiredDataResult = result;
        this.isLoading = false;
        if (result.data) {
            this.rawData = result.data;
            this.processData(result.data);
        } else if (result.error) {
            this.showToast('Error', 'Failed to load dashboard data: ' + this.reduceErrors(result.error), 'error');
        }
    }

    processData(data) {
        // 1. Process KPI Cards
        if (data.kpiList) {
            this.kpiCards = data.kpiList.map(kpi => {
                let cardClass = 'kpi-card';
                if (kpi.variant) cardClass += ' kpi-' + kpi.variant;
                if (this.selectedKpiKey === kpi.key) cardClass += ' kpi-selected';
                return { ...kpi, cardClass };
            });
        }

        // 2. Process Funnel Stages
        if (data.funnelStages) {
            this.funnelStages = data.funnelStages.map(stage => {
                let widthPct = Math.max(stage.conversionPct, 4);
                return {
                    ...stage,
                    fillStyle: `width: ${widthPct}%;`
                };
            });
        }

        // 3. Process Status Distribution (Donut Legend)
        if (data.statusDistribution) {
            this.statusDistribution = data.statusDistribution.map(item => {
                return {
                    ...item,
                    dotStyle: `background-color: ${item.color};`
                };
            });
        }

        // 4. Performance Tables
        this.campaignPerformance = data.campaignPerformance || [];
        this.projectPerformance = data.projectPerformance || [];
        this.pagePerformance = data.pagePerformance || [];
        this.formPerformance = data.formPerformance || [];
        this.ownerPerformance = data.ownerPerformance || [];

        // 5. Leads Grid
        this.allLeads = data.leads || [];
        this.currentPage = 1;

        // 6. Validation Failures & Webhook Health
        this.validationFailures = data.validationFailures || [];
        this.webhookHealth = data.webhookHealth || {};

        // 7. Populate Picklist Options dynamically
        if (data.filterOptions) {
            if (data.filterOptions.projects && data.filterOptions.projects.length > 0) {
                this.projectOptions = [{ label: 'All Projects', value: '' }, ...data.filterOptions.projects];
            }
            if (data.filterOptions.statuses && data.filterOptions.statuses.length > 0) {
                this.statusOptions = [{ label: 'All Statuses', value: '' }, ...data.filterOptions.statuses];
            }
            if (data.filterOptions.owners && data.filterOptions.owners.length > 0) {
                this.ownerOptions = [{ label: 'All Owners', value: '' }, ...data.filterOptions.owners];
            }
            if (data.filterOptions.campaigns && data.filterOptions.campaigns.length > 0) {
                this.campaignOptions = [{ label: 'All Campaigns', value: '' }, ...data.filterOptions.campaigns];
            }
            if (data.filterOptions.pages && data.filterOptions.pages.length > 0) {
                this.pageOptions = [{ label: 'All Pages', value: '' }, ...data.filterOptions.pages];
            }
            if (data.filterOptions.forms && data.filterOptions.forms.length > 0) {
                this.formOptions = [{ label: 'All Forms', value: '' }, ...data.filterOptions.forms];
            }
        }
    }

    // ── Filter Change Handlers ──
    handleFilterChange(event) {
        const name = event.target.name;
        const value = event.target.value;
        this[name] = value;

        if (name === 'dateRange' && value === 'Custom') {
            if (!this.startDate) {
                const d = new Date();
                d.setDate(d.getDate() - 30);
                this.startDate = d.toISOString().slice(0, 10);
            }
            if (!this.endDate) {
                this.endDate = new Date().toISOString().slice(0, 10);
            }
        }

        this.currentPage = 1;
        this.isLoading = true;
        this.triggerWireRefresh();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.currentPage = 1;
    }

    handleKpiClick(event) {
        const key = event.currentTarget.dataset.key;
        if (this.selectedKpiKey === key) {
            this.selectedKpiKey = ''; // Toggle off
        } else {
            this.selectedKpiKey = key;
        }
        this.currentPage = 1;
        this.isLoading = true;
        this.triggerWireRefresh();
    }

    handleClearFilters() {
        this.selectedDateRange = 'All Time';
        this.startDate = '';
        this.endDate = '';
        this.selectedProject = '';
        this.selectedStatus = '';
        this.selectedOwner = '';
        this.selectedCampaign = '';
        this.selectedPage = '';
        this.selectedForm = '';
        this.searchKey = '';
        this.selectedKpiKey = '';
        this.currentPage = 1;
        this.isLoading = true;
        this.triggerWireRefresh();
    }

    async triggerWireRefresh() {
        if (this.wiredDataResult) {
            try {
                await refreshApex(this.wiredDataResult);
            } catch (e) {
                console.error('Error refreshing dashboard:', e);
            } finally {
                this.isLoading = false;
            }
        } else {
            this.isLoading = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await this.triggerWireRefresh();
    }

    // ── Getters for UI ──
    get isCustomDate() {
        return this.selectedDateRange === 'Custom';
    }

    get hasActiveFilters() {
        return this.selectedProject || this.selectedStatus || this.selectedOwner || this.selectedCampaign || this.selectedPage || this.selectedForm || this.searchKey || this.selectedKpiKey || this.selectedDateRange !== 'All Time';
    }

    get activeFilterSummary() {
        let parts = [];
        if (this.selectedDateRange !== 'All Time') parts.push(this.selectedDateRange);
        if (this.selectedProject) parts.push('Project: ' + this.selectedProject);
        if (this.selectedStatus) parts.push('Status: ' + this.selectedStatus);
        if (this.selectedKpiKey) parts.push('KPI: ' + this.selectedKpiKey);
        if (this.searchKey) parts.push('Search: "' + this.searchKey + '"');
        return parts.join(' | ');
    }

    get totalLeadsCount() {
        return this.allLeads ? this.allLeads.length : 0;
    }

    get totalPages() {
        return Math.ceil(this.totalLeadsCount / this.pageSize) || 1;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get paginatedLeads() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.allLeads.slice(start, start + this.pageSize);
    }

    get validationFailuresCount() {
        return this.validationFailures ? this.validationFailures.length : 0;
    }

    get hasValidationFailures() {
        return this.validationFailuresCount > 0;
    }

    get webhookHealthBadgeClass() {
        if (this.webhookHealth.status === 'Green') return 'status-badge status-active';
        if (this.webhookHealth.status === 'Yellow') return 'status-badge status-warning';
        return 'status-badge status-error';
    }

    get webhookDotStyle() {
        if (this.webhookHealth.status === 'Green') return 'background-color: #10b981;';
        if (this.webhookHealth.status === 'Yellow') return 'background-color: #f59e0b;';
        return 'background-color: #ef4444;';
    }

    // ── Pagination Handlers ──
    handlePrevPage() {
        if (!this.isFirstPage) this.currentPage--;
    }

    handleNextPage() {
        if (!this.isLastPage) this.currentPage++;
    }

    // ── CSV Export ──
    async handleExportCsv() {
        try {
            const csvStr = await exportLeadsCsv({ filterJson: this.filterJsonString });
            const element = document.createElement('a');
            element.setAttribute('href', 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvStr));
            element.setAttribute('download', `Lead_Intelligence_Report_${new Date().toISOString().slice(0, 10)}.csv`);
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            document.body.removeChild(element);
            this.showToast('Success', 'Lead Intelligence CSV report exported successfully!', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to export CSV: ' + this.reduceErrors(error), 'error');
        }
    }

    // ── Open Lead Timeline Drawer ──
    async handleOpenLead(event) {
        const leadId = event.target.dataset.id || event.currentTarget.dataset.id;
        const leadRec = this.allLeads.find(l => l.id === leadId);
        if (leadRec) {
            this.selectedLeadRecord = leadRec;
            this.showLeadDrawer = true;
            this.isTimelineLoading = true;
            try {
                const timeline = await getLeadTimeline({ leadId: leadId });
                this.selectedLeadTimeline = timeline.map(evt => ({
                    ...evt,
                    timestamp: new Date(evt.timestamp).toLocaleString()
                }));
            } catch (err) {
                this.showToast('Error', 'Failed to load lead timeline: ' + this.reduceErrors(err), 'error');
            } finally {
                this.isTimelineLoading = false;
            }
        }
    }

    handleCloseLeadDrawer() {
        this.showLeadDrawer = false;
        this.selectedLeadRecord = {};
        this.selectedLeadTimeline = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return JSON.stringify(error);
    }
}

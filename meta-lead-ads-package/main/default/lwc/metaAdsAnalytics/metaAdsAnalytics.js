import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAdAccounts from '@salesforce/apex/MetaAdsAnalyticsController.getAdAccounts';
import getDashboardAnalytics from '@salesforce/apex/MetaAdsAnalyticsController.getDashboardAnalytics';
import getMonthlyAnalytics from '@salesforce/apex/MetaAdsAnalyticsController.getMonthlyAnalytics';
import syncNow from '@salesforce/apex/MetaAdsAnalyticsController.syncNow';
import testMarketingApiConnection from '@salesforce/apex/MetaAdsAnalyticsController.testMarketingApiConnection';

export default class MetaAdsAnalytics extends LightningElement {
    @track isLoading = true;
    @track selectedAdAccount = '';
    @track selectedSyncFreq = 'Daily';
    @track adAccountOptions = [];
    @track metrics = {
        totalSpend: '0.00',
        todaySpend: '0.00',
        yesterdaySpend: '0.00',
        thisWeekSpend: '0.00',
        thisMonthSpend: '0.00',
        totalLeads: 0,
        totalClicks: 0,
        totalImpressions: 0,
        totalReach: 0,
        avgCtr: '0.00',
        avgCpc: '0.00',
        avgCpm: '0.00',
        avgCpl: '0.00',
        campaigns: []
    };

    syncFreqOptions = [
        { label: 'Every Hour', value: 'Hourly' },
        { label: 'Every 3 Hours', value: '3Hours' },
        { label: 'Every 6 Hours', value: '6Hours' },
        { label: 'Daily', value: 'Daily' }
    ];

    @track monthlyRows = [];
    @track hasMonthlyData = false;

    wiredAnalyticsResult;

    connectedCallback() {
        this.loadAdAccounts();
        this.loadMonthlyAnalytics();
    }

    async loadAdAccounts() {
        try {
            const data = await getAdAccounts();
            if (data && data.length > 0) {
                this.adAccountOptions = data.map(acc => ({
                    label: (acc.name || 'Unknown') + ' (' + (acc.account_id || acc.id) + ')',
                    value: acc.id
                }));
                this.selectedAdAccount = data[0].id;
            } else {
                this.adAccountOptions = [{ label: 'No Ad Accounts Found', value: '' }];
            }
        } catch(e) {
            this.showToast('Error', 'Failed to load ad accounts: ' + (e.body ? e.body.message : e.message), 'error');
        }
    }

    @wire(getDashboardAnalytics, { filterJson: '{}' })
    wiredAnalytics(result) {
        this.wiredAnalyticsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.processMetrics(result.data);
            this.loadMonthlyAnalytics();
        } else if (result.error) {
            this.showToast('Error', 'Failed to load Ads Analytics', 'error');
        }
    }

    processMetrics(data) {
        this.metrics = {
            totalSpend: Number(data.totalSpend || 0).toFixed(2),
            todaySpend: Number(data.todaySpend || 0).toFixed(2),
            yesterdaySpend: Number(data.yesterdaySpend || 0).toFixed(2),
            thisWeekSpend: Number(data.thisWeekSpend || 0).toFixed(2),
            thisMonthSpend: Number(data.thisMonthSpend || 0).toFixed(2),
            totalLeads: data.totalLeads || 0,
            totalClicks: data.totalClicks || 0,
            totalImpressions: data.totalImpressions || 0,
            totalReach: data.totalReach || 0,
            avgCtr: Number(data.avgCtr || 0).toFixed(2),
            avgCpc: Number(data.avgCpc || 0).toFixed(2),
            avgCpm: Number(data.avgCpm || 0).toFixed(2),
            avgCpl: Number(data.avgCpl || 0).toFixed(2),
            conversionRate: Number(data.conversionRate || 0).toFixed(2),
            convertedLeads: data.convertedLeads || 0,
            failedLeads: data.failedLeads || 0,
            pendingLeads: data.pendingLeads || 0,
            successRate: Number(data.successRate || 0).toFixed(2),
            bookingRatio: Number(data.bookingRatio || 0).toFixed(2),
            campaigns: (data.campaigns || []).map(c => ({
                ...c,
                Spend__c: Number(c.Spend__c || 0).toFixed(2),
                CPL__c: Number(c.CPL__c || 0).toFixed(2),
                CPC__c: Number(c.CPC__c || 0).toFixed(2),
                CTR__c: Number(c.CTR__c || 0).toFixed(2)
            }))
        };
    }

    handleAdAccountChange(event) {
        this.selectedAdAccount = event.target.value;
    }

    handleFreqChange(event) {
        this.selectedSyncFreq = event.target.value;
    }

    async handleTestConnection() {
        this.isLoading = true;
        try {
            const res = await testMarketingApiConnection();
            if (res.success) {
                this.showToast('Success', res.message, 'success');
            } else {
                this.showToast('Warning', res.message, 'warning');
            }
        } catch (e) {
            this.showToast('Error', 'Connection test failed: ' + e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSyncCampaigns() {
        if (!this.selectedAdAccount) {
            this.showToast('Warning', 'Please select an Ad Account first', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const res = await syncNow({ adAccountId: this.selectedAdAccount, syncType: 'campaigns' });
            this.showToast(res.success ? 'Success' : 'Error', res.message, res.success ? 'success' : 'error');
            await refreshApex(this.wiredAnalyticsResult);
        } catch (e) {
            this.showToast('Error', e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSyncInsights() {
        if (!this.selectedAdAccount) {
            this.showToast('Warning', 'Please select an Ad Account first', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const res = await syncNow({ adAccountId: this.selectedAdAccount, syncType: 'insights' });
            this.showToast(res.success ? 'Success' : 'Error', res.message, res.success ? 'success' : 'error');
            await refreshApex(this.wiredAnalyticsResult);
        } catch (e) {
            this.showToast('Error', e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredAnalyticsResult);
        await this.loadMonthlyAnalytics();
        this.isLoading = false;
    }

    async loadMonthlyAnalytics() {
        try {
            const data = await getMonthlyAnalytics();
            if (data && data.length > 0) {
                this.monthlyRows = data.map(row => ({
                    ...row,
                    fSpend:  '₹' + Number(row.spend  || 0).toFixed(2),
                    fCpl:    '₹' + Number(row.cpl    || 0).toFixed(2),
                    fCpc:    '₹' + Number(row.cpc    || 0).toFixed(2),
                    fCtr:    Number(row.ctr || 0).toFixed(2) + '%'
                }));
                this.hasMonthlyData = true;
            } else {
                this.hasMonthlyData = false;
            }
        } catch(e) {
            this.hasMonthlyData = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

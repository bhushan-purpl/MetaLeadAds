import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAdAccounts from '@salesforce/apex/MetaAdsAnalyticsController.getAdAccounts';
import getDashboardAnalytics from '@salesforce/apex/MetaAdsAnalyticsController.getDashboardAnalytics';
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

    wiredAnalyticsResult;

    @wire(getAdAccounts)
    wiredAdAccounts({ data, error }) {
        if (data) {
            this.adAccountOptions = data.map(acc => ({
                label: acc.name + ' (' + acc.account_id + ')',
                value: acc.id
            }));
            if (data.length > 0) {
                this.selectedAdAccount = data[0].id;
            }
        }
    }

    @wire(getDashboardAnalytics, { filterJson: '{}' })
    wiredAnalytics(result) {
        this.wiredAnalyticsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.processMetrics(result.data);
        } else if (result.error) {
            this.showToast('Error', 'Failed to load Ads Analytics', 'error');
        }
    }

    processMetrics(data) {
        this.metrics = {
            totalSpend: (data.totalSpend || 0).toFixed(2),
            todaySpend: (data.todaySpend || 0).toFixed(2),
            yesterdaySpend: (data.yesterdaySpend || 0).toFixed(2),
            thisWeekSpend: (data.thisWeekSpend || 0).toFixed(2),
            thisMonthSpend: (data.thisMonthSpend || 0).toFixed(2),
            totalLeads: data.totalLeads || 0,
            totalClicks: data.totalClicks || 0,
            totalImpressions: data.totalImpressions || 0,
            totalReach: data.totalReach || 0,
            avgCtr: (data.avgCtr || 0).toFixed(2),
            avgCpc: (data.avgCpc || 0).toFixed(2),
            avgCpm: (data.avgCpm || 0).toFixed(2),
            avgCpl: (data.avgCpl || 0).toFixed(2),
            campaigns: (data.campaigns || []).map(c => ({
                ...c,
                Spend__c: (c.Spend__c || 0).toFixed(2),
                CPL__c: (c.CPL__c || 0).toFixed(2),
                CPC__c: (c.CPC__c || 0).toFixed(2),
                CTR__c: (c.CTR__c || 0).toFixed(2)
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
        this.isLoading = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

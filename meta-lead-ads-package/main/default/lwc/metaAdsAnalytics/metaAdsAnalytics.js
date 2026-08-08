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
    
    // Demo Mode
    @track isDemoMode = true;
    get isLiveMode() {
        return !this.isDemoMode;
    }

    handleModeToggle(event) {
        this.isDemoMode = !event.target.checked;
        if (this.wiredAnalyticsResult && this.wiredAnalyticsResult.data) {
            this.processMetrics(this.wiredAnalyticsResult.data);
        }
        this.loadMonthlyAnalytics();
    }

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
        let displayData = data;
        
        if (this.isDemoMode) {
            displayData = {
                totalSpend: 245000.00,
                todaySpend: 1540.50,
                yesterdaySpend: 4200.00,
                thisWeekSpend: 28400.00,
                thisMonthSpend: 84500.00,
                totalLeads: 1248,
                totalClicks: 42600,
                totalImpressions: 894000,
                totalReach: 320500,
                avgCtr: 4.76,
                avgCpc: 5.75,
                avgCpm: 274.04,
                avgCpl: 196.31,
                conversionRate: 15.2,
                convertedLeads: 190,
                failedLeads: 12,
                pendingLeads: 45,
                successRate: 99.04,
                bookingRatio: 3.8,
                campaigns: [
                    { Name: 'Diwali Special Offer 2026', Spend__c: 125000, CPL__c: 180, CPC__c: 4.5, CTR__c: 5.2, Leads__c: 694 },
                    { Name: 'Retargeting - Website Visitors', Spend__c: 45000, CPL__c: 210, CPC__c: 6.8, CTR__c: 3.9, Leads__c: 214 },
                    { Name: 'Lookalike Audience 1%', Spend__c: 75000, CPL__c: 220, CPC__c: 7.1, CTR__c: 4.5, Leads__c: 340 }
                ]
            };
        }

        this.metrics = {
            totalSpend: Number(displayData.totalSpend || 0).toFixed(2),
            todaySpend: Number(displayData.todaySpend || 0).toFixed(2),
            yesterdaySpend: Number(displayData.yesterdaySpend || 0).toFixed(2),
            thisWeekSpend: Number(displayData.thisWeekSpend || 0).toFixed(2),
            thisMonthSpend: Number(displayData.thisMonthSpend || 0).toFixed(2),
            totalLeads: displayData.totalLeads || 0,
            totalClicks: displayData.totalClicks || 0,
            totalImpressions: displayData.totalImpressions || 0,
            totalReach: displayData.totalReach || 0,
            avgCtr: Number(displayData.avgCtr || 0).toFixed(2),
            avgCpc: Number(displayData.avgCpc || 0).toFixed(2),
            avgCpm: Number(displayData.avgCpm || 0).toFixed(2),
            avgCpl: Number(displayData.avgCpl || 0).toFixed(2),
            conversionRate: Number(displayData.conversionRate || 0).toFixed(2),
            convertedLeads: displayData.convertedLeads || 0,
            failedLeads: displayData.failedLeads || 0,
            pendingLeads: displayData.pendingLeads || 0,
            successRate: Number(displayData.successRate || 0).toFixed(2),
            bookingRatio: Number(displayData.bookingRatio || 0).toFixed(2),
            campaigns: (displayData.campaigns || []).map(c => ({
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
        if (this.isDemoMode) {
            const dummyMonthly = [
                { monthYear: 'August 2026', spend: 84500, leads: 430, cpl: 196.5, cpc: 5.8, ctr: 4.6, impressions: 290000 },
                { monthYear: 'July 2026', spend: 95000, leads: 480, cpl: 197.9, cpc: 6.1, ctr: 4.4, impressions: 310000 },
                { monthYear: 'June 2026', spend: 65500, leads: 338, cpl: 193.7, cpc: 5.5, ctr: 4.9, impressions: 240000 }
            ];
            this.monthlyRows = dummyMonthly.map(row => ({
                ...row,
                fSpend:  '₹' + Number(row.spend  || 0).toFixed(2),
                fCpl:    '₹' + Number(row.cpl    || 0).toFixed(2),
                fCpc:    '₹' + Number(row.cpc    || 0).toFixed(2),
                fCtr:    Number(row.ctr || 0).toFixed(2) + '%'
            }));
            this.hasMonthlyData = true;
            return;
        }

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

import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import registerTrial from '@salesforce/apex/MetaLicenseService.registerTrial';
import validateLicense from '@salesforce/apex/MetaLicenseService.validateLicense';

export default class MetaLicenseManager extends LightningElement {
    @track isLoading = true;
    @track licenseStatus = 'Unknown';
    @track rawStatus = 'Unknown';
    @track licenseExpiry = 'N/A';
    @track remainingDays = 0;
    @track maxPages = 0;
    @track licenseKey = '';
    @track inputKey = '';

    @track isExpiringSoon = false;
    @track isExpired = false;
    @track isTrial = false;
    @track isActiveStatus = false;
    @track isSuspended = false;

    connectedCallback() {
        this.initLicense();
    }

    async initLicense() {
        this.isLoading = true;
        try {
            const settings = await registerTrial();
            if (settings) {
                this.updateUI(settings);
            } else {
                this.licenseStatus = 'Not Registered';
            }
        } catch (error) {
            this.showToast('Error', 'Failed to initialize license: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleKeyChange(event) {
        this.inputKey = event.target.value;
    }

    get isActivateDisabled() {
        return !this.inputKey || this.inputKey.trim() === '';
    }

    async handleActivate() {
        this.isLoading = true;
        try {
            const result = await validateLicense({ licenseKey: this.inputKey.trim() });
            if (result.success) {
                this.updateUI(result.settings);
                this.inputKey = '';
                this.showToast('Success', 'License successfully activated!', 'success');
            } else {
                this.showToast('Validation Failed', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Validation error: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    updateUI(settings) {
        this.licenseStatus = settings.Status__c || 'Unknown';
        this.rawStatus     = settings.RawStatus__c || settings.Status__c || 'Unknown';
        this.licenseExpiry = settings.Expiration_Date__c || 'N/A';
        this.remainingDays = settings.Remaining_Days__c !== undefined ? settings.Remaining_Days__c : 0;
        this.maxPages      = settings.Max_Pages_Allowed__c || 0;
        this.licenseKey    = settings.License_Key__c || '';

        this.isExpired      = settings.Is_Expired__c || (this.licenseStatus === 'Expired');
        this.isExpiringSoon = settings.Is_Expiring_Soon__c || (this.licenseStatus === 'Expiring Soon');
        this.isTrial        = settings.Is_Trial__c || (this.rawStatus === 'Trial' && !this.isExpired);
        this.isActiveStatus = this.licenseStatus === 'Active';
        this.isSuspended    = settings.Is_Suspended__c || (this.licenseStatus === 'Suspended');
    }

    get statusBadgeClass() {
        if (this.isExpired) return 'status-badge status-expired';
        if (this.isExpiringSoon) return 'status-badge status-expiring';
        if (this.isTrial) return 'status-badge status-trial';
        if (this.isActiveStatus) return 'status-badge status-active';
        if (this.isSuspended) return 'status-badge status-suspended';
        return 'status-badge';
    }

    get statusIcon() {
        if (this.isExpired) return '🔴';
        if (this.isExpiringSoon) return '🟠';
        if (this.isTrial) return '🟡';
        if (this.isActiveStatus) return '🟢';
        if (this.isSuspended) return '⚫';
        return '⚪';
    }

    get daysText() {
        return `${this.remainingDays} ${this.remainingDays === 1 ? 'Day' : 'Days'}`;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return JSON.stringify(error);
    }
}

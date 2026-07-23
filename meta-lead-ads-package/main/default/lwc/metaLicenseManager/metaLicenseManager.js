import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import registerTrial from '@salesforce/apex/MetaLicenseService.registerTrial';
import validateLicense from '@salesforce/apex/MetaLicenseService.validateLicense';

export default class MetaLicenseManager extends LightningElement {
    @track isLoading = true;
    @track licenseStatus = 'Unknown';
    @track licenseExpiry = 'N/A';
    @track maxPages = 0;
    @track licenseKey = '';
    @track inputKey = '';

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

    get isTrial() {
        return this.licenseStatus === 'Trial';
    }

    updateUI(settings) {
        this.licenseStatus = settings.Status__c || 'Unknown';
        this.licenseExpiry = settings.Expiration_Date__c || 'N/A';
        this.maxPages = settings.Max_Pages_Allowed__c || 0;
        this.licenseKey = settings.License_Key__c || '';
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

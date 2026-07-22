import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncForms from '@salesforce/apex/MetaFormService.syncForms';
import getForms  from '@salesforce/apex/MetaFormService.getForms';

export default class MetaFormManager extends LightningElement {
    @api pageId;
    @api pageName = 'Facebook Page';
    @track forms = [];
    @track isLoading = false;
    @track errorMessage = '';

    connectedCallback() { if (this.pageId) this.loadForms(); }

    async loadForms() {
        try {
            const raw = await getForms({ pageId: this.pageId });
            this.forms = this.enrichForms(raw);
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load forms.';
        }
    }

    async handleSyncForms() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const raw = await syncForms({ pageId: this.pageId });
            this.forms = this.enrichForms(raw);
            this.dispatchEvent(new ShowToastEvent({ title: 'Synced!', message: `${this.forms.length} forms synced.`, variant: 'success' }));
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Sync failed.';
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() { this.dispatchEvent(new CustomEvent('back')); }

    handleMapForm(event) {
        const formId   = event.currentTarget.dataset.formId;
        const formName = event.currentTarget.dataset.formName;
        this.dispatchEvent(new CustomEvent('mapform', { detail: { formId, formName, pageId: this.pageId, pageName: this.pageName } }));
    }

    handleAssignment(event) {
        const formId   = event.currentTarget.dataset.formId;
        const formName = event.currentTarget.dataset.formName;
        this.dispatchEvent(new CustomEvent('assignment', { detail: { formId, formName } }));
    }

    enrichForms(raw) {
        return (raw || []).map(f => ({
            ...f,
            statusClass:  f.Status__c === 'Active' ? 'badge badge-success' : 'badge badge-neutral',
            mappedLabel:  f.Is_Mapped__c ? 'Mapped' : 'Unmapped',
            mappedClass:  f.Is_Mapped__c ? 'badge badge-mapped' : 'badge badge-unmapped'
        }));
    }

    get hasForms()   { return this.forms && this.forms.length > 0; }
    get totalForms() { return this.forms.length; }
}
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncPages from '@salesforce/apex/MetaPageService.syncPages';
import getPages  from '@salesforce/apex/MetaPageService.getPages';

export default class MetaPageManager extends LightningElement {
    @track pages = [];
    @track isLoading = false;
    @track errorMessage = '';

    connectedCallback() { this.loadPages(); }

    async loadPages() {
        try {
            const raw = await getPages();
            this.pages = this.enrichPages(raw);
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load pages.';
        }
    }

    async handleSyncPages() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const raw = await syncPages();
            this.pages = this.enrichPages(raw);
            this.dispatchEvent(new ShowToastEvent({ title: 'Synced!', message: `${this.pages.length} pages synced from Meta.`, variant: 'success' }));
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Sync failed.';
        } finally {
            this.isLoading = false;
        }
    }

    handlePageClick(event) {
        const pageId   = event.currentTarget.dataset.id;
        const pageName = event.currentTarget.dataset.name;
        this.dispatchEvent(new CustomEvent('pageselect', { detail: { pageId, pageName } }));
    }

    enrichPages(raw) {
        return (raw || []).map(p => ({
            ...p,
            initials:    (p.Page_Name || 'P').substring(0, 2).toUpperCase(),
            statusClass: p.Status === 'Connected' ? 'badge badge-success' : 'badge badge-error',
            Forms_Count: p.Forms_Count || 0
        }));
    }

    get hasPages()       { return this.pages && this.pages.length > 0; }
    get totalPages()     { return this.pages.length; }
    get connectedPages() { return this.pages.filter(p => p.Status === 'Connected').length; }
    get totalForms()     { return this.pages.reduce((s, p) => s + (p.Forms_Count || 0), 0); }
}
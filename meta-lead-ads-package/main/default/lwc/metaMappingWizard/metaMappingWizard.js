import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPages               from '@salesforce/apex/MetaPageService.getPages';
import getForms               from '@salesforce/apex/MetaFormService.getForms';
import syncFormQuestions      from '@salesforce/apex/MetaFormService.syncFormQuestions';
import getFormFieldsForMapping from '@salesforce/apex/MetaMappingService.getFormFieldsForMapping';
import getAutoSuggestions     from '@salesforce/apex/MetaMappingService.getAutoSuggestions';
import saveMappings           from '@salesforce/apex/MetaMappingService.saveMappings';
import getLeadFields          from '@salesforce/apex/MetaMappingService.getLeadFields';
import getPicklistValues      from '@salesforce/apex/MetaMappingService.getPicklistValues';

export default class MetaMappingWizard extends LightningElement {

    // ─── Step control ─────────────────────────────────────────────────
    @track currentStep      = 1;

    // ─── Step 1 data ──────────────────────────────────────────────────
    @track pages            = [];
    @track selectedPageId   = '';
    @track selectedPageName = '';
    @track isLoadingPages   = false;

    // ─── Step 2 data ──────────────────────────────────────────────────
    @track allForms         = [];   // full list from server
    @track forms            = [];   // kept for backward compat (filtered)
    @track formSearchTerm   = '';
    @track selectedFormId   = '';
    @track selectedFormName = '';
    @track isLoadingForms   = false;

    // ─── Step 3 data ──────────────────────────────────────────────────
    // allMappings: [{ facebookField, label, category, sfField, isUtm, sampleValue }]
    @track allMappings      = [];
    @track sfFieldOptions   = [];   // [{label, value}] for the dropdowns
    @track isLoadingFields  = false;
    @track isSaving         = false;
    // Map of fieldApiName → 'PICKLIST' | 'TEXT' (populated from getLeadFields)
    sfFieldTypeMap          = {};
    // Map of rowId → [{label, value}] picklist options for static rows
    @track staticPicklistMap = {};

    // ─── General ─────────────────────────────────────────────────────
    @track errorMessage     = '';

    // ─── Lifecycle ───────────────────────────────────────────────────
    connectedCallback() {
        this.loadPages();
        this.loadLeadFields();
    }

    // ─── Step navigation ─────────────────────────────────────────────
    async goToStep2() {
        this.currentStep = 2;
        await this.loadForms();
    }

    async goToStep3() {
        this.currentStep = 3;
        // Wait for BOTH lead fields AND form fields to load together
        // so sfFieldOptions is populated before the comboboxes try to render their selected values
        await Promise.all([
            this.loadLeadFields(),
            this.loadFieldsAndMappings()
        ]);
    }

    goToStep1() { this.currentStep = 1; }
    goToStep2Back() { this.currentStep = 2; }

    // ─── Step 1: Load pages ───────────────────────────────────────────
    async loadPages() {
        this.isLoadingPages = true;
        try {
            const raw = await getPages();
            this.pages = (raw || []).map(p => ({
                ...p,
                initials:   (p.Page_Name || 'P').substring(0, 2).toUpperCase(),
                isSelected: p.Page_ID === this.selectedPageId,
                cardClass:  p.Page_ID === this.selectedPageId ? 'ps-card ps-card-selected' : 'ps-card',
                Forms_Count: p.Forms_Count || 0
            }));
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load pages.';
        } finally {
            this.isLoadingPages = false;
        }
    }

    handleSelectPage(event) {
        this.selectedPageId   = event.currentTarget.dataset.id;
        this.selectedPageName = event.currentTarget.dataset.name;
        this.pages = this.pages.map(p => ({
            ...p,
            isSelected: p.Page_ID === this.selectedPageId,
            cardClass:  p.Page_ID === this.selectedPageId ? 'ps-card ps-card-selected' : 'ps-card'
        }));
    }

    // ─── Step 2: Load forms ──────────────────────────────────
    async loadForms() {
        this.isLoadingForms = true;
        this.formSearchTerm = ''; // reset search on every load
        try {
            const raw = await getForms({ pageId: this.selectedPageId });
            this.allForms = (raw || []).map(f => ({
                ...f,
                isSelected:  f.Form_ID === this.selectedFormId,
                cardClass:   f.Form_ID === this.selectedFormId ? 'fs-card fs-card-selected' : 'fs-card',
                mappedLabel: f.Is_Mapped ? 'Mapped' : 'Unmapped',
                mappedClass: f.Is_Mapped ? 'mapped-badge' : 'unmapped-badge',
            }));
            this.forms = this.allForms; // keep backward compat
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load forms.';
        } finally {
            this.isLoadingForms = false;
        }
    }

    // ─── Form search handler ──────────────────────────────────
    handleFormSearch(event) {
        this.formSearchTerm = event.target.value;
        const term = this.formSearchTerm.toLowerCase().trim();
        this.forms = term
            ? this.allForms.filter(f => (f.Form_Name || '').toLowerCase().includes(term))
            : this.allForms;
    }

    handleSelectForm(event) {
        this.selectedFormId   = event.currentTarget.dataset.id;
        this.selectedFormName = event.currentTarget.dataset.name;
        this.forms = this.forms.map(f => ({
            ...f,
            isSelected: f.Form_ID === this.selectedFormId,
            cardClass:  f.Form_ID === this.selectedFormId ? 'fs-card fs-card-selected' : 'fs-card'
        }));
    }

    // ─── Step 3: Load ALL fields & existing mappings via master Apex method ──
    async loadFieldsAndMappings() {
        this.isLoadingFields = true;
        this.errorMessage = '';
        try {
            // First sync questions from API to ensure they are fresh
            try {
                await syncFormQuestions({ formId: this.selectedFormId, pageId: this.selectedPageId });
            } catch (syncErr) {
                // Sync failure is non-fatal — we fall back to cached DB data
                console.warn('Form question sync failed, using cached data:', syncErr);
            }

            // Call master method — returns everything pre-categorized & merged with saved mappings
            const fields = await getFormFieldsForMapping({
                formId: this.selectedFormId,
                pageId: this.selectedPageId
            });

            this.allMappings = (fields || []).map((f, index) => ({
                id:            'row_' + index,
                facebookField: f.facebookField,
                label:         f.label || f.facebookField,
                category:      f.category || 'standard',
                sfField:       f.sfField || '',
                isUtm:         f.isUtm === true,
                sampleValue:   f.sampleValue || '',
                isStatic:      f.facebookField && f.facebookField.startsWith('STATIC::')
            }));

        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load form fields.';
        } finally {
            this.isLoadingFields = false;
        }
    }

    // ─── Load Salesforce Lead field options (for all dropdowns) ──────
    async loadLeadFields() {
        try {
            const fields = await getLeadFields();
            // Build the field type map for picklist detection
            const typeMap = {};
            (fields || []).forEach(f => { typeMap[f.value] = f.fieldType || 'TEXT'; });
            this.sfFieldTypeMap = typeMap;
            this.sfFieldOptions = [
                { label: '-- None --', value: '' },
                ...(fields || []).map(f => ({ label: f.label, value: f.value }))
            ];
        } catch (e) {
            console.error('Failed to load Salesforce Lead fields:', e);
        }
    }

    // ─── Auto Map — server does synonym matching, LWC just applies results ──
    async handleAutoMap() {
        try {
            const suggestions = await getAutoSuggestions({
                formId: this.selectedFormId,
                pageId: this.selectedPageId
            });
            // Build a lookup map from the suggestions returned by Apex
            const suggestMap = {};
            (suggestions || []).forEach(s => {
                if (s.sfField) suggestMap[s.facebookField] = s.sfField;
            });
            // Apply suggestions to existing rows (preserving any the user already mapped)
            this.allMappings = this.allMappings.map(row => ({
                ...row,
                sfField: suggestMap[row.facebookField] || row.sfField || ''
            }));
            this.dispatchEvent(new ShowToastEvent({
                title:   'Auto Mapped!',
                message: 'Fields have been automatically suggested using smart synonym matching. Review and save.',
                variant: 'success'
            }));
        } catch (e) {
            this.errorMessage = 'Auto-map failed: ' + (e.body ? e.body.message : e.message);
        }
    }

    // ─── Handle dropdown change (lightning-combobox fires event.detail.value) ──
    handleMappingChange(event) {
        const rowId  = event.currentTarget.dataset.id;
        const sfField = event.detail.value;
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, sfField } : row
        );
    }

    // ─── Handle Static Value Text Input ──
    handleStaticValueChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const val = event.target.value;
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, facebookField: 'STATIC::' + val, sampleValue: val } : row
        );
    }

    // ─── When SF field changes on a static row — detect picklist and load values ──
    async handleStaticSfFieldChange(event) {
        const rowId   = event.currentTarget.dataset.id;
        const sfField = event.detail.value;
        // First update the sfField
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, sfField, sampleValue: '', isPicklistMode: false, picklistOptions: [] } : row
        );
        if (!sfField) return;
        // Check if this is a picklist field
        if (this.sfFieldTypeMap[sfField] === 'PICKLIST') {
            try {
                const picklistOpts = await getPicklistValues({ fieldApiName: sfField });
                // Set isPicklistMode=true and attach options directly to the row
                this.allMappings = this.allMappings.map(row =>
                    row.id === rowId
                        ? { ...row, isPicklistMode: true, picklistOptions: picklistOpts }
                        : row
                );
            } catch (e) {
                console.error('Failed to load picklist values:', e);
            }
        }
    }

    // ─── When picklist value selected inside a static row ──
    handleStaticPicklistValueChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const val   = event.detail.value;
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, sampleValue: val, facebookField: 'STATIC::' + val } : row
        );
    }

    // Helper: check if a static row should show a picklist dropdown
    isStaticPicklist(rowId) {
        return !!(this.staticPicklistMap[rowId] && this.staticPicklistMap[rowId].length > 1);
    }

    // ─── Add Static Value Row ──
    handleAddStaticMapping() {
        const newId = 'static_' + Date.now();
        this.allMappings = [...this.allMappings, {
            id:            newId,
            facebookField: 'STATIC::',
            label:         'Static Text',
            category:      'static',
            sfField:       '',
            isUtm:         false,
            sampleValue:   '',
            isStatic:      true,
            isPicklist:    false
        }];
    }

    // ─── Save mappings ────────────────────────────────────────────────
    async handleSaveMapping() {
        this.isSaving = true;
        this.errorMessage = '';
        try {
            const mappingsJson = JSON.stringify(this.allMappings);
            await saveMappings({ formId: this.selectedFormId, mappingsJson });
            this.dispatchEvent(new ShowToastEvent({
                title:   'Saved!',
                message: `Mappings saved for ${this.selectedFormName}`,
                variant: 'success'
            }));
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Save failed.';
        } finally {
            this.isSaving = false;
        }
    }

    // ─── Computed: 4 dynamic field groups ────────────────────────────
    get standardFields()  { return this.allMappings.filter(m => m.category === 'standard'); }
    get customFields()    { return this.allMappings.filter(m => m.category === 'custom'); }
    get hiddenFields()    { return this.allMappings.filter(m => m.category === 'hidden'); }
    get trackingFields()  { return this.allMappings.filter(m => m.category === 'tracking'); }
    get staticFields()    { return this.allMappings.filter(m => m.category === 'static'); }

    get hasStandardFields()  { return this.standardFields.length > 0; }
    get hasCustomFields()    { return this.customFields.length > 0; }
    get hasHiddenFields()    { return this.hiddenFields.length > 0; }
    get hasTrackingFields()  { return this.trackingFields.length > 0; }
    get hasStaticFields()    { return this.staticFields.length > 0; }

    get standardCount()  { return this.standardFields.length; }
    get customCount()    { return this.customFields.length; }
    get hiddenCount()    { return this.hiddenFields.length; }
    get trackingCount()  { return this.trackingFields.length; }
    get staticCount()    { return this.staticFields.length; }

    // ─── Preview panel ───────────────────────────────────────────────
    get mappedPreview() {
        return this.allMappings
            .filter(m => m.sfField)
            .map(m => ({ sfField: m.sfField, sampleValue: m.sampleValue, label: m.label }));
    }
    get hasMappedFields() { return this.mappedPreview.length > 0; }

    // ─── Step & nav helpers ──────────────────────────────────────────
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get stepClass1() { return this.currentStep >= 1 ? 'step-item step-active' : 'step-item'; }
    get stepClass2() { return this.currentStep >= 2 ? 'step-item step-active' : 'step-item'; }
    get stepClass3() { return this.currentStep >= 3 ? 'step-item step-active' : 'step-item'; }

    get noPageSelected()  { return !this.selectedPageId; }
    get noFormSelected()  { return !this.selectedFormId; }
    get noFormsFound()    { return this.formSearchTerm && this.forms.length === 0; }
    get saveLabel()       { return this.isSaving ? 'Saving...' : 'Save Mapping'; }
}
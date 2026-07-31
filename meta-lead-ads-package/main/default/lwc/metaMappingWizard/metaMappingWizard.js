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
import validateMappingLimit   from '@salesforce/apex/MetaMappingService.validateMappingLimit';
import getMappings            from '@salesforce/apex/MetaMappingService.getMappings';
import LightningConfirm       from 'lightning/confirm';

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
    @track isDirty          = false;
    @track selectedCopySourceId = '';
    // Map of fieldApiName → 'PICKLIST' | 'TEXT' (populated from getLeadFields)
    sfFieldTypeMap          = {};
    @track sfFieldOptions   = []; // Initialize to prevent map() crashes
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
        this.isLoadingForms = true;
        try {
            await validateMappingLimit({ formId: this.selectedFormId });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Limit Reached',
                message: e.body ? e.body.message : 'License limit reached.',
                variant: 'error'
            }));
            this.isLoadingForms = false;
            return;
        }
        this.isLoadingForms = false;

        this.currentStep = 3;
        // Wait for BOTH lead fields AND form fields to load together
        // so sfFieldOptions is populated before the comboboxes try to render their selected values
        await Promise.all([
            this.loadLeadFields(),
            this.loadFieldsAndMappings()
        ]);
        this.updateDropdownOptions();
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
                isStatic:      f.facebookField && f.facebookField.startsWith('STATIC::'),
                options:       []
            }));
            this.isDirty = false;

        } catch (e) {
            this.errorMessage = e.body ? e.body.message : 'Failed to load form fields.';
        } finally {
            this.isLoadingFields = false;
        }
    }

    // ─── Load Salesforce Lead field options (for all dropdowns) ──────
    async loadLeadFields() {
        if (this.sfFieldOptions && this.sfFieldOptions.length > 1) {
            return; // Already loaded
        }
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
            this.sfFieldOptions = [];
            this.errorMessage = e.body ? e.body.message : 'Failed to load Salesforce Lead fields.';
        }
    }

    // ─── Helper to match Salesforce Lead field API names flexibly ──────────
    resolveSfField(targetField) {
        if (!targetField) return '';
        const targetLower = targetField.toLowerCase();
        const targetNoNs = targetLower.replace(/^purpl__/, '');
        
        let match = this.sfFieldOptions.find(opt => {
            if (!opt.value) return false;
            const valLower = opt.value.toLowerCase();
            const valNoNs = valLower.replace(/^purpl__/, '');
            return valLower === targetLower || valNoNs === targetNoNs;
        });
        
        if (match) return match.value;

        // Fallback matching for tracking parameters if explicit target field is not present in org
        if (targetLower.includes('source')) {
            match = this.sfFieldOptions.find(opt => 
                opt.value && (opt.value.toLowerCase().includes('lead_source') || opt.value.toLowerCase().includes('leadsource'))
            );
        } else if (targetLower.includes('campaign') || targetLower.includes('project')) {
            match = this.sfFieldOptions.find(opt => 
                opt.value && (opt.value.toLowerCase().includes('project') || opt.value.toLowerCase().includes('description'))
            );
        } else if (targetLower.includes('utm') || targetLower.includes('medium') || targetLower.includes('term') || targetLower.includes('content')) {
            match = this.sfFieldOptions.find(opt => 
                opt.value && opt.value.toLowerCase().includes('description')
            );
        }

        return match ? match.value : '';
    }

    updateDropdownOptions() {
        if (!this.sfFieldOptions || !this.allMappings) return;
        this.allMappings = this.allMappings.map(row => {
            const availableOptions = this.sfFieldOptions.map(opt => {
                if (!opt.value) return opt; // keep -- None --
                const isTaken = this.allMappings.some(otherRow => otherRow.id !== row.id && otherRow.sfField === opt.value);
                return {
                    ...opt,
                    disabled: isTaken
                };
            });
            return { ...row, options: availableOptions };
        });
    }

    handleMappingChange(event) {
        const rowId  = event.currentTarget.dataset.id;
        const sfField = event.detail.value;
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, sfField } : row
        );
        this.updateDropdownOptions();
        this.isDirty = true;
    }

    // ─── Handle Static Value Text Input ──
    handleStaticValueChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const val = event.target.value;
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, facebookField: 'STATIC::' + val, sampleValue: val } : row
        );
        this.isDirty = true;
    }

    // ─── When SF field changes on a static row — detect picklist and load values ──
    async handleStaticSfFieldChange(event) {
        const rowId   = event.currentTarget.dataset.id;
        const sfField = event.detail.value;
        // First update the sfField
        this.allMappings = this.allMappings.map(row =>
            row.id === rowId ? { ...row, sfField, sampleValue: '', isPicklistMode: false, picklistOptions: [] } : row
        );
        this.updateDropdownOptions();
        this.isDirty = true;
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
        this.isDirty = true;
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
            isPicklist:    false,
            options:       []
        }];
        this.updateDropdownOptions();
        this.isDirty = true;
    }

    // ─── Duplicate SF Field Prevention ──────────────────────────────────────────
    updateDropdownOptions() {
        this.allMappings = this.allMappings.map(row => {
            return { ...row, options: this.sfFieldOptions };
        });
    }

    // ─── Helper to match Salesforce Lead field API names flexibly ──────────
    resolveSfField(targetField) {
        if (!targetField) return '';
        const targetLower = targetField.toLowerCase();
        const targetNoNs = targetLower.replace(/^purpl__/, '');
        
        let match = this.sfFieldOptions.find(opt => {
            if (!opt.value) return false;
            const valLower = opt.value.toLowerCase();
            const valNoNs = valLower.replace(/^purpl__/, '');
            return valLower === targetLower || valNoNs === targetNoNs;
        });
        
        if (match) return match.value;

        return targetField;
    }

    // ─── Copy Mapping ────────────────────────────────────────────────────────
    handleCopySourceChange(event) {
        this.selectedCopySourceId = event.detail.value;
    }

    async handleCopyMapping() {
        if (!this.selectedCopySourceId) return;
        
        const message = this.isDirty 
            ? 'You have unsaved changes. Copying will overwrite your current mappings. Are you sure you want to proceed?'
            : 'Are you sure you want to copy mappings from the selected form? This will overwrite your current mappings.';
            
        const result = await LightningConfirm.open({
            message: message,
            variant: 'headerless',
            label: 'Copy Mapping Confirmation'
        });
        
        if (!result) return;
        
        try {
            const mappings = await getMappings({ formId: this.selectedCopySourceId });
            
            const copyMapLower = {};
            const staticMappings = [];
            (mappings || []).forEach(m => {
                if (m.Facebook_Field && m.Salesforce_Field) {
                    if (m.Facebook_Field.startsWith('STATIC::')) {
                        staticMappings.push(m);
                    } else {
                        copyMapLower[m.Facebook_Field.toLowerCase()] = m.Salesforce_Field;
                    }
                }
            });
            
            let copiedCount = 0;
            let invalidCount = 0;
            
            let updatedMappings = this.allMappings.map(row => {
                if (row.isStatic) return { ...row, sfField: '' };
                
                const rawTargetSfField = copyMapLower[(row.facebookField || '').toLowerCase()];
                
                if (rawTargetSfField) {
                    const resolvedSfField = this.resolveSfField(rawTargetSfField);
                    
                    if (resolvedSfField) {
                        copiedCount++;
                        return { ...row, sfField: resolvedSfField };
                    } else {
                        invalidCount++;
                        return { ...row, sfField: '' };
                    }
                }
                
                return { ...row, sfField: '' };
            });

            // Handle static mappings from source form
            staticMappings.forEach(m => {
                const resolvedSfField = this.resolveSfField(m.Salesforce_Field);
                if (!resolvedSfField) {
                    invalidCount++;
                    return;
                }
                
                const staticVal = m.Facebook_Field.substring(8);
                const existingIndex = updatedMappings.findIndex(r => r.facebookField === m.Facebook_Field);
                
                if (existingIndex >= 0) {
                    copiedCount++;
                    updatedMappings[existingIndex] = {
                        ...updatedMappings[existingIndex],
                        sfField: resolvedSfField
                    };
                } else {
                    copiedCount++;
                    updatedMappings.push({
                        id:            'static_copy_' + Date.now() + Math.random().toString(36).substring(2, 6),
                        facebookField: m.Facebook_Field,
                        label:         'Static Text',
                        category:      'static',
                        sfField:       resolvedSfField,
                        isUtm:         false,
                        sampleValue:   staticVal,
                        isStatic:      true,
                        isPicklist:    false,
                        options:       []
                    });
                }
            });
            
            this.allMappings = updatedMappings;
            this.updateDropdownOptions();
            this.isDirty = true;
            
            this.selectedCopySourceId = '';
            const copyCombo = this.template.querySelector('c-meta-searchable-combobox[name="copyMapping"]');
            if (copyCombo) copyCombo.value = '';
            
            let msg = `${copiedCount} mappings copied successfully.`;
            if (invalidCount > 0) msg += ` ${invalidCount} invalid fields ignored.`;
            
            this.dispatchEvent(new ShowToastEvent({
                title:   'Mapping Copied',
                message: msg,
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Copy Failed',
                message: e.body ? e.body.message : e.message,
                variant: 'error'
            }));
        }
    }

    // ─── Save mappings ────────────────────────────────────────────────
    async handleSaveMapping() {
        this.isSaving = true;
        this.errorMessage = '';
        try {
            const mappingsJson = JSON.stringify(this.allMappings);
            await saveMappings({ formId: this.selectedFormId, mappingsJson });
            this.isDirty = false;
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
    
    get standardMappedCount()  { return this.standardFields.filter(m => m.sfField).length; }
    get customMappedCount()    { return this.customFields.filter(m => m.sfField).length; }
    get hiddenMappedCount()    { return this.hiddenFields.filter(m => m.sfField).length; }
    get trackingMappedCount()  { return this.trackingFields.filter(m => m.sfField).length; }
    get staticMappedCount()    { return this.staticFields.filter(m => m.sfField).length; }

    get mappedFormOptions() {
        return this.allForms
            .filter(f => f.Is_Mapped && f.Form_ID !== this.selectedFormId)
            .map(f => ({ label: f.Form_Name, value: f.Form_ID }));
    }
    
    get hasMappedForms() {
        return this.mappedFormOptions.length > 0;
    }

    get noMappedForms() {
        return !this.hasMappedForms;
    }
    
    get noCopySourceSelected() {
        return !this.selectedCopySourceId;
    }

    // ─── Preview panel ───────────────────────────────────────────────
    get mappedPreview() {
        return this.allMappings
            .filter(m => m.sfField)
            .map(m => {
                const sfOpt = this.sfFieldOptions.find(opt => opt.value === m.sfField);
                let cleanLabel = m.sfField;
                if (sfOpt) {
                    cleanLabel = sfOpt.label.split(' (')[0];
                }
                return { sfField: m.sfField, sfLabel: cleanLabel, sampleValue: m.sampleValue, label: m.label };
            });
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
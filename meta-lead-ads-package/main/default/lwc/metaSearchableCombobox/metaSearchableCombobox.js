import { LightningElement, api, track } from 'lwc';

export default class MetaSearchableCombobox extends LightningElement {
    @api name;
    @api label;
    @api placeholder = 'Select Form...';
    @api disabled = false;
    @api takenValues = [];
    
    // Internal state
    @track _options = [];
    @track _value = '';
    
    @api
    get options() {
        return this._options;
    }
    set options(val) {
        this._options = val || [];
        this.updateDisplayLabel();
    }
    
    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val;
        this.updateDisplayLabel();
    }
    
    @track isOpen = false;
    @track searchTerm = '';
    @track displayLabel = '';
    
    get inputValue() {
        return this.isOpen ? this.searchTerm : this.displayLabel;
    }
    
    connectedCallback() {
        this.updateDisplayLabel();
    }
    
    get filteredOptions() {
        const term = this.searchTerm.toLowerCase();
        
        let filtered = this._options;
        if (term) {
            filtered = this._options.filter(opt => {
                const labelMatch = opt.label && opt.label.toLowerCase().includes(term);
                const valueMatch = opt.value && opt.value.toLowerCase().includes(term);
                return labelMatch || valueMatch;
            });
        }
        let finalOptions = filtered;
        // Limit to 100 items for immediate rendering, but ensure selected value is present
        if (filtered.length > 100) {
            const result = [];
            const noneOpt = filtered.find(opt => !opt.value);
            const selectedOpt = this._value ? filtered.find(opt => opt.value === this._value) : null;
            
            if (noneOpt) result.push(noneOpt);
            if (selectedOpt) result.push(selectedOpt);
            
            for (let i = 0; i < filtered.length && result.length < 100; i++) {
                if (filtered[i] !== noneOpt && filtered[i] !== selectedOpt) {
                    result.push(filtered[i]);
                }
            }
            finalOptions = result;
        }
        
        return finalOptions.map(opt => {
            if (!opt.value) return { ...opt, className: 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small option-row' };
            const isTaken = this.takenValues && this.takenValues.includes(opt.value) && this._value !== opt.value;
            const className = `slds-media slds-listbox__option slds-listbox__option_plain slds-media_small option-row ${isTaken ? 'disabled-option' : ''}`;
            return { ...opt, disabled: isTaken, className };
        });
    }
    
    get noOptionsFound() {
        return this.filteredOptions.length === 0;
    }
    
    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isOpen ? 'slds-is-open' : ''}`;
    }
    
    updateDisplayLabel() {
        if (!this._value) {
            this.displayLabel = '';
        } else {
            const selectedOpt = this._options.find(opt => opt.value === this._value);
            this.displayLabel = selectedOpt ? selectedOpt.label : this._value;
        }
    }
    
    handleFocus() {
        this.isOpen = true;
        this.searchTerm = '';
    }
    
    handleBlur() {
        setTimeout(() => {
            this.isOpen = false;
            this.searchTerm = '';
            this.updateDisplayLabel();
        }, 200);
    }
    
    handleInput(event) {
        this.searchTerm = event.target.value;
        this.isOpen = true;
    }
    
    handleSelect(event) {
        const isDisabled = event.currentTarget.dataset.disabled === 'true';
        if (isDisabled) return;
        
        const selectedValue = event.currentTarget.dataset.value;
        this._value = selectedValue;
        this.updateDisplayLabel();
        this.isOpen = false;
        
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: selectedValue, name: this.name }
        }));
    }
    
    handleClear(event) {
        event.stopPropagation();
        this._value = '';
        this.searchTerm = '';
        this.updateDisplayLabel();
        this.isOpen = false;
        
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: '', name: this.name }
        }));
    }
    
    get showClearIcon() {
        return !!this._value && !this.isOpen;
    }
    
    get showSearchIcon() {
        return !this.showClearIcon;
    }
}

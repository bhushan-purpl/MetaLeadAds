/**
 * MetaMappingService.cls
 * Fully dynamic metadata-driven mapping engine.
 * - getFormFieldsForMapping() is the master method: returns every field for a form,
 *   pre-categorized and merged with existing saved mappings.
 * - Auto-mapping uses synonym scoring instead of exact-key lookup.
 * - Zero hardcoded field lists in LWC — Apex is the single source of truth.
 */
public without sharing class MetaMappingService {

    // ─── Synonym Auto-Map Engine ─────────────────────────────────────────────
    private static final Map<String, List<String>> SF_SYNONYMS = new Map<String, List<String>>{
        'Email'            => new List<String>{'email','e-mail','emailaddress','work_email','personal_email'},
        'Phone'            => new List<String>{'phone','phone_number','mobile','contact','telephone','tel'},
        'MobilePhone'      => new List<String>{'mobile','cell','cellphone','work_phone','mobile_number','work_phone_number'},
        'FirstName'        => new List<String>{'first_name','firstname','given_name','fname'},
        'LastName'         => new List<String>{'last_name','lastname','surname','family_name','lname'},
        'Name'             => new List<String>{'full_name','fullname','name','complete_name'},
        'Company'          => new List<String>{'company','company_name','organization','organisation','employer','business'},
        'City'             => new List<String>{'city','town','location','locality'},
        'State'            => new List<String>{'state','province','region','state_name'},
        'PostalCode'       => new List<String>{'zip','zip_code','postal','postal_code','pincode','pin'},
        'Country'          => new List<String>{'country','nation','country_name'},
        'Street'           => new List<String>{'street','address','street_address','street1'},
        'LeadSource'       => new List<String>{'lead_source','leadsource','source','utm_source'},
        'Description'      => new List<String>{'message','note','notes','comments','description','remark','query'},
        'Website'          => new List<String>{'website','url','web','site'},
        'Title'            => new List<String>{'title','job_title','designation','position','role'},
        'Industry'         => new List<String>{'industry','sector','business_type','vertical'},
        'NumberOfEmployees'=> new List<String>{'employees','team_size','company_size','headcount'},
        'AnnualRevenue'    => new List<String>{'revenue','annual_revenue','turnover','budget','annual_budget'},
        'purpl__utm_source__c'   => new List<String>{'utm_source'},
        'purpl__utm_medium__c'   => new List<String>{'utm_medium'},
        'purpl__utm_campaign__c' => new List<String>{'utm_campaign','campaign_name'},
        'purpl__utm_term__c'     => new List<String>{'utm_term','keyword'},
        'purpl__utm_content__c'  => new List<String>{'utm_content','ad_name'}
    };

    // Tracking parameters that Meta injects at lead delivery time (not form questions)
    private static final List<Map<String,String>> TRACKING_PARAMS = new List<Map<String,String>>{
        new Map<String,String>{'key'=>'utm_source',    'label'=>'UTM Source',        'sample'=>'facebook'},
        new Map<String,String>{'key'=>'utm_medium',    'label'=>'UTM Medium',        'sample'=>'cpc'},
        new Map<String,String>{'key'=>'utm_campaign',  'label'=>'UTM Campaign',      'sample'=>'summer_2024'},
        new Map<String,String>{'key'=>'utm_term',      'label'=>'UTM Term',          'sample'=>'real estate'},
        new Map<String,String>{'key'=>'utm_content',   'label'=>'UTM Content',       'sample'=>'ad_variant_a'},
        new Map<String,String>{'key'=>'utm_adgroup',   'label'=>'UTM Ad Group',      'sample'=>'adgroup_1'},
        new Map<String,String>{'key'=>'campaign_id',   'label'=>'Campaign ID',       'sample'=>'23847123456789'},
        new Map<String,String>{'key'=>'campaign_name', 'label'=>'Campaign Name',     'sample'=>'Q3 Awareness'},
        new Map<String,String>{'key'=>'ad_id',         'label'=>'Ad ID',             'sample'=>'23847987654321'},
        new Map<String,String>{'key'=>'ad_name',       'label'=>'Ad Name',           'sample'=>'Carousel - Tower A'},
        new Map<String,String>{'key'=>'adset_id',      'label'=>'Ad Set ID',         'sample'=>'23847111111111'},
        new Map<String,String>{'key'=>'adset_name',    'label'=>'Ad Set Name',       'sample'=>'Mumbai - 25-45'},
        new Map<String,String>{'key'=>'page_id',       'label'=>'Facebook Page ID',  'sample'=>'112345678901234'},
        new Map<String,String>{'key'=>'form_id',       'label'=>'Lead Form ID',      'sample'=>'223456789012345'},
        new Map<String,String>{'key'=>'leadgen_id',    'label'=>'Lead ID (Meta)',     'sample'=>'334567890123456'},
        new Map<String,String>{'key'=>'fbclid',        'label'=>'Facebook Click ID', 'sample'=>'IwAR3xyzABC'},
        new Map<String,String>{'key'=>'gclid',         'label'=>'Google Click ID',   'sample'=>'CjwKCAjw'},
        new Map<String,String>{'key'=>'created_time',  'label'=>'Lead Created Time', 'sample'=>'2024-06-25T10:30:00+0000'},
        new Map<String,String>{'key'=>'is_organic',    'label'=>'Is Organic',        'sample'=>'false'},
        new Map<String,String>{'key'=>'platform',      'label'=>'Platform',          'sample'=>'fb'},
        new Map<String,String>{'key'=>'partner_name',  'label'=>'Partner Name',      'sample'=>'zapier'},
        new Map<String,String>{'key'=>'retailer_item_id','label'=>'Retailer Item ID','sample'=>'item123'},
        new Map<String,String>{'key'=>'vehicle',       'label'=>'Vehicle',           'sample'=>'vehicle123'},
        new Map<String,String>{'key'=>'home_listing',  'label'=>'Home Listing',      'sample'=>'home123'}
    };

    // ─── MASTER METHOD — called by LWC on Step 3 load ────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getFormFieldsForMapping(String formId, String pageId) {

        // Load existing saved mappings
        Map<String, String> existingMap = new Map<String, String>();
        try {
            for (Meta_Field_Mapping__c m : [
                SELECT Facebook_Field__c, Salesforce_Field__c
                FROM Meta_Field_Mapping__c
                WHERE Form_ID__c = :formId AND Active__c = true
            ]) {
                existingMap.put(m.Facebook_Field__c, m.Salesforce_Field__c);
            }
        } catch (Exception e) { /* object may not exist yet */ }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        Set<String> trackingKeysAdded = new Set<String>();

        // Load form questions from DB
        List<Meta_Form__c> forms = [
            SELECT Questions_JSON__c FROM Meta_Form__c WHERE Form_ID__c = :formId LIMIT 1
        ];

        if (!forms.isEmpty() && String.isNotBlank(forms[0].Questions_JSON__c)) {
            List<Object> questions = (List<Object>) JSON.deserializeUntyped(forms[0].Questions_JSON__c);
            if (questions != null) {
                for (Object q : questions) {
                    Map<String, Object> qMap = (Map<String, Object>) q;
                    String key      = String.valueOf(qMap.get('key'));
                    String rawLabel = qMap.containsKey('label') ? String.valueOf(qMap.get('label')) : key;
                    String rawType  = qMap.containsKey('type')  ? String.valueOf(qMap.get('type')).toUpperCase() : 'TEXT';

                    String category = 'standard';
                    if (rawType == 'CUSTOM' || rawType == 'CUSTOM_QUESTION') {
                        category = 'custom';
                    } else if (rawType == 'HIDDEN') {
                        category = 'hidden';
                    }

                    if (isTrackingKey(key)) {
                        category = 'tracking';
                        trackingKeysAdded.add(key.toLowerCase());
                    }

                    result.add(buildRow(key, rawLabel, category, existingMap.get(key)));
                }
            }
        }

        // Always inject all tracking parameters
        for (Map<String, String> tp : TRACKING_PARAMS) {
            String key = tp.get('key');
            if (!trackingKeysAdded.contains(key.toLowerCase())) {
                Map<String, Object> row = buildRow(key, tp.get('label'), 'tracking', existingMap.get(key));
                row.put('sampleValue', tp.get('sample'));
                result.add(row);
            }
        }

        // Restore any saved static mappings
        for (String existingKey : existingMap.keySet()) {
            if (existingKey.startsWithIgnoreCase('STATIC::')) {
                String staticValue = existingKey.substring(8);
                Map<String, Object> row = buildRow(existingKey, 'Static Value', 'static', existingMap.get(existingKey));
                row.put('sampleValue', staticValue);
                result.add(row);
            }
        }

        return result;
    }

    // ─── AUTO-MAP with synonym scoring ───────────────────────────────────────
    @AuraEnabled
    public static List<Map<String, Object>> getAutoSuggestions(String formId, String pageId) {
        List<Map<String, Object>> allFields = getFormFieldsForMapping(formId, pageId);
        for (Map<String, Object> row : allFields) {
            String fbKey   = (String) row.get('facebookField');
            String fbLabel = (String) row.get('label');
            String bestSf  = findBestSfField(fbKey, fbLabel);
            if (String.isNotBlank(bestSf)) {
                row.put('sfField', bestSf);
            }
        }
        return allFields;
    }

    // ─── Save mappings ────────────────────────────────────────────────────────
    @AuraEnabled
    public static String saveMappings(String formId, String mappingsJson) {
        try {
            List<Object> mappingData = (List<Object>) JSON.deserializeUntyped(mappingsJson);

            List<Meta_Field_Mapping__c> existing = [SELECT Id FROM Meta_Field_Mapping__c WHERE Form_ID__c = :formId];
            if (!existing.isEmpty()) delete existing;

            List<Meta_Form__c> forms = [SELECT Id FROM Meta_Form__c WHERE Form_ID__c = :formId LIMIT 1];
            Id formRecId = forms.isEmpty() ? null : forms[0].Id;

            List<Meta_Field_Mapping__c> toInsert = new List<Meta_Field_Mapping__c>();
            for (Object obj : mappingData) {
                Map<String, Object> m = (Map<String, Object>) obj;
                String sfField = (String) m.get('sfField');
                if (String.isBlank(sfField)) continue;

                Meta_Field_Mapping__c mapping = new Meta_Field_Mapping__c();
                mapping.Form__c              = formRecId;
                mapping.Form_ID__c           = formId;
                mapping.Facebook_Field__c    = (String) m.get('facebookField');
                mapping.Salesforce_Field__c  = sfField;
                mapping.Salesforce_Object__c = 'Lead';
                mapping.Is_UTM__c            = (String) m.get('category') == 'tracking';
                mapping.Active__c            = true;
                toInsert.add(mapping);
            }

            if (!toInsert.isEmpty()) insert toInsert;
            if (formRecId != null) {
                update new Meta_Form__c(Id = formRecId, Is_Mapped__c = true);
            }
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException('Save failed: ' + e.getMessage());
        }
    }

    // ─── Get existing mappings ────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Meta_Field_Mapping__c> getMappings(String formId) {
        return [
            SELECT Id, Form_ID__c, Facebook_Field__c, Salesforce_Field__c,
                   Salesforce_Object__c, Is_UTM__c, Active__c
            FROM Meta_Field_Mapping__c
            WHERE Form_ID__c = :formId AND Active__c = true
            ORDER BY Is_UTM__c ASC, Facebook_Field__c ASC
        ];
    }

    // ─── Get all Salesforce Lead fields for dropdown ──────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLeadFields() {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();
        List<String> sortedLabels = new List<String>();
        Map<String, Map<String, String>> labelToField = new Map<String, Map<String, String>>();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (!dfr.isAccessible() || dfr.isDeprecatedAndHidden()) continue;
            Schema.DisplayType dtype = dfr.getType();
            if (dtype == Schema.DisplayType.ADDRESS ||
                dtype == Schema.DisplayType.REFERENCE ||
                fieldName == 'id') continue;

            String lbl = dfr.getLabel() + ' (' + dfr.getName() + ')';
            String fieldType = (dtype == Schema.DisplayType.PICKLIST || dtype == Schema.DisplayType.MULTIPICKLIST)
                               ? 'PICKLIST' : 'TEXT';
            Map<String, String> field = new Map<String, String>{
                'value'     => dfr.getName(),
                'label'     => lbl,
                'type'      => String.valueOf(dtype),
                'fieldType' => fieldType
            };
            sortedLabels.add(lbl);
            labelToField.put(lbl, field);
        }

        sortedLabels.sort();
        for (String lbl : sortedLabels) {
            fieldList.add(labelToField.get(lbl));
        }
        return fieldList;
    }

    // ─── Get picklist values for a specific Lead field ────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String fieldApiName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        options.add(new Map<String, String>{ 'label' => '-- Select Value --', 'value' => '' });
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();
            if (!fieldMap.containsKey(fieldApiName.toLowerCase())) return options;
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName.toLowerCase()).getDescribe();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                if (pe.isActive()) {
                    options.add(new Map<String, String>{
                        'label' => pe.getLabel(),
                        'value' => pe.getValue()
                    });
                }
            }
        } catch (Exception e) {
            System.debug('getPicklistValues error: ' + e.getMessage());
        }
        return options;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    private static Map<String, Object> buildRow(String key, String label, String category, String savedSfField) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('facebookField', key);
        row.put('label',         String.isNotBlank(label) ? label : key);
        row.put('category',      category);
        row.put('isUtm',         key != null && key.toLowerCase().startsWith('utm_'));
        row.put('sfField',       String.isNotBlank(savedSfField) ? savedSfField : '');
        row.put('sampleValue',   generateSampleValue(key, category));
        return row;
    }

    private static String generateSampleValue(String key, String category) {
        if (key == null) return '';
        String k = key.toLowerCase();
        if (k.contains('email'))    return 'john@example.com';
        if (k.contains('phone') || k.contains('mobile')) return '+91 98765 43210';
        if (k == 'full_name')       return 'John Doe';
        if (k == 'first_name')      return 'John';
        if (k == 'last_name')       return 'Doe';
        if (k.contains('company'))  return 'Acme Corp';
        if (k.contains('city'))     return 'Mumbai';
        if (k.contains('state'))    return 'Maharashtra';
        if (k.contains('zip') || k.contains('postal') || k.contains('pin')) return '400001';
        if (k.contains('country'))  return 'India';
        if (k.contains('street') || k.contains('address')) return '123 Main Street';
        if (k.contains('website') || k.contains('url')) return 'https://example.com';
        if (k.contains('budget'))   return '50-75 Lakhs';
        if (k.contains('project'))  return 'Tower A - Premium';
        if (k == 'utm_source')      return 'facebook';
        if (k == 'utm_medium')      return 'cpc';
        if (k == 'utm_campaign')    return 'summer_2024';
        if (k == 'utm_term')        return 'real estate';
        if (k == 'utm_content')     return 'carousel_v1';
        if (k == 'campaign_id')     return '23847123456789';
        if (k == 'ad_id')           return '23847987654321';
        if (k == 'adset_id')        return '23847111111111';
        if (k.contains('_id'))      return '100000000000001';
        if (k.contains('_name'))    return 'Sample Name';
        if (k == 'fbclid')          return 'IwAR3xyzABC';
        if (k == 'gclid')           return 'CjwKCAjw';
        if (k == 'created_time')    return '2024-06-25T10:30:00+0000';
        if (category == 'hidden')   return '(Pre-filled value)';
        if (category == 'custom')   return 'Custom answer here';
        return 'sample_' + k;
    }

    private static Boolean isTrackingKey(String key) {
        if (key == null) return false;
        Set<String> trackingKeys = new Set<String>{
            'utm_source','utm_medium','utm_campaign','utm_term','utm_content','utm_adgroup',
            'campaign_id','campaign_name','ad_id','ad_name','adset_id','adset_name',
            'page_id','form_id','leadgen_id','fbclid','gclid','created_time'
        };
        return trackingKeys.contains(key.toLowerCase());
    }

    private static String findBestSfField(String fbKey, String fbLabel) {
        if (String.isBlank(fbKey)) return '';
        String k = fbKey.toLowerCase().replaceAll('[^a-z0-9]', '');
        String l = String.isNotBlank(fbLabel) ? fbLabel.toLowerCase().replaceAll('[^a-z0-9 ]', '') : '';

        String bestField = '';
        Integer bestScore = 0;

        for (String sfField : SF_SYNONYMS.keySet()) {
            for (String synonym : SF_SYNONYMS.get(sfField)) {
                String syn = synonym.toLowerCase().replaceAll('[^a-z0-9]', '');
                Integer score = 0;
                if (k == syn) {
                    score = 100;
                } else if (k.contains(syn) || syn.contains(k)) {
                    score = 70;
                } else if (String.isNotBlank(l) && l.contains(syn)) {
                    score = 50;
                }
                if (score > bestScore) {
                    bestScore = score;
                    bestField = sfField;
                }
            }
        }

        return bestScore >= 50 ? bestField : '';
    }
}
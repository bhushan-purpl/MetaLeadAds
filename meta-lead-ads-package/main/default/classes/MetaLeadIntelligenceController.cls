/**
 * MetaLeadIntelligenceController
 *
 * Controller for the Lead Intelligence Dashboard LWC (metaLeadIntelligence).
 * Provides complete read-only analytics, KPI metrics, conversion funnel,
 * multi-dimensional performance tables, validation failures, webhook health,
 * datatable pagination, and lead lifecycle timeline.
 */
public with sharing class MetaLeadIntelligenceController {

    public class FilterWrapper {
        public String dateRange;
        public String startDate;
        public String endDate;
        public String project;
        public String status;
        public String ownerId;
        public String campaign;
        public String pageId;
        public String formId;
        public String searchKey;
        public String kpiFilter;
    }

    public class KpiItem {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public String icon;
        @AuraEnabled public String trend; // e.g. "+12%" or "Stable"
        @AuraEnabled public String variant; // e.g. "success", "warning", "error", "info"

        public KpiItem(String key, String label, Integer count, Decimal percentage, String icon, String trend, String variant) {
            this.key = key;
            this.label = label;
            this.count = count;
            this.percentage = percentage != null ? percentage.setScale(1) : 0;
            this.icon = icon;
            this.trend = trend;
            this.variant = variant;
        }
    }

    public class FunnelStage {
        @AuraEnabled public String stage;
        @AuraEnabled public Integer count;
        @AuraEnabled public Decimal conversionPct;
        @AuraEnabled public Decimal dropOffPct;

        public FunnelStage(String stage, Integer count, Decimal conversionPct, Decimal dropOffPct) {
            this.stage = stage;
            this.count = count;
            this.conversionPct = conversionPct != null ? conversionPct.setScale(1) : 0;
            this.dropOffPct = dropOffPct != null ? dropOffPct.setScale(1) : 0;
        }
    }

    public class PerformanceRow {
        @AuraEnabled public String name;
        @AuraEnabled public Integer totalLeads;
        @AuraEnabled public Integer workingLeads;
        @AuraEnabled public Integer qualifiedLeads;
        @AuraEnabled public Integer opportunities;
        @AuraEnabled public Integer wonLeads;
        @AuraEnabled public Decimal conversionRate;
        @AuraEnabled public Decimal revenue;

        public PerformanceRow(String name) {
            this.name = String.isNotBlank(name) ? name : 'Unassigned / N/A';
            this.totalLeads = 0;
            this.workingLeads = 0;
            this.qualifiedLeads = 0;
            this.opportunities = 0;
            this.wonLeads = 0;
            this.conversionRate = 0;
            this.revenue = 0;
        }

        public void calculateRates() {
            if (this.totalLeads > 0) {
                this.conversionRate = ((Decimal) this.wonLeads / (Decimal) this.totalLeads * 100).setScale(1);
            }
        }
    }

    public class FormPerformanceRow {
        @AuraEnabled public String formName;
        @AuraEnabled public Integer leadsReceived;
        @AuraEnabled public Integer duplicates;
        @AuraEnabled public Integer qualified;
        @AuraEnabled public Integer converted;

        public FormPerformanceRow(String formName) {
            this.formName = String.isNotBlank(formName) ? formName : 'Unknown Form';
            this.leadsReceived = 0;
            this.duplicates = 0;
            this.qualified = 0;
            this.converted = 0;
        }
    }

    public class LeadRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String project;
        @AuraEnabled public String campaign;
        @AuraEnabled public String facebookPage;
        @AuraEnabled public String leadForm;
        @AuraEnabled public String status;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdDateFormatted;
        @AuraEnabled public Boolean isConverted;
    }

    public class ValidationFailure {
        @AuraEnabled public String id;
        @AuraEnabled public String metaLeadId;
        @AuraEnabled public String formId;
        @AuraEnabled public String pageId;
        @AuraEnabled public String errorType; // e.g. "Validation Rule Failed", "Required Field Missing", "Duplicate Lead", "Assignment Failed"
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Datetime createdDate;
    }

    public class WebhookHealthInfo {
        @AuraEnabled public String status; // "Green", "Yellow", "Red"
        @AuraEnabled public String statusLabel; // "Healthy", "Warning", "Critical"
        @AuraEnabled public Integer activePages;
        @AuraEnabled public Datetime lastLeadReceived;
        @AuraEnabled public Datetime lastWebhookReceived;
        @AuraEnabled public Datetime lastSyncTime;
        @AuraEnabled public Integer failedLogCount;
    }

    public class TimelineEvent {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String description;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public String icon;
        @AuraEnabled public String statusClass;

        public TimelineEvent(String title, String subtitle, String description, Datetime timestamp, String icon, String statusClass) {
            this.title = title;
            this.subtitle = subtitle;
            this.description = description;
            this.timestamp = timestamp;
            this.icon = icon;
            this.statusClass = statusClass;
        }
    }

    public class FilterOptions {
        @AuraEnabled public List<Map<String, String>> projects = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> statuses = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> owners = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> campaigns = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> pages = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> forms = new List<Map<String, String>>();
    }

    public class DashboardDataWrapper {
        @AuraEnabled public Map<String, KpiItem> kpiStats = new Map<String, KpiItem>();
        @AuraEnabled public List<KpiItem> kpiList = new List<KpiItem>();
        @AuraEnabled public List<FunnelStage> funnelStages = new List<FunnelStage>();
        @AuraEnabled public List<PerformanceRow> campaignPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<PerformanceRow> projectPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<PerformanceRow> pagePerformance = new List<PerformanceRow>();
        @AuraEnabled public List<FormPerformanceRow> formPerformance = new List<FormPerformanceRow>();
        @AuraEnabled public List<PerformanceRow> ownerPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<Map<String, Object>> statusDistribution = new List<Map<String, Object>>();
        @AuraEnabled public List<LeadRow> leads = new List<LeadRow>();
        @AuraEnabled public List<ValidationFailure> validationFailures = new List<ValidationFailure>();
        @AuraEnabled public WebhookHealthInfo webhookHealth = new WebhookHealthInfo();
        @AuraEnabled public FilterOptions filterOptions = new FilterOptions();
    }

    // ── Main Dashboard Data Endpoint ──
    @AuraEnabled(cacheable=true)
    public static DashboardDataWrapper getDashboardData(String filterJson) {
        FilterWrapper filters = new FilterWrapper();
        if (String.isNotBlank(filterJson)) {
            try {
                filters = (FilterWrapper) JSON.deserialize(filterJson, FilterWrapper.class);
            } catch (Exception e) {}
        }

        DashboardDataWrapper wrapper = new DashboardDataWrapper();
        
        // 1. Build Date Filters
        Datetime startDt = null;
        Datetime endDt = null;
        Date today = Date.today();

        if (String.isNotBlank(filters.dateRange)) {
            if (filters.dateRange == 'Today') {
                startDt = Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0));
                endDt = Datetime.newInstance(today, Time.newInstance(23, 59, 59, 999));
            } else if (filters.dateRange == 'This Week') {
                Date startOfWeek = today.toStartOfWeek();
                startDt = Datetime.newInstance(startOfWeek, Time.newInstance(0, 0, 0, 0));
                endDt = Datetime.newInstance(today.addDays(7), Time.newInstance(23, 59, 59, 999));
            } else if (filters.dateRange == 'This Month') {
                Date startOfMonth = today.toStartOfMonth();
                startDt = Datetime.newInstance(startOfMonth, Time.newInstance(0, 0, 0, 0));
                endDt = Datetime.newInstance(startOfMonth.addMonths(1).addDays(-1), Time.newInstance(23, 59, 59, 999));
            } else if (filters.dateRange == 'This Quarter') {
                Integer currentMonth = today.month();
                Integer quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1;
                Date startOfQuarter = Date.newInstance(today.year(), quarterStartMonth, 1);
                startDt = Datetime.newInstance(startOfQuarter, Time.newInstance(0, 0, 0, 0));
                endDt = Datetime.newInstance(startOfQuarter.addMonths(3).addDays(-1), Time.newInstance(23, 59, 59, 999));
            } else if (filters.dateRange == 'Custom' && String.isNotBlank(filters.startDate) && String.isNotBlank(filters.endDate)) {
                try {
                    startDt = Datetime.newInstance(Date.valueOf(filters.startDate), Time.newInstance(0, 0, 0, 0));
                    endDt = Datetime.newInstance(Date.valueOf(filters.endDate), Time.newInstance(23, 59, 59, 999));
                } catch (Exception ex) {}
            }
        }

        // 2. Fetch Lead Records
        String leadQuery = 'SELECT Id, FirstName, LastName, Name, Email, Phone, MobilePhone, Company, Status, OwnerId, Owner.Name, CreatedDate, IsConverted, ConvertedOpportunityId, ConvertedOpportunity.Name, ConvertedOpportunity.StageName, ConvertedOpportunity.Amount';
        
        // Dynamic custom fields check
        Map<String, Schema.SObjectField> leadFieldsMap = Schema.SObjectType.Lead.fields.getMap();
        Boolean hasIntegrationSource = leadFieldsMap.containsKey('purpl__integration_source__c') || leadFieldsMap.containsKey('integration_source__c');
        Boolean hasProject = leadFieldsMap.containsKey('purpl__project_interested__c') || leadFieldsMap.containsKey('project_interested__c');
        Boolean hasForm1 = leadFieldsMap.containsKey('purpl__meta_form_1__c') || leadFieldsMap.containsKey('meta_form_1__c');
        Boolean hasForm2 = leadFieldsMap.containsKey('purpl__meta_form_2__c') || leadFieldsMap.containsKey('meta_form_2__c');
        Boolean hasUtmSource = leadFieldsMap.containsKey('purpl__utm_source__c') || leadFieldsMap.containsKey('utm_source__c');
        Boolean hasUtmCampaign = leadFieldsMap.containsKey('purpl__utm_campaign__c') || leadFieldsMap.containsKey('utm_campaign__c');

        if (hasIntegrationSource) leadQuery += leadFieldsMap.containsKey('purpl__integration_source__c') ? ', purpl__Integration_Source__c' : ', Integration_Source__c';
        if (hasProject) leadQuery += leadFieldsMap.containsKey('purpl__project_interested__c') ? ', purpl__Project_Interested__c' : ', Project_Interested__c';
        if (hasForm1) leadQuery += leadFieldsMap.containsKey('purpl__meta_form_1__c') ? ', purpl__Meta_Form_1__c' : ', Meta_Form_1__c';
        if (hasForm2) leadQuery += leadFieldsMap.containsKey('purpl__meta_form_2__c') ? ', purpl__Meta_Form_2__c' : ', Meta_Form_2__c';
        if (hasUtmCampaign) leadQuery += leadFieldsMap.containsKey('purpl__utm_campaign__c') ? ', purpl__UTM_Campaign__c' : ', UTM_Campaign__c';

        leadQuery += ' FROM Lead WHERE Id != null';

        // Filter by Backend Integration Source or LeadSource or Form if field present
        if (hasIntegrationSource) {
            String integrationField = leadFieldsMap.containsKey('purpl__integration_source__c') ? 'purpl__Integration_Source__c' : 'Integration_Source__c';
            leadQuery += ' AND (' + integrationField + ' = \'Meta Lead Ads\' OR LeadSource = \'Meta Lead Ads\'';
            if (hasForm1) {
                String form1Field = leadFieldsMap.containsKey('purpl__meta_form_1__c') ? 'purpl__Meta_Form_1__c' : 'Meta_Form_1__c';
                leadQuery += ' OR ' + form1Field + ' != null';
            }
            leadQuery += ')';
        }

        if (startDt != null && endDt != null) {
            leadQuery += ' AND CreatedDate >= :startDt AND CreatedDate <= :endDt';
        }

        if (String.isNotBlank(filters.status)) {
            String statusVal = filters.status;
            leadQuery += ' AND Status = :statusVal';
        }

        if (String.isNotBlank(filters.ownerId)) {
            String ownerVal = filters.ownerId;
            leadQuery += ' AND OwnerId = :ownerVal';
        }

        leadQuery += ' ORDER BY CreatedDate DESC LIMIT 5000';

        List<Lead> rawLeads = Database.query(leadQuery);

        // Fetch Meta Pages and Meta Forms for mapping lookup
        Map<String, String> formIdToNameMap = new Map<String, String>();
        Map<String, String> pageIdToNameMap = new Map<String, String>();

        for (Meta_Form__c mf : [SELECT Form_ID__c, Form_Name__c, Page_ID__c FROM Meta_Form__c]) {
            if (String.isNotBlank(mf.Form_ID__c)) {
                formIdToNameMap.put(mf.Form_ID__c, mf.Form_Name__c);
            }
        }
        for (Meta_Page__c mp : [SELECT Page_ID__c, Page_Name__c FROM Meta_Page__c]) {
            if (String.isNotBlank(mp.Page_ID__c)) {
                pageIdToNameMap.put(mp.Page_ID__c, mp.Page_Name__c);
            }
        }

        // Fetch Meta Lead Logs to map Validation Failures, Duplicates, and Webhook Health
        List<Meta_Lead_Log__c> logs = [
            SELECT Id, Meta_Lead_ID__c, Page_ID__c, Form_ID__c, Processing_Status__c, Error_Message__c, Salesforce_Lead_ID__c, CreatedDate
            FROM Meta_Lead_Log__c
            ORDER BY CreatedDate DESC LIMIT 2000
        ];

        Map<String, Meta_Lead_Log__c> leadIdToLogMap = new Map<String, Meta_Lead_Log__c>();
        Integer duplicateCount = 0;
        Integer validationFailedCount = 0;

        for (Meta_Lead_Log__c log : logs) {
            if (String.isNotBlank(log.Salesforce_Lead_ID__c)) {
                String sfId = log.Salesforce_Lead_ID__c.trim();
                leadIdToLogMap.put(sfId, log);
                if (sfId.length() >= 15) {
                    leadIdToLogMap.put(sfId.substring(0, 15), log);
                }
            }
            if (log.Processing_Status__c == 'Failed') {
                validationFailedCount++;
                if (log.Error_Message__c != null && log.Error_Message__c.toLowerCase().contains('duplicate')) {
                    duplicateCount++;
                }
            }
        }

        // Aggregate Metrics & Build Wrappers
        Integer totalMetaLeads = 0;
        Integer newLeadsCount = 0;
        Integer assignedCount = 0;
        Integer openCount = 0;
        Integer workingCount = 0;
        Integer qualifiedCount = 0;
        Integer siteVisitCount = 0;
        Integer oppCreatedCount = 0;
        Integer convertedCount = 0;
        Integer closedWonCount = 0;
        Integer closedLostCount = 0;

        Map<String, PerformanceRow> campaignMap = new Map<String, PerformanceRow>();
        Map<String, PerformanceRow> projectMap = new Map<String, PerformanceRow>();
        Map<String, PerformanceRow> pageMap = new Map<String, PerformanceRow>();
        Map<String, FormPerformanceRow> formMap = new Map<String, FormPerformanceRow>();
        Map<String, PerformanceRow> ownerMap = new Map<String, PerformanceRow>();
        Map<String, Integer> statusCounts = new Map<String, Integer>();

        Set<String> projectSet = new Set<String>();
        Set<String> statusSet = new Set<String>();
        Map<String, String> ownerOptionsMap = new Map<String, String>();
        Set<String> campaignSet = new Set<String>();

        for (Lead l : rawLeads) {
            String st = l.Status != null ? l.Status : 'Open';
            String ownerName = l.Owner != null ? l.Owner.Name : 'Unassigned';

            // Collect filter options from all records
            statusSet.add(st);
            if (l.OwnerId != null) ownerOptionsMap.put(l.OwnerId, ownerName);

            // Project Interested field extraction
            String projName = 'General Enquiry';
            if (hasProject) {
                String pVal = (String) l.get(leadFieldsMap.containsKey('purpl__project_interested__c') ? 'purpl__Project_Interested__c' : 'Project_Interested__c');
                if (String.isNotBlank(pVal)) projName = pVal;
            }
            projectSet.add(projName);

            // Campaign extraction
            String campName = 'Organic / Direct Meta';
            if (hasUtmCampaign) {
                String cVal = (String) l.get(leadFieldsMap.containsKey('purpl__utm_campaign__c') ? 'purpl__UTM_Campaign__c' : 'UTM_Campaign__c');
                if (String.isNotBlank(cVal)) campName = cVal;
            }
            campaignSet.add(campName);

            // Form & Page extraction from Log or Lead
            String formId = '';
            if (hasForm1) {
                String fVal = (String) l.get(leadFieldsMap.containsKey('purpl__meta_form_1__c') ? 'purpl__Meta_Form_1__c' : 'Meta_Form_1__c');
                if (String.isNotBlank(fVal)) formId = fVal;
            }
            String sLeadId = String.valueOf(l.Id);
            Meta_Lead_Log__c logRec = leadIdToLogMap.get(sLeadId);
            if (logRec == null && sLeadId.length() >= 15) {
                logRec = leadIdToLogMap.get(sLeadId.substring(0, 15));
            }

            if (logRec != null && String.isNotBlank(logRec.Form_ID__c)) formId = logRec.Form_ID__c;

            String formName = formIdToNameMap.containsKey(formId) ? formIdToNameMap.get(formId) : (String.isNotBlank(formId) ? 'Form ' + formId : 'Meta Lead Form');
            String pageId = logRec != null ? logRec.Page_ID__c : '';
            String pageName = pageIdToNameMap.containsKey(pageId) ? pageIdToNameMap.get(pageId) : (String.isNotBlank(pageId) ? 'Page ' + pageId : 'Facebook Business Page');

            // ── APPLY ALL FILTERS BEFORE METRICS AGGREGATION ──
            if (String.isNotBlank(filters.project) && projName != filters.project) continue;
            if (String.isNotBlank(filters.status) && st != filters.status) continue;
            if (String.isNotBlank(filters.pageId) && pageId != filters.pageId && pageName != filters.pageId) continue;
            if (String.isNotBlank(filters.formId) && formId != filters.formId && formName != filters.formId) continue;
            if (String.isNotBlank(filters.campaign) && campName != filters.campaign) continue;
            if (String.isNotBlank(filters.searchKey)) {
                String sk = filters.searchKey.toLowerCase();
                Boolean nameMatch = l.Name != null && l.Name.toLowerCase().contains(sk);
                Boolean emailMatch = l.Email != null && l.Email.toLowerCase().contains(sk);
                Boolean phoneMatch = l.Phone != null && l.Phone.toLowerCase().contains(sk);
                if (!nameMatch && !emailMatch && !phoneMatch) continue;
            }
            if (String.isNotBlank(filters.kpiFilter)) {
                String kf = filters.kpiFilter;
                if (kf == 'Duplicate') {
                    if (logRec == null || logRec.Processing_Status__c != 'Failed' || logRec.Error_Message__c == null || !logRec.Error_Message__c.toLowerCase().contains('duplicate')) continue;
                } else if (kf == 'Failed') {
                    if (logRec == null || logRec.Processing_Status__c != 'Failed') continue;
                } else if (kf == 'Opportunity') {
                    Boolean hasOpp = l.IsConverted || l.ConvertedOpportunityId != null;
                    if (!hasOpp) continue;
                } else if (kf == 'Converted') {
                    if (!l.IsConverted) continue;
                } else if (kf.startsWith('Status:')) {
                    String targetStatus = kf.substringAfter('Status:');
                    if (st != targetStatus) continue;
                } else if (kf != 'Total' && st != kf) {
                    continue;
                }
            }

            // ── RECORD PASSED ALL FILTERS: ACCUMULATE METRICS ──
            totalMetaLeads++;
            statusCounts.put(st, statusCounts.containsKey(st) ? statusCounts.get(st) + 1 : 1);

            // Status counts
            if (st == 'New' || st == 'Uncontacted') newLeadsCount++;
            if (l.OwnerId != null) assignedCount++;
            if (st == 'Open' || st == 'New') openCount++;
            if (st == 'Working' || st == 'Contacted' || st == 'In Progress') workingCount++;
            if (st == 'Qualified' || st == 'Interested') qualifiedCount++;
            if (st == 'Site Visit' || st == 'Site Visit Done' || st == 'Meeting Scheduled') siteVisitCount++;
            
            Boolean hasOpp = l.IsConverted || l.ConvertedOpportunityId != null;
            if (hasOpp) oppCreatedCount++;
            if (l.IsConverted) convertedCount++;

            if (l.IsConverted && l.ConvertedOpportunity != null && l.ConvertedOpportunity.StageName != null) {
                String stage = l.ConvertedOpportunity.StageName;
                if (stage.contains('Closed Won') || stage.contains('Won')) closedWonCount++;
                if (stage.contains('Closed Lost') || stage.contains('Lost')) closedLostCount++;
            } else if (st.contains('Won') || st.contains('Converted')) {
                closedWonCount++;
            } else if (st.contains('Lost') || st.contains('Unqualified')) {
                closedLostCount++;
            }

            // Build Performance Rows
            // Campaign Performance
            if (!campaignMap.containsKey(campName)) campaignMap.put(campName, new PerformanceRow(campName));
            PerformanceRow cRow = campaignMap.get(campName);
            cRow.totalLeads++;
            if (st == 'Qualified' || st == 'Interested') cRow.qualifiedLeads++;
            if (hasOpp) cRow.opportunities++;
            if (l.IsConverted) cRow.wonLeads++;

            // Project Performance
            if (!projectMap.containsKey(projName)) projectMap.put(projName, new PerformanceRow(projName));
            PerformanceRow pRow = projectMap.get(projName);
            pRow.totalLeads++;
            if (st == 'Qualified' || st == 'Interested') pRow.qualifiedLeads++;
            if (l.IsConverted) {
                pRow.wonLeads++;
                if (l.ConvertedOpportunity != null && l.ConvertedOpportunity.Amount != null) {
                    pRow.revenue += l.ConvertedOpportunity.Amount;
                }
            }

            // Facebook Page Performance
            if (!pageMap.containsKey(pageName)) pageMap.put(pageName, new PerformanceRow(pageName));
            PerformanceRow pgRow = pageMap.get(pageName);
            pgRow.totalLeads++;
            if (st == 'Qualified' || st == 'Interested') pgRow.qualifiedLeads++;
            if (l.IsConverted) pgRow.wonLeads++;

            // Lead Form Performance
            if (!formMap.containsKey(formName)) formMap.put(formName, new FormPerformanceRow(formName));
            FormPerformanceRow fRow = formMap.get(formName);
            fRow.leadsReceived++;
            if (st == 'Qualified' || st == 'Interested') fRow.qualified++;
            if (l.IsConverted) fRow.converted++;

            // Owner Performance
            if (!ownerMap.containsKey(ownerName)) ownerMap.put(ownerName, new PerformanceRow(ownerName));
            PerformanceRow oRow = ownerMap.get(ownerName);
            oRow.totalLeads++;
            if (st == 'Working' || st == 'In Progress') oRow.workingLeads++;
            if (st == 'Qualified' || st == 'Interested') oRow.qualifiedLeads++;
            if (l.IsConverted) oRow.wonLeads++;

            // Lead Grid Row
            LeadRow r = new LeadRow();
            r.id = l.Id;
            r.name = l.Name;
            r.mobile = maskPhone(String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone);
            r.email = maskEmail(l.Email);
            r.project = projName;
            r.campaign = campName;
            r.facebookPage = pageName;
            r.leadForm = formName;
            r.status = st;
            r.ownerName = ownerName;
            r.opportunityName = l.ConvertedOpportunity != null ? l.ConvertedOpportunity.Name : '';
            r.createdDate = l.CreatedDate;
            r.createdDateFormatted = l.CreatedDate.format('dd-MMM-yyyy hh:mm a');
            r.isConverted = l.IsConverted;
            wrapper.leads.add(r);
        }

        // Calculate rates for performance rows
        for (PerformanceRow r : campaignMap.values()) r.calculateRates();
        for (PerformanceRow r : projectMap.values()) r.calculateRates();
        for (PerformanceRow r : pageMap.values()) r.calculateRates();
        for (PerformanceRow r : ownerMap.values()) r.calculateRates();

        wrapper.campaignPerformance = campaignMap.values();
        wrapper.projectPerformance = projectMap.values();
        wrapper.pagePerformance = pageMap.values();
        wrapper.formPerformance = formMap.values();
        wrapper.ownerPerformance = ownerMap.values();

        // 3. Build KPI Items Dynamically from Actual Lead Status Picklist Values
        Decimal totalBase = totalMetaLeads > 0 ? (Decimal) totalMetaLeads : 1;

        Map<String, KpiItem> kpis = new Map<String, KpiItem>();
        kpis.put('Total', new KpiItem('Total', 'Total Meta Leads', totalMetaLeads, 100.0, 'utility:lead', 'Total', 'brand'));

        if (duplicateCount > 0) {
            kpis.put('Duplicate', new KpiItem('Duplicate', 'Duplicate Leads', duplicateCount, ((Decimal)duplicateCount / totalBase * 100).setScale(1), 'utility:copy', 'Log', 'warning'));
        }
        if (validationFailedCount > 0) {
            kpis.put('Failed', new KpiItem('Failed', 'Validation Failed', validationFailedCount, ((Decimal)validationFailedCount / totalBase * 100).setScale(1), 'utility:error', 'Log', 'error'));
        }

        // Fetch actual Lead Status picklist entries from Schema
        List<Schema.PicklistEntry> statusEntries = Schema.SObjectType.Lead.fields.Status.getPicklistValues();
        String[] statusIcons = new String[]{'utility:new', 'utility:clock', 'utility:like', 'utility:check', 'utility:close', 'utility:open_folder', 'utility:location'};
        String[] statusVariants = new String[]{'info', 'warning', 'success', 'brand', 'error', 'info', 'success'};
        Integer sIdx = 0;

        for (Schema.PicklistEntry entry : statusEntries) {
            if (entry.isActive()) {
                String sValue = entry.getValue();
                String sLabel = entry.getLabel();
                Integer cnt = statusCounts.containsKey(sValue) ? statusCounts.get(sValue) : 0;
                Decimal pct = ((Decimal) cnt / totalBase * 100).setScale(1);

                String icon = statusIcons[Math.mod(sIdx, statusIcons.size())];
                String variant = statusVariants[Math.mod(sIdx, statusVariants.size())];

                kpis.put('Status:' + sValue, new KpiItem('Status:' + sValue, sLabel, cnt, pct, icon, 'Status', variant));
                sIdx++;
            }
        }

        // Add Opportunity & Converted Metrics KPI Cards
        kpis.put('Opportunity', new KpiItem('Opportunity', 'Opportunity Created', oppCreatedCount, ((Decimal)oppCreatedCount / totalBase * 100).setScale(1), 'utility:opportunity', 'Pipeline', 'brand'));
        if (convertedCount > 0) {
            kpis.put('Converted', new KpiItem('Converted', 'Converted Leads', convertedCount, ((Decimal)convertedCount / totalBase * 100).setScale(1), 'utility:check', 'Converted', 'success'));
        }

        wrapper.kpiStats = kpis;
        wrapper.kpiList = kpis.values();

        // 4. Build Conversion Funnel
        wrapper.funnelStages.add(new FunnelStage('Meta Lead Received', totalMetaLeads, 100.0, 0.0));
        wrapper.funnelStages.add(new FunnelStage('Lead Created', totalMetaLeads - validationFailedCount, ((Decimal)(totalMetaLeads - validationFailedCount)/totalBase)*100, ((Decimal)validationFailedCount/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Assigned', assignedCount, ((Decimal)assignedCount/totalBase)*100, ((Decimal)(totalMetaLeads - assignedCount)/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Working', workingCount, ((Decimal)workingCount/totalBase)*100, ((Decimal)(assignedCount - workingCount)/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Qualified', qualifiedCount, ((Decimal)qualifiedCount/totalBase)*100, ((Decimal)(workingCount - qualifiedCount)/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Site Visit', siteVisitCount, ((Decimal)siteVisitCount/totalBase)*100, ((Decimal)(qualifiedCount - siteVisitCount)/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Opportunity Created', oppCreatedCount, ((Decimal)oppCreatedCount/totalBase)*100, ((Decimal)(siteVisitCount - oppCreatedCount)/totalBase)*100));
        wrapper.funnelStages.add(new FunnelStage('Closed Won', closedWonCount, ((Decimal)closedWonCount/totalBase)*100, ((Decimal)(oppCreatedCount - closedWonCount)/totalBase)*100));

        // 5. Build Status Distribution for Charts
        String[] colors = new String[]{'#3b82f6', '#f59e0b', '#10b981', '#8b5cf6', '#06b6d4', '#059669', '#ef4444'};
        Integer cIdx = 0;
        for (String sKey : statusCounts.keySet()) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('label', sKey);
            m.put('value', statusCounts.get(sKey));
            m.put('color', colors[Math.mod(cIdx, colors.size())]);
            wrapper.statusDistribution.add(m);
            cIdx++;
        }

        // 6. Build Validation Failures Widget Data
        for (Meta_Lead_Log__c log : logs) {
            if (log.Processing_Status__c == 'Failed') {
                ValidationFailure vf = new ValidationFailure();
                vf.id = log.Id;
                vf.metaLeadId = log.Meta_Lead_ID__c;
                vf.formId = log.Form_ID__c;
                vf.pageId = log.Page_ID__c;
                vf.errorMessage = String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c : 'Validation Failed';
                if (vf.errorMessage.toLowerCase().contains('duplicate')) vf.errorType = 'Duplicate Lead';
                else if (vf.errorMessage.toLowerCase().contains('required')) vf.errorType = 'Required Field Missing';
                else if (vf.errorMessage.toLowerCase().contains('assignment')) vf.errorType = 'Assignment Failed';
                else vf.errorType = 'Validation Rule Failed';
                vf.createdDate = log.CreatedDate;
                wrapper.validationFailures.add(vf);
                if (wrapper.validationFailures.size() >= 20) break;
            }
        }

        // 7. Webhook Health Status
        List<Meta_Page__c> activePages = [SELECT Id FROM Meta_Page__c WHERE Active__c = true];
        wrapper.webhookHealth.activePages = activePages.size();
        wrapper.webhookHealth.failedLogCount = validationFailedCount;
        wrapper.webhookHealth.lastSyncTime = Datetime.now();
        if (!logs.isEmpty()) {
            wrapper.webhookHealth.lastLeadReceived = logs[0].CreatedDate;
            wrapper.webhookHealth.lastWebhookReceived = logs[0].CreatedDate;
        }

        if (validationFailedCount == 0 && activePages.size() > 0) {
            wrapper.webhookHealth.status = 'Green';
            wrapper.webhookHealth.statusLabel = 'Healthy & Operational';
        } else if (validationFailedCount > 0 && validationFailedCount < 10) {
            wrapper.webhookHealth.status = 'Yellow';
            wrapper.webhookHealth.statusLabel = 'Minor Issues Detected';
        } else {
            wrapper.webhookHealth.status = 'Red';
            wrapper.webhookHealth.statusLabel = 'Attention Required';
        }

        // 8. Populate Filter Picklist Options
        for (String p : projectSet) {
            if (String.isNotBlank(p)) wrapper.filterOptions.projects.add(new Map<String, String>{'label' => p, 'value' => p});
        }
        for (String st : statusSet) {
            if (String.isNotBlank(st)) wrapper.filterOptions.statuses.add(new Map<String, String>{'label' => st, 'value' => st});
        }
        for (String oId : ownerOptionsMap.keySet()) {
            wrapper.filterOptions.owners.add(new Map<String, String>{'label' => ownerOptionsMap.get(oId), 'value' => oId});
        }
        for (String c : campaignSet) {
            if (String.isNotBlank(c)) wrapper.filterOptions.campaigns.add(new Map<String, String>{'label' => c, 'value' => c});
        }
        for (String pId : pageIdToNameMap.keySet()) {
            wrapper.filterOptions.pages.add(new Map<String, String>{'label' => pageIdToNameMap.get(pId), 'value' => pId});
        }
        for (String fId : formIdToNameMap.keySet()) {
            wrapper.filterOptions.forms.add(new Map<String, String>{'label' => formIdToNameMap.get(fId), 'value' => fId});
        }

        return wrapper;
    }

    // ── Get Lead Timeline Lifecycle Events ──
    @AuraEnabled(cacheable=true)
    public static List<TimelineEvent> getLeadTimeline(Id leadId) {
        List<TimelineEvent> timeline = new List<TimelineEvent>();
        if (leadId == null) return timeline;

        List<Lead> leads = [
            SELECT Id, Name, Status, Owner.Name, CreatedDate, IsConverted, ConvertedOpportunityId, ConvertedOpportunity.Name, ConvertedOpportunity.StageName, ConvertedDate
            FROM Lead WHERE Id = :leadId LIMIT 1
        ];

        if (leads.isEmpty()) return timeline;
        Lead l = leads[0];

        // 1. Meta Lead Received & Webhook Event
        timeline.add(new TimelineEvent(
            'Meta Lead Received',
            'Facebook Webhook Callback Received',
            'Lead payload captured from Meta Graph API webhook.',
            l.CreatedDate.addSeconds(-5),
            'utility:call',
            'timeline-item-brand'
        ));

        // 2. Lead Created
        timeline.add(new TimelineEvent(
            'Lead Created',
            'Salesforce Record Generated',
            'Lead record created with name ' + l.Name,
            l.CreatedDate,
            'utility:lead',
            'timeline-item-info'
        ));

        // 3. Lead Assigned
        if (l.Owner != null) {
            timeline.add(new TimelineEvent(
                'Assigned to ' + l.Owner.Name,
                'Owner Assignment Completed',
                'Lead assigned automatically based on assignment rules.',
                l.CreatedDate.addMinutes(1),
                'utility:user',
                'timeline-item-success'
            ));
        }

        // 4. Status Stage Timeline
        timeline.add(new TimelineEvent(
            'Status: ' + l.Status,
            'Current Lead Status',
            'Lead status updated to ' + l.Status,
            l.CreatedDate.addMinutes(10),
            'utility:clock',
            'timeline-item-warning'
        ));

        // 5. Opportunity Conversion
        if (l.IsConverted) {
            timeline.add(new TimelineEvent(
                'Opportunity Created: ' + (l.ConvertedOpportunity != null ? l.ConvertedOpportunity.Name : 'Converted'),
                'Lead Converted to Opportunity',
                'Opportunity created with stage ' + (l.ConvertedOpportunity != null ? l.ConvertedOpportunity.StageName : 'Prospecting'),
                l.ConvertedDate != null ? Datetime.newInstance(l.ConvertedDate, Time.newInstance(12, 0, 0, 0)) : l.CreatedDate.addDays(1),
                'utility:opportunity',
                'timeline-item-brand'
            ));
        }

        return timeline;
    }

    // ── Export Filtered Leads to CSV ──
    @AuraEnabled
    public static String exportLeadsCsv(String filterJson) {
        DashboardDataWrapper data = getDashboardData(filterJson);
        String csv = 'Lead Name,Mobile,Email,Project Interested,Campaign,Facebook Page,Lead Form,Current Status,Current Owner,Opportunity,Created Date\n';
        for (LeadRow r : data.leads) {
            csv += '"' + safeCsv(r.name) + '","'
                 + safeCsv(r.mobile) + '","'
                 + safeCsv(r.email) + '","'
                 + safeCsv(r.project) + '","'
                 + safeCsv(r.campaign) + '","'
                 + safeCsv(r.facebookPage) + '","'
                 + safeCsv(r.leadForm) + '","'
                 + safeCsv(r.status) + '","'
                 + safeCsv(r.ownerName) + '","'
                 + safeCsv(r.opportunityName) + '","'
                 + safeCsv(r.createdDateFormatted) + '"\n';
        }
        return csv;
    }

    private static String safeCsv(String str) {
        if (String.isBlank(str)) return '';
        return str.replace('"', '""');
    }

    private static String maskPhone(String phone) {
        if (String.isBlank(phone)) return '';
        String cleaned = phone.trim();
        if (cleaned.length() <= 5) return '*****';
        Integer len = cleaned.length();
        String firstTwo = cleaned.substring(0, 2);
        String lastThree = cleaned.substring(len - 3);
        return firstTwo + '*****' + lastThree;
    }

    private static String maskEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) return '****';
        String[] parts = email.split('@');
        String localPart = parts[0];
        String domain = parts.size() > 1 ? parts[1] : '';
        if (localPart.length() <= 2) {
            return localPart.substring(0, 1) + '***@' + domain;
        }
        String firstChar = localPart.substring(0, 1);
        String lastChar = localPart.substring(localPart.length() - 1);
        return firstChar + '****' + lastChar + '@' + domain;
    }
}

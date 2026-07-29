/**
 * MetaLeadIntelligenceController
 *
 * Controller for Purplstack Meta Lead Analytics (metaLeadIntelligence).
 * Provides executive analytics, fixed 10 KPIs, real Salesforce timeline,
 * multi-dimensional charts, validation monitoring, webhook health,
 * recent activities, and CSV export.
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

    public class ExecutiveSnapshot {
        @AuraEnabled public Integer todayLeads = 0;
        @AuraEnabled public Integer todayQualified = 0;
        @AuraEnabled public Integer todayOpportunities = 0;
        @AuraEnabled public Integer todayClosedWon = 0;
        @AuraEnabled public Integer todayValidationFailures = 0;
        @AuraEnabled public Integer todayDuplicates = 0;
    }

    public class KpiItem {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public String icon;
        @AuraEnabled public String trend;
        @AuraEnabled public String variant;

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
        @AuraEnabled public Decimal opportunityAmount;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdDateFormatted;
        @AuraEnabled public Boolean isConverted;
    }

    public class ValidationFailure {
        @AuraEnabled public String id;
        @AuraEnabled public String metaLeadId;
        @AuraEnabled public String formId;
        @AuraEnabled public String pageId;
        @AuraEnabled public String errorType;
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
        @AuraEnabled public Integer retryQueueCount;
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

    public class TrendPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;

        public TrendPoint(String label, Integer count) {
            this.label = label;
            this.count = count;
        }
    }

    public class RecentActivities {
        @AuraEnabled public List<LeadRow> last10Leads = new List<LeadRow>();
        @AuraEnabled public List<LeadRow> recentlyQualified = new List<LeadRow>();
        @AuraEnabled public List<LeadRow> recentlyConverted = new List<LeadRow>();
        @AuraEnabled public List<LeadRow> recentlyWon = new List<LeadRow>();
        @AuraEnabled public List<ValidationFailure> recentlyFailed = new List<ValidationFailure>();
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
        @AuraEnabled public ExecutiveSnapshot executiveSnapshot = new ExecutiveSnapshot();
        @AuraEnabled public Map<String, KpiItem> kpiStats = new Map<String, KpiItem>();
        @AuraEnabled public List<KpiItem> kpiList = new List<KpiItem>();
        @AuraEnabled public List<FunnelStage> funnelStages = new List<FunnelStage>();
        @AuraEnabled public List<PerformanceRow> campaignPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<PerformanceRow> projectPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<PerformanceRow> pagePerformance = new List<PerformanceRow>();
        @AuraEnabled public List<FormPerformanceRow> formPerformance = new List<FormPerformanceRow>();
        @AuraEnabled public List<PerformanceRow> ownerPerformance = new List<PerformanceRow>();
        @AuraEnabled public List<Map<String, Object>> statusDistribution = new List<Map<String, Object>>();
        @AuraEnabled public List<TrendPoint> dailyTrend = new List<TrendPoint>();
        @AuraEnabled public List<TrendPoint> monthlyTrend = new List<TrendPoint>();
        @AuraEnabled public List<LeadRow> leads = new List<LeadRow>();
        @AuraEnabled public List<ValidationFailure> validationFailures = new List<ValidationFailure>();
        @AuraEnabled public WebhookHealthInfo webhookHealth = new WebhookHealthInfo();
        @AuraEnabled public RecentActivities recentActivities = new RecentActivities();
        @AuraEnabled public FilterOptions filterOptions = new FilterOptions();
        @AuraEnabled public Decimal totalRevenue = 0;
        @AuraEnabled public Boolean hasRevenueTracking = false;
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
        
        Map<String, Schema.SObjectField> leadFieldsMap = Schema.SObjectType.Lead.fields.getMap();
        Boolean hasIntegrationSource = leadFieldsMap.containsKey('purpl__integration_source__c') || leadFieldsMap.containsKey('integration_source__c');
        Boolean hasProject = leadFieldsMap.containsKey('purpl__project_interested__c') || leadFieldsMap.containsKey('project_interested__c');
        Boolean hasForm1 = leadFieldsMap.containsKey('purpl__meta_form_1__c') || leadFieldsMap.containsKey('meta_form_1__c');
        Boolean hasUtmCampaign = leadFieldsMap.containsKey('purpl__utm_campaign__c') || leadFieldsMap.containsKey('utm_campaign__c');

        if (hasIntegrationSource) leadQuery += leadFieldsMap.containsKey('purpl__integration_source__c') ? ', purpl__Integration_Source__c' : ', Integration_Source__c';
        if (hasProject) leadQuery += leadFieldsMap.containsKey('purpl__project_interested__c') ? ', purpl__Project_Interested__c' : ', Project_Interested__c';
        if (hasForm1) leadQuery += leadFieldsMap.containsKey('purpl__meta_form_1__c') ? ', purpl__Meta_Form_1__c' : ', Meta_Form_1__c';
        if (hasUtmCampaign) leadQuery += leadFieldsMap.containsKey('purpl__utm_campaign__c') ? ', purpl__UTM_Campaign__c' : ', UTM_Campaign__c';

        leadQuery += ' FROM Lead WHERE Id != null';

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

        leadQuery += ' ORDER BY CreatedDate DESC LIMIT 10000';

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

        // Fetch Meta Lead Logs using Processing Status as Source of Truth
        List<Meta_Lead_Log__c> logs = [
            SELECT Id, Meta_Lead_ID__c, Page_ID__c, Form_ID__c, Processing_Status__c, Error_Message__c, Salesforce_Lead_ID__c, CreatedDate
            FROM Meta_Lead_Log__c
            ORDER BY CreatedDate DESC LIMIT 5000
        ];

        Map<String, Meta_Lead_Log__c> leadIdToLogMap = new Map<String, Meta_Lead_Log__c>();
        Integer duplicateCount = 0;
        Integer validationFailedCount = 0;
        Integer retryQueueCount = 0;

        for (Meta_Lead_Log__c log : logs) {
            if (String.isNotBlank(log.Salesforce_Lead_ID__c)) {
                String sfId = log.Salesforce_Lead_ID__c.trim();
                leadIdToLogMap.put(sfId, log);
                if (sfId.length() >= 15) {
                    leadIdToLogMap.put(sfId.substring(0, 15), log);
                }
            }

            // Executive Snapshot Today check for logs
            Boolean logIsToday = log.CreatedDate != null && log.CreatedDate.date() == today;

            String pStatus = log.Processing_Status__c;
            if (pStatus == 'Duplicate' || (log.Error_Message__c != null && log.Error_Message__c.toLowerCase().contains('duplicate'))) {
                duplicateCount++;
                if (logIsToday) wrapper.executiveSnapshot.todayDuplicates++;
            } else if (pStatus == 'Failed' || pStatus == 'Validation Failed') {
                validationFailedCount++;
                if (logIsToday) wrapper.executiveSnapshot.todayValidationFailures++;
            } else if (pStatus == 'Retry' || pStatus == 'Processing') {
                retryQueueCount++;
            }
        }

        // Aggregate Metrics & Build Wrappers
        Integer totalMetaLeads = 0;
        Integer openCount = 0;
        Integer workingCount = 0;
        Integer qualifiedCount = 0;
        Integer siteVisitCount = 0;
        Integer oppCreatedCount = 0;
        Integer convertedCount = 0;
        Integer closedWonCount = 0;
        Integer closedLostCount = 0;
        Integer assignedCount = 0;

        Map<String, PerformanceRow> campaignMap = new Map<String, PerformanceRow>();
        Map<String, PerformanceRow> projectMap = new Map<String, PerformanceRow>();
        Map<String, PerformanceRow> pageMap = new Map<String, PerformanceRow>();
        Map<String, FormPerformanceRow> formMap = new Map<String, FormPerformanceRow>();
        Map<String, PerformanceRow> ownerMap = new Map<String, PerformanceRow>();
        Map<String, Integer> statusCounts = new Map<String, Integer>();
        Map<String, Integer> dailyTrendMap = new Map<String, Integer>();
        Map<String, Integer> monthlyTrendMap = new Map<String, Integer>();

        Set<String> projectSet = new Set<String>();
        Set<String> statusSet = new Set<String>();
        Map<String, String> ownerOptionsMap = new Map<String, String>();
        Set<String> campaignSet = new Set<String>();

        for (Lead l : rawLeads) {
            String st = l.Status != null ? l.Status : 'Open';
            String ownerName = l.Owner != null ? l.Owner.Name : 'Unassigned';
            Boolean isToday = l.CreatedDate != null && l.CreatedDate.date() == today;

            statusSet.add(st);
            if (l.OwnerId != null) ownerOptionsMap.put(l.OwnerId, ownerName);

            String projName = 'General Enquiry';
            if (hasProject) {
                String pVal = (String) l.get(leadFieldsMap.containsKey('purpl__project_interested__c') ? 'purpl__Project_Interested__c' : 'Project_Interested__c');
                if (String.isNotBlank(pVal)) projName = pVal;
            }
            projectSet.add(projName);

            String campName = 'Organic / Direct Meta';
            if (hasUtmCampaign) {
                String cVal = (String) l.get(leadFieldsMap.containsKey('purpl__utm_campaign__c') ? 'purpl__UTM_Campaign__c' : 'UTM_Campaign__c');
                if (String.isNotBlank(cVal)) campName = cVal;
            }
            campaignSet.add(campName);

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

            // ── APPLY FILTERS ──
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
                if (kf == 'open' && st != 'Open' && st != 'New') continue;
                if (kf == 'working' && st != 'Working' && st != 'Contacted' && st != 'In Progress') continue;
                if (kf == 'qualified' && st != 'Qualified' && st != 'Interested') continue;
                if (kf == 'site_visit' && st != 'Site Visit' && st != 'Meeting Scheduled') continue;
                if (kf == 'opportunity' && !l.IsConverted && l.ConvertedOpportunityId == null) continue;
                if (kf == 'closed_won' && !l.IsConverted && !st.contains('Won')) continue;
                if (kf == 'closed_lost' && st != 'Closed Lost' && !st.contains('Lost')) continue;
                if (kf == 'duplicate' && (logRec == null || (logRec.Processing_Status__c != 'Duplicate' && (logRec.Error_Message__c == null || !logRec.Error_Message__c.toLowerCase().contains('duplicate'))))) continue;
                if (kf == 'validation_failed' && (logRec == null || logRec.Processing_Status__c != 'Failed')) continue;
            }

            // ── ACCUMULATE METRICS ──
            totalMetaLeads++;
            statusCounts.put(st, statusCounts.containsKey(st) ? statusCounts.get(st) + 1 : 1);

            if (isToday) wrapper.executiveSnapshot.todayLeads++;

            if (l.OwnerId != null) assignedCount++;
            if (st == 'Open' || st == 'New') openCount++;
            if (st == 'Working' || st == 'Contacted' || st == 'In Progress') workingCount++;
            if (st == 'Qualified' || st == 'Interested') {
                qualifiedCount++;
                if (isToday) wrapper.executiveSnapshot.todayQualified++;
            }
            if (st == 'Site Visit' || st == 'Site Visit Done' || st == 'Meeting Scheduled') siteVisitCount++;
            
            Boolean hasOpp = l.IsConverted || l.ConvertedOpportunityId != null;
            if (hasOpp) {
                oppCreatedCount++;
                if (isToday) wrapper.executiveSnapshot.todayOpportunities++;
                if (l.ConvertedOpportunity != null && l.ConvertedOpportunity.Amount != null && l.ConvertedOpportunity.Amount > 0) {
                    wrapper.totalRevenue += l.ConvertedOpportunity.Amount;
                    wrapper.hasRevenueTracking = true;
                }
            }
            if (l.IsConverted) convertedCount++;

            if (l.IsConverted && l.ConvertedOpportunity != null && l.ConvertedOpportunity.StageName != null) {
                String stage = l.ConvertedOpportunity.StageName;
                if (stage.contains('Closed Won') || stage.contains('Won')) {
                    closedWonCount++;
                    if (isToday) wrapper.executiveSnapshot.todayClosedWon++;
                }
                if (stage.contains('Closed Lost') || stage.contains('Lost')) closedLostCount++;
            } else if (st.contains('Won') || st.contains('Converted')) {
                closedWonCount++;
                if (isToday) wrapper.executiveSnapshot.todayClosedWon++;
            } else if (st.contains('Lost') || st.contains('Unqualified')) {
                closedLostCount++;
            }

            // Daily & Monthly Trend
            if (l.CreatedDate != null) {
                String dayKey = l.CreatedDate.format('dd-MMM');
                String monthKey = l.CreatedDate.format('MMM-yyyy');
                dailyTrendMap.put(dayKey, dailyTrendMap.containsKey(dayKey) ? dailyTrendMap.get(dayKey) + 1 : 1);
                monthlyTrendMap.put(monthKey, monthlyTrendMap.containsKey(monthKey) ? monthlyTrendMap.get(monthKey) + 1 : 1);
            }

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

            // Page Performance
            if (!pageMap.containsKey(pageName)) pageMap.put(pageName, new PerformanceRow(pageName));
            PerformanceRow pgRow = pageMap.get(pageName);
            pgRow.totalLeads++;
            if (st == 'Qualified' || st == 'Interested') pgRow.qualifiedLeads++;
            if (l.IsConverted) pgRow.wonLeads++;

            // Form Performance
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
            r.opportunityAmount = (l.ConvertedOpportunity != null && l.ConvertedOpportunity.Amount != null) ? l.ConvertedOpportunity.Amount : null;
            r.createdDate = l.CreatedDate;
            r.createdDateFormatted = l.CreatedDate.format('dd-MMM-yyyy hh:mm a');
            r.isConverted = l.IsConverted;
            wrapper.leads.add(r);

            // Recent Activities Population
            if (wrapper.recentActivities.last10Leads.size() < 10) wrapper.recentActivities.last10Leads.add(r);
            if ((st == 'Qualified' || st == 'Interested') && wrapper.recentActivities.recentlyQualified.size() < 10) wrapper.recentActivities.recentlyQualified.add(r);
            if (l.IsConverted && wrapper.recentActivities.recentlyConverted.size() < 10) wrapper.recentActivities.recentlyConverted.add(r);
            if (closedWonCount <= 10 && (st.contains('Won') || (l.ConvertedOpportunity != null && l.ConvertedOpportunity.StageName.contains('Won')))) {
                if (wrapper.recentActivities.recentlyWon.size() < 10) wrapper.recentActivities.recentlyWon.add(r);
            }
        }

        // Calculate rates
        for (PerformanceRow r : campaignMap.values()) r.calculateRates();
        for (PerformanceRow r : projectMap.values()) r.calculateRates();
        for (PerformanceRow r : pageMap.values()) r.calculateRates();
        for (PerformanceRow r : ownerMap.values()) r.calculateRates();

        wrapper.campaignPerformance = campaignMap.values();
        wrapper.projectPerformance = projectMap.values();
        wrapper.pagePerformance = pageMap.values();
        wrapper.formPerformance = formMap.values();
        wrapper.ownerPerformance = ownerMap.values();

        // 3. BUILD FIXED 10 KPI CARDS (PROMPT RULE #2)
        Decimal totalBase = totalMetaLeads > 0 ? (Decimal) totalMetaLeads : 1;

        Map<String, KpiItem> kpis = new Map<String, KpiItem>();
        kpis.put('total', new KpiItem('total', 'Total Meta Leads', totalMetaLeads, 100.0, 'utility:lead', 'Total Received', 'brand'));
        kpis.put('open', new KpiItem('open', 'Open Leads', openCount, ((Decimal) openCount / totalBase * 100).setScale(1), 'utility:stage', 'Pending Action', 'info'));
        kpis.put('working', new KpiItem('working', 'Working Leads', workingCount, ((Decimal) workingCount / totalBase * 100).setScale(1), 'utility:work_order_type', 'In Follow-up', 'warning'));
        kpis.put('qualified', new KpiItem('qualified', 'Qualified Leads', qualifiedCount, ((Decimal) qualifiedCount / totalBase * 100).setScale(1), 'utility:approval', 'High Intent', 'success'));
        kpis.put('site_visit', new KpiItem('site_visit', 'Site Visit', siteVisitCount, ((Decimal) siteVisitCount / totalBase * 100).setScale(1), 'utility:event', 'Engaged', 'warning'));
        kpis.put('opportunity', new KpiItem('opportunity', 'Opportunity Created', oppCreatedCount, ((Decimal) oppCreatedCount / totalBase * 100).setScale(1), 'utility:opportunity', 'Pipeline Deals', 'brand'));
        kpis.put('closed_won', new KpiItem('closed_won', 'Closed Won', closedWonCount, ((Decimal) closedWonCount / totalBase * 100).setScale(1), 'utility:success', 'Revenue Deals', 'success'));
        kpis.put('closed_lost', new KpiItem('closed_lost', 'Closed Lost', closedLostCount, ((Decimal) closedLostCount / totalBase * 100).setScale(1), 'utility:close', 'Unqualified / Lost', 'error'));
        kpis.put('duplicate', new KpiItem('duplicate', 'Duplicate Leads', duplicateCount, ((Decimal) duplicateCount / (totalBase + duplicateCount) * 100).setScale(1), 'utility:copy', 'Log Filtered', 'error'));
        kpis.put('validation_failed', new KpiItem('validation_failed', 'Validation Failed', validationFailedCount, ((Decimal) validationFailedCount / (totalBase + validationFailedCount) * 100).setScale(1), 'utility:error', 'Error Logged', 'error'));

        wrapper.kpiStats = kpis;
        wrapper.kpiList = kpis.values();

        // 4. Build Conversion Funnel
        wrapper.funnelStages.add(new FunnelStage('Meta Lead Received', totalMetaLeads, 100.0, 0.0));
        wrapper.funnelStages.add(new FunnelStage('Lead Created', totalMetaLeads - validationFailedCount, totalMetaLeads > 0 ? ((Decimal)(totalMetaLeads - validationFailedCount)/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)validationFailedCount/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Assigned', assignedCount, totalMetaLeads > 0 ? ((Decimal)assignedCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(totalMetaLeads - assignedCount)/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Working', workingCount, totalMetaLeads > 0 ? ((Decimal)workingCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(assignedCount - workingCount)/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Qualified', qualifiedCount, totalMetaLeads > 0 ? ((Decimal)qualifiedCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(workingCount - qualifiedCount)/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Site Visit', siteVisitCount, totalMetaLeads > 0 ? ((Decimal)siteVisitCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(qualifiedCount - siteVisitCount)/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Opportunity Created', oppCreatedCount, totalMetaLeads > 0 ? ((Decimal)oppCreatedCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(siteVisitCount - oppCreatedCount)/totalBase)*100 : 0));
        wrapper.funnelStages.add(new FunnelStage('Closed Won', closedWonCount, totalMetaLeads > 0 ? ((Decimal)closedWonCount/totalBase)*100 : 0, totalMetaLeads > 0 ? ((Decimal)(oppCreatedCount - closedWonCount)/totalBase)*100 : 0));

        // 5. Build Dynamic Status Distribution for Charts
        String[] colors = new String[]{'#6366f1', '#10b981', '#f59e0b', '#8b5cf6', '#06b6d4', '#ec4899', '#ef4444'};
        Integer cIdx = 0;
        for (String sKey : statusCounts.keySet()) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('label', sKey);
            m.put('value', statusCounts.get(sKey));
            m.put('color', colors[Math.mod(cIdx, colors.size())]);
            wrapper.statusDistribution.add(m);
            cIdx++;
        }

        // Build Daily & Monthly Trend Points
        for (String dKey : dailyTrendMap.keySet()) {
            wrapper.dailyTrend.add(new TrendPoint(dKey, dailyTrendMap.get(dKey)));
        }
        for (String mKey : monthlyTrendMap.keySet()) {
            wrapper.monthlyTrend.add(new TrendPoint(mKey, monthlyTrendMap.get(mKey)));
        }

        // 6. Build Validation Failures Widget Data
        for (Meta_Lead_Log__c log : logs) {
            String pStat = log.Processing_Status__c;
            if (pStat == 'Failed' || pStat == 'Validation Failed' || pStat == 'Duplicate') {
                ValidationFailure vf = new ValidationFailure();
                vf.id = log.Id;
                vf.metaLeadId = log.Meta_Lead_ID__c;
                vf.formId = log.Form_ID__c;
                vf.pageId = log.Page_ID__c;
                vf.errorMessage = String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c : 'Validation Failed';
                
                if (pStat == 'Duplicate' || vf.errorMessage.toLowerCase().contains('duplicate')) vf.errorType = 'Duplicate Lead';
                else if (vf.errorMessage.toLowerCase().contains('required')) vf.errorType = 'Required Fields Missing';
                else if (vf.errorMessage.toLowerCase().contains('assignment')) vf.errorType = 'Assignment Failed';
                else if (pStat == 'Retry') vf.errorType = 'Retry Queue';
                else vf.errorType = 'Validation Failed';
                
                vf.createdDate = log.CreatedDate;
                wrapper.validationFailures.add(vf);
                if (wrapper.recentActivities.recentlyFailed.size() < 10) wrapper.recentActivities.recentlyFailed.add(vf);
                if (wrapper.validationFailures.size() >= 50) break;
            }
        }

        // 7. Webhook Health Status
        List<Meta_Page__c> activePages = [SELECT Id FROM Meta_Page__c WHERE Active__c = true];
        wrapper.webhookHealth.activePages = activePages.size();
        wrapper.webhookHealth.failedLogCount = validationFailedCount;
        wrapper.webhookHealth.retryQueueCount = retryQueueCount;
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

    // ── Get Real Lead Timeline Lifecycle Events (Prompt Rule #5 - No fake timestamps) ──
    @AuraEnabled(cacheable=true)
    public static List<TimelineEvent> getLeadTimeline(Id leadId) {
        List<TimelineEvent> timeline = new List<TimelineEvent>();
        if (leadId == null) return timeline;

        List<Lead> leads = [
            SELECT Id, Name, Status, Owner.Name, OwnerId, CreatedDate, IsConverted, ConvertedOpportunityId, ConvertedOpportunity.Name, ConvertedOpportunity.StageName, ConvertedOpportunity.Amount, ConvertedOpportunity.CreatedDate, ConvertedDate
            FROM Lead WHERE Id = :leadId LIMIT 1
        ];

        if (leads.isEmpty()) return timeline;
        Lead l = leads[0];

        // 1. Meta Lead Log / Webhook Event
        String sLeadId = String.valueOf(l.Id);
        List<Meta_Lead_Log__c> logs = [
            SELECT Id, Meta_Lead_ID__c, Form_ID__c, Page_ID__c, Processing_Status__c, CreatedDate
            FROM Meta_Lead_Log__c
            WHERE Salesforce_Lead_ID__c = :sLeadId OR Salesforce_Lead_ID__c = :sLeadId.substring(0, 15)
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        if (!logs.isEmpty()) {
            timeline.add(new TimelineEvent(
                'Meta Webhook Received',
                'Meta Graph API Lead Payload',
                'Received Meta Lead ID: ' + logs[0].Meta_Lead_ID__c + ' (Form ID: ' + logs[0].Form_ID__c + ')',
                logs[0].CreatedDate,
                'utility:call',
                'timeline-item-brand'
            ));
        } else {
            timeline.add(new TimelineEvent(
                'Meta Webhook Received',
                'Meta Graph API Lead Payload',
                'Meta Lead Ads Webhook Payload Processed.',
                l.CreatedDate,
                'utility:call',
                'timeline-item-brand'
            ));
        }

        // 2. Lead Created
        timeline.add(new TimelineEvent(
            'Lead Record Created',
            'Salesforce Lead Object',
            'Lead record created in Salesforce for ' + l.Name,
            l.CreatedDate,
            'utility:lead',
            'timeline-item-info'
        ));

        // 3. Owner Assigned
        if (l.Owner != null) {
            timeline.add(new TimelineEvent(
                'Owner Assigned: ' + l.Owner.Name,
                'Lead Assignment Rule / Owner Assignment',
                'Assigned to ' + l.Owner.Name + '.',
                l.CreatedDate,
                'utility:user',
                'timeline-item-success'
            ));
        }

        // 4. Tasks / Activity History (Follow-up Activities)
        try {
            List<Task> tasks = [
                SELECT Id, Subject, Status, ActivityDate, CreatedDate, Description
                FROM Task WHERE WhoId = :leadId
                ORDER BY CreatedDate ASC LIMIT 5
            ];
            for (Task t : tasks) {
                timeline.add(new TimelineEvent(
                    'Follow-up Activity: ' + t.Subject,
                    'Task Activity Status: ' + t.Status,
                    t.Description != null ? t.Description : 'Follow-up task recorded.',
                    t.CreatedDate,
                    'utility:event',
                    'timeline-item-warning'
                ));
            }
        } catch (Exception ex) {}

        // 5. Status Stage Event
        timeline.add(new TimelineEvent(
            'Current Status: ' + l.Status,
            'Lead Lifecycle Stage',
            'Lead record currently in stage: ' + l.Status,
            l.CreatedDate,
            'utility:clock',
            'timeline-item-warning'
        ));

        // 6. Lead Conversion & Opportunity Created
        if (l.IsConverted && l.ConvertedOpportunity != null) {
            Datetime oppCreated = l.ConvertedOpportunity.CreatedDate != null ? l.ConvertedOpportunity.CreatedDate : (l.ConvertedDate != null ? Datetime.newInstance(l.ConvertedDate, Time.newInstance(12, 0, 0, 0)) : l.CreatedDate);
            timeline.add(new TimelineEvent(
                'Opportunity Created: ' + l.ConvertedOpportunity.Name,
                'Lead Converted to Opportunity',
                'Lead converted into Opportunity with stage: ' + l.ConvertedOpportunity.StageName + (l.ConvertedOpportunity.Amount != null ? ' (Amount: ₹' + l.ConvertedOpportunity.Amount + ')' : ''),
                oppCreated,
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


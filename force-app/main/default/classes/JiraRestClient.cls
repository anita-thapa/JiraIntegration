/*
public class JiraRestClient {
	private static final String ENDPOINT_URL = 'https://sregmi48.atlassian.net/rest/api/3/search?jql=';
    private static final String USERNAME = 'sregmi48@gmail.com';
    private static final String PASSWORD = 'ATATT3xFfGF0cESWCagQzADqw0wh9gN6jCZemy4fXaNsHs0c9QIQVVsI-chMOgsmyQ7-4YVB2nxWSIvctuBv6aBKtd2T710qzmtS1Rs3NNR9i50f7ocJXwnxZFdW9LzZLme9KYo_tnUFgYGV1n-9Dx8pp-BASNN0tEkpgnv8CR2rdmueQc9K-tE=CC3A49B4';
    private static final String CUSTOMFIELD_START_DATE = 'customfield_10015';
    private static final String CUSTOMFIELD_PLANNED_END_DATE = 'customfield_10048';
    private static final String CUSTOMFIELD_DUE_DATE = 'duedate';
   
    @AuraEnabled()
    public static String performHttpRequestWithNamedCredential(String selectedValues) {
        System.debug(selectedValues);
        HttpResponse res;
        String responseBody = '';
        String projectData;

        // Retrieve project details
        List<Map<String, Map<String, String>>> projectMapList = GetProjectDetails.getProjectName();
        String selectedProjectAddress = getSelectedProjectAddress(projectMapList, selectedValues);

        // Perform the HTTP request with the selected project address
        if (selectedProjectAddress != null) {
            HttpRequest req = new HttpRequest();
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(USERNAME + ':' + PASSWORD));
            req.setHeader('Authorization', authHeader);
            req.setEndpoint(ENDPOINT_URL + selectedProjectAddress);
            System.debug(ENDPOINT_URL + selectedProjectAddress);
            req.setMethod('GET');

            // Create HTTP connection
            Http http = new Http();
            try {
                res = http.send(req);

                // Handle the response
                if (res.getStatusCode() == 200) {
                    // Successful request
                    System.debug('Response: ' + res.getBody());
                    responseBody = res.getBody();            
                    projectData = processIssues(responseBody);
                } else {
                    // Handle errors
                    System.debug('Error: ' + res.getStatusCode() + ' ' + res.getStatus());
                }
            } catch (Exception e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
            }
        } else {
            System.debug('Selected project not found');
        }

        return responseBody;
    }

    private static String getSelectedProjectAddress(List<Map<String, Map<String, String>>> projectMapList, String selectedValues) {
        for (Map<String, Map<String, String>> projectMap : projectMapList) {
            Map<String, String> nameAddressMapper = projectMap.get('NameAddressMapper');
            for (String address : nameAddressMapper.keySet()) {
                String projectName = nameAddressMapper.get(address);
                if (projectName.equals(selectedValues)) {
                    return address;
                }
            }
        }
        return null;
    }

    private static String processIssues(String responseBody) {
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> issuesList = (List<Object>) jsonMap.get('issues');
        List<Jira__c> jiraRecords = new List<Jira__c>();

        // Process all issues
        for (Object issueObj : issuesList) {
            Map<String, Object> issue = (Map<String, Object>) issueObj;
            Map<String, Object> fields = (Map<String, Object>) issue.get('fields');

            // Process issues
            Jira__c jiraRecord = createIssueRecord(issue, fields);
            jiraRecords.add(jiraRecord);
        }

        // Insert all records
        System.debug('Inserting Jira Records:');
        insertJiraRecords(jiraRecords);

        return 'Processed JSON';
    }

    private static void insertJiraRecords(List<Jira__c> jiraRecords) {
        if (!jiraRecords.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(jiraRecords, false);

            // Handle insertion results
            for (Database.SaveResult sr : insertResults) {
                if (sr.isSuccess()) {
                    System.debug('Successfully inserted Jira record with ID: ' + sr.getId());
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Error inserting Jira record: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }

    private static Jira__c createIssueRecord(Map<String, Object> issue, Map<String, Object> fields) {
        Jira__c jiraRecord = new Jira__c();

        // Populate fields for the issue
        jiraRecord.Name = (String) issue.get('key');
        jiraRecord.Type__c = fields != null && fields.containsKey('issuetype') ? (String) ((Map<String, Object>) fields.get('issuetype')).get('name') : null;
        jiraRecord.Summary__c = fields != null && fields.containsKey('summary') ? (String) fields.get('summary') : null;
        jiraRecord.Status__c = fields != null && fields.containsKey('status') ? (String) ((Map<String, Object>) fields.get('status')).get('name') : null;
        jiraRecord.Reporter__c = getUserByName(fields != null && fields.containsKey('reporter') ? (String) ((Map<String, Object>) fields.get('reporter')).get('displayName') : null);
        jiraRecord.Assignee__c = getUserByName(fields != null && fields.containsKey('assignee') ? (String) ((Map<String, Object>) fields.get('assignee')).get('displayName') : null);
        jiraRecord.StartDate__c = fields != null && fields.containsKey(CUSTOMFIELD_START_DATE) ? Date.valueOf((String) fields.get(CUSTOMFIELD_START_DATE)) : null;
        Integer c = fields != null && fields.containsKey('timespent') ? (Integer) fields.get('timespent') : null;
        jiraRecord.Expected_Time_Tracking__c = c != null ? convertSecondsToDHMS(c) : null;
        jiraRecord.DueDate__c = date.today();
        jiraRecord.ParentName__c =  fields != null && fields.containsKey('parent') ? (String) ((Map<String, Object>) fields.get('parent')).get('key') : null;
		Integer actualTimeInSeconds = fields != null && fields.containsKey('aggregatetimeoriginalestimate') ? (Integer) fields.get('aggregatetimeoriginalestimate') : null;
        String s = actualTimeInSeconds != null ? convertSecondsToDHMS(actualTimeInSeconds) : null;
		jiraRecord.Actual_Time_Tracking__c = s;
        
        return jiraRecord;
    }
    
    private static String convertSecondsToDHMS(Integer totalSeconds) {
        if (totalSeconds == null) {
            return null;
        }
        
        Integer days = totalSeconds / (8 * 3600);
        Integer remainder = totalSeconds - (days * 8 * 3600);
        Integer hours = remainder / 3600;
        remainder = remainder - (hours * 3600);
        Integer minutes = remainder / 60;
    
        return days + ' days ' + hours + ' hours ' + minutes + ' minutes ';
	}
    

    private static String getUserByName(String displayName) {
        if (displayName != null) {
            List<User> users = [SELECT Id FROM User WHERE Name = :displayName LIMIT 1];
            if (!users.isEmpty()) {
                return users[0].Id;
            }
        }
        return '005dL000000cKiTQAU'; // Default user ID if not found
    }
}
*/
public class JiraRestClient {
    
    public static final String ENDPOINT_URL = 'callout:JiraAuth/rest/api/3/search?jql=';
    private static final String CUSTOMFIELD_START_DATE = 'customfield_10015';
    private static final String CUSTOMFIELD_PLANNED_END_DATE = 'customfield_10048';
    private static final String CUSTOMFIELD_DUE_DATE = 'duedate';

    @AuraEnabled()
    public static String performHttpRequestWithNamedCredential(String selectedValues) {
        System.debug(selectedValues);
        HttpResponse res;
        String responseBody = '';
        String projectData;

        // Retrieve project details
        List<Map<String, Map<String, String>>> projectMapList = GetProjectDetails.getProjectName();
        String selectedProjectAddress = getSelectedProjectAddress(projectMapList, selectedValues);

        // Perform the HTTP request with the selected project address
        if (selectedProjectAddress != null) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT_URL + selectedProjectAddress);
            System.debug(ENDPOINT_URL + selectedProjectAddress);
            req.setMethod('GET');

            // Create HTTP connection
            Http http = new Http();
            try {
                res = http.send(req);

                // Handle the response
                if (res.getStatusCode() == 200) {
                    // Successful request
                    System.debug('Response: ' + res.getBody());
                    responseBody = res.getBody();
                    projectData = processIssues(responseBody);
                } else {
                    // Handle errors
                    System.debug('Error: ' + res.getStatusCode() + ' ' + res.getStatus());
                }
            } catch (Exception e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
            }
        } else {
            System.debug('Selected project not found');
        }

        return responseBody;
    }

    private static String getSelectedProjectAddress(List<Map<String, Map<String, String>>> projectMapList, String selectedValues) {
        for (Map<String, Map<String, String>> projectMap : projectMapList) {
            Map<String, String> nameAddressMapper = projectMap.get('NameAddressMapper');
            for (String address : nameAddressMapper.keySet()) {
                String projectName = nameAddressMapper.get(address);
                if (projectName.equals(selectedValues)) {
                    return address;
                }
            }
        }
        return null;
    }

    private static String processIssues(String responseBody) {
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> issuesList = (List<Object>) jsonMap.get('issues');
        List<Jira__c> jiraRecordsToUpdate = new List<Jira__c>();
        List<Jira__c> jiraRecordsToInsert = new List<Jira__c>();

        // Collect Jira keys to query existing records
        Set<String> jiraKeys = new Set<String>();
        for (Object issueObj : issuesList) {
            Map<String, Object> issue = (Map<String, Object>) issueObj;
            jiraKeys.add((String) issue.get('key'));
        }

        // Query existing Jira records
        Map<String, Jira__c> existingJiraRecords = new Map<String, Jira__c>();
        if (!jiraKeys.isEmpty()) {
            for (Jira__c existingRecord : [SELECT Id, Name, Type__c, Summary__c, Status__c, Reporter__c, Assignee__c, StartDate__c, Expected_Time_Tracking__c, DueDate__c, ParentName__c, Actual_Time_Tracking__c FROM Jira__c WHERE Name IN :jiraKeys]) {
                existingJiraRecords.put(existingRecord.Name, existingRecord);
            }
        }

        // Process all issues
        for (Object issueObj : issuesList) {
            Map<String, Object> issue = (Map<String, Object>) issueObj;
            Map<String, Object> fields = (Map<String, Object>) issue.get('fields');

            // Create new Jira record from issue
            Jira__c newJiraRecord = createIssueRecord(issue, fields);

            // Check if the record exists and has changes
            if (existingJiraRecords.containsKey(newJiraRecord.Name)) {
                Jira__c existingRecord = existingJiraRecords.get(newJiraRecord.Name);
                if (hasChanges(existingRecord, newJiraRecord)) {
                    newJiraRecord.Id = existingRecord.Id;  // Set Id to update existing record
                    jiraRecordsToUpdate.add(newJiraRecord);
                }
            } else {
                jiraRecordsToInsert.add(newJiraRecord);
            }
        }

        // Upsert records
        System.debug('Upserting Jira Records:');
        upsertJiraRecords(jiraRecordsToUpdate, jiraRecordsToInsert);

        return 'Processed JSON';
    }

    private static void upsertJiraRecords(List<Jira__c> jiraRecordsToUpdate, List<Jira__c> jiraRecordsToInsert) {
        if (!jiraRecordsToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(jiraRecordsToUpdate, false);

            // Handle update results
            for (Database.SaveResult sr : updateResults) {
                if (sr.isSuccess()) {
                    System.debug('Successfully updated Jira record with ID: ' + sr.getId());
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Error updating Jira record: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }

        if (!jiraRecordsToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(jiraRecordsToInsert, false);

            // Handle insert results
            for (Database.SaveResult sr : insertResults) {
                if (sr.isSuccess()) {
                    System.debug('Successfully inserted Jira record with ID: ' + sr.getId());
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Error inserting Jira record: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }

    private static Jira__c createIssueRecord(Map<String, Object> issue, Map<String, Object> fields) {
        Jira__c jiraRecord = new Jira__c();

        // Populate fields for the issue
        jiraRecord.Name = (String) issue.get('key');
        jiraRecord.Type__c = fields != null && fields.containsKey('issuetype') ? (String) ((Map<String, Object>) fields.get('issuetype')).get('name') : null;
        jiraRecord.Summary__c = fields != null && fields.containsKey('summary') ? (String) fields.get('summary') : null;
        jiraRecord.Status__c = fields != null && fields.containsKey('status') ? (String) ((Map<String, Object>) fields.get('status')).get('name') : null;
        jiraRecord.Reporter__c = getUserByName(fields != null && fields.containsKey('reporter') ? (String) ((Map<String, Object>) fields.get('reporter')).get('displayName') : null);
        jiraRecord.Assignee__c = getUserByName(fields != null && fields.containsKey('assignee') ? (String) ((Map<String, Object>) fields.get('assignee')).get('displayName') : null);
        jiraRecord.StartDate__c = fields != null && fields.containsKey(CUSTOMFIELD_START_DATE) ? Date.valueOf((String) fields.get(CUSTOMFIELD_START_DATE)) : null;
        Integer c = fields != null && fields.containsKey('timespent') ? (Integer) fields.get('timespent') : null;
        jiraRecord.Expected_Time_Tracking__c = c != null ? convertSecondsToDHMS(c) : null;
        jiraRecord.DueDate__c = date.today();
        jiraRecord.ParentName__c =  fields != null && fields.containsKey('parent') ? (String) ((Map<String, Object>) fields.get('parent')).get('key') : null;
		Integer actualTimeInSeconds = fields != null && fields.containsKey('aggregatetimeoriginalestimate') ? (Integer) fields.get('aggregatetimeoriginalestimate') : null;
        String s = actualTimeInSeconds != null ? convertSecondsToDHMS(actualTimeInSeconds) : null;
		jiraRecord.Actual_Time_Tracking__c = s;
        
        return jiraRecord;
    }

    private static Boolean hasChanges(Jira__c existingRecord, Jira__c newRecord) {
        return existingRecord.Type__c != newRecord.Type__c ||
               existingRecord.Summary__c != newRecord.Summary__c ||
               existingRecord.Status__c != newRecord.Status__c ||
               existingRecord.Reporter__c != newRecord.Reporter__c ||
               existingRecord.Assignee__c != newRecord.Assignee__c ||
               existingRecord.StartDate__c != newRecord.StartDate__c ||
               existingRecord.Expected_Time_Tracking__c != newRecord.Expected_Time_Tracking__c ||
               existingRecord.DueDate__c != newRecord.DueDate__c ||
               existingRecord.ParentName__c != newRecord.ParentName__c ||
               existingRecord.Actual_Time_Tracking__c != newRecord.Actual_Time_Tracking__c;
    }

    private static String convertSecondsToDHMS(Integer totalSeconds) {
        if (totalSeconds == null) {
            return null;
        }
        
        Integer days = totalSeconds / (8 * 3600);
        Integer remainder = totalSeconds - (days * 8 * 3600);
        Integer hours = remainder / 3600;
        remainder = remainder - (hours * 3600);
        Integer minutes = remainder / 60;
    
        return days + ' days ' + hours + ' hours ' + minutes + ' minutes ';
    }

    private static String getUserByName(String displayName) {
        if (displayName != null) {
            List<User> users = [SELECT Id FROM User WHERE Name = :displayName LIMIT 1];
            if (!users.isEmpty()) {
                return users[0].Id;
            }
        }
        return '005dL000000cKiTQAU'; // Default user ID if not found
    }
}
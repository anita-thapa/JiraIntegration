public class GetProjectDetails {
    public static Map<String, String> getProjects() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:JiraAuth/rest/api/3/project');
        req.setMethod('GET'); // Change the method as needed

        // Create HTTP connection
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        string responseBody = res.getBody();
		//System.debug(responseBody);
        
        // Deserialize the JSON response
        List<Object> projects = (List<Object>) JSON.deserializeUntyped(responseBody);
        Map<String, String> idNameMapper = new Map<String, String>();
        
        // Loop through each project
        for (Object projectObj : projects) {
            Map<String, Object> project = (Map<String, Object>) projectObj;

            String name = (String) project.get('name');
            String id = (String) project.get('id');

            idNameMapper.put(id, name);
        }
        return  idNameMapper;  
    }

    public static Map<String, String> getUrl(){
        Map<String, String> idNameMapper = getProjects();
        Map<String, String> idAddressMapper = new Map<String, String>();
        for (String key : idNameMapper.keySet()) {
        	String decodedValue = 'project' + EncodingUtil.urlEncode('=', 'UTF-8')+EncodingUtil.urlEncode(key, 'UTF-8');
            idAddressMapper.put(key, decodedValue);
		}
        return idAddressMapper;
    }
    
    @AuraEnabled(cacheable=true)
    public  static List<Map<String, Map<String, String>>> getProjectName() {
        Map<String, String> idNameMapper = getProjects();
        Map<String, String> idAddressMapper = getUrl();
        Map<String, String> nameAddressMapper = new Map<String, String>();
        
        // Combine nameAddressMapper and idAddressMapper into a single map
        for (String id : idNameMapper.keySet()) {
            if (idAddressMapper.containsKey(id)) {
                String name = idNameMapper.get(id);
                String address = idAddressMapper.get(id);
                nameAddressMapper.put(address, name);
            }
        }
        
        // Create a list to hold the maps
        List<Map<String, Map<String, String>>> projectDetailsList = new List<Map<String, Map<String, String>>>();
        
        // Create a map to hold nameAddressMapper and idAddressMapper
        Map<String, Map<String, String>> projectDetailsMap = new Map<String, Map<String, String>>();
        projectDetailsMap.put('NameAddressMapper', nameAddressMapper);
        projectDetailsMap.put('IdAddressMapper', idAddressMapper);
        
        // Add the map to the list
        projectDetailsList.add(projectDetailsMap);
        for (string detailname: projectDetailsMap.keySet()){
            Map<String, String> value = projectDetailsMap.get(detailname);
            System.debug(value);
        }
        return projectDetailsList;   
    }
}
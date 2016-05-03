/**
 * Encapsulates all behaviour logic relating to the AsyncRequest__c object
 *
 * For more guidelines and details see
 *   https://developer.salesforce.com/page/Apex_Enterprise_Patterns_-_Domain_Layer
 *
 **/
public class RT_AsyncRequests extends fflib_SObjectDomain {

	public static Boolean enabled = true;
	
	public RT_AsyncRequests(List<AsyncRequest__c> records) {
		super(records);
	}
	
	public override void onBeforeInsert() {
		if (enabled) {
			RT_AsyncRequestService.setChecksum(records);
		}
	}
	
	public override void onAfterInsert() {
		if (enabled && isAnyPending()) {
			RT_AsyncRequestService.enqueue();
		}
	}
	
	public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
		if (enabled) {
			RT_AsyncRequestService.setChecksum(records);
		}
	}
	
	public override void onAfterUpdate(Map<Id, SObject> existingRecords) {
		if (enabled && isAnyRequeueing(existingRecords)) {
			RT_AsyncRequestService.enqueue();
		}
	}
	
	public Boolean isAnyPending() {
		Set<String> statuses = new Set<String>();
		for (AsyncRequest__c record : (List<AsyncRequest__c>) records) {
			statuses.add(record.Status__c);
		}
		return statuses.contains('Pending');
	}
	
	public Boolean isAnyRequeueing(Map<Id, SObject> existingRecords) {
		for (AsyncRequest__c newReq : (List<AsyncRequest__c>) records) {
			AsyncRequest__c oldReq = (AsyncRequest__c) existingRecords.get(newReq.Id);
			if (newReq.Status__c == 'Pending' && oldReq.IsDone__c) {
				return true;
			}
		}
		return false;
	}
	
	public class Constructor implements fflib_SObjectDomain.IConstructable {
		public fflib_SObjectDomain construct(List<SObject> records) {
			RT_AsyncRequests domain = new RT_AsyncRequests(records);
			domain.Configuration.disableTriggerCRUDSecurity();
			return domain;
		}
	}
}
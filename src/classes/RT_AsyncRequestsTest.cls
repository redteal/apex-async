@isTest class RT_AsyncRequestsTest {

	/**
	 * Default coverage for AsyncRequest__c trigger operations
	 */
	@isTest static void testTriggerCoverage() {
		AsyncRequest__c record = new AsyncRequest__c(
		    AsyncType__c = 'Test' // required
		);
		insert record;
		update record;
		delete record;
		undelete record;
	}
}
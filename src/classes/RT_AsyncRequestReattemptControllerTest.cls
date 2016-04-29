@isTest class RT_AsyncRequestReattemptControllerTest {

	@isTest static void testController() {
		List<AsyncRequest__c> reqs = new List<AsyncRequest__c>();
		for (Integer i = 0; i < 50; i++) {
			Map<String, Object> data = new Map<String, Object> {'i' => i};
			AsyncRequest__c req = RT_AsyncRequestService.create(FooAsyncTask.class, data);
			req.Status__c = 'Error';
			reqs.add(req);
		}
		insert reqs;
		
		Test.startTest();
		ApexPages.StandardSetController sc = new ApexPages.StandardSetController(reqs);
		RT_AsyncRequestReattemptController con = new RT_AsyncRequestReattemptController(sc);
		sc.setSelected(reqs);
		con.clearErrors();
		Test.stopTest();
	}
	
	public class FooAsyncTask implements RT_IAsyncTask {
		public void execute(AsyncRequest__c asyncRequest, Map<String, Object> params) {}
	}
}
@isTest class RT_AsyncDelegateTest {

	static Integer hitQueueable = 0;
	static Integer hitFuture = 0;
	static Integer hitAsyncTask = 0;
	
	@isTest static void testQueueableWithFuture() {
		Test.startTest();
		Integer availableFutureCalls = RT_AsyncDelegate.getAvailableFutureCalls();
		myFutureCall();
		System.assertEquals(availableFutureCalls - 1, RT_AsyncDelegate.getAvailableFutureCalls(), 'should have decremented @future limit');
		Test.stopTest();
		
		System.assertEquals(1, hitQueueable, 'should have executed the queueable');
		System.assertEquals(1, hitFuture, 'should have executed the @future method');
	}
	
	@future
	static void myFutureCall() {
		System.assert(System.isFuture(), 'should be in future context');
		System.assert(!System.isQueueable(), 'should not be in queueable context');
		
		System.assertEquals(50, RT_AsyncDelegate.getAvailableQueueableJobs(), 'should be able to enqueue a queueable in @future context');
		System.enqueueJob(new FooQueueable());
		System.assertEquals(49, RT_AsyncDelegate.getAvailableQueueableJobs(), 'should have one less available queueables');
		
		System.assertEquals(0, RT_AsyncDelegate.getAvailableFutureCalls(), '@future call limit should be zero in @future context');
		try {
			myFutureCall();
			System.assert(false, 'should not allowed in @future context');
		}
		catch (Exception e) {
		}
		
		hitFuture++;
	}
	
	public class FooQueueable implements Queueable {
	
		public void execute(QueueableContext context) {
			System.assert(System.isQueueable(), 'should be in queueable context');
			System.assert(System.isBatch()); // shouldn't be true; probably a platform bug
			System.assertEquals(1, RT_AsyncDelegate.getAvailableQueueableJobs(), 'should be able to chain another Queueable');
			System.assert(RT_AsyncDelegate.getAvailableFutureCalls() > 0, 'should be able to call @future in queueable context');
			
			hitQueueable++;
		}
	}
	
	@isTest static void testAsyncDelegate() {
		List<AsyncRequest__c> reqs = new List<AsyncRequest__c>();
		for (Integer i = 0; i < 50; i++) {
			reqs.add(
			    new AsyncRequest__c(
			        AsyncType__c = 'RT_AsyncDelegateTest.FooAsyncTask',
			        Params__c = '{"i":' + i + '}'
			    )
			);
		}
		Test.startTest();
		insert reqs;
		Test.stopTest();
		
		System.assertEquals(50, [ SELECT COUNT() FROM AsyncRequest__c WHERE Status__c = 'Complete' ]);
		System.assertEquals(50, hitAsyncTask);
	}
	
	@isTest static void testEnqueue() {
		Test.startTest();
		List<AsyncRequest__c> reqs = new List<AsyncRequest__c>();
		for (Integer i = 0; i < 50; i++) {
			Map<String, Object> data = new Map<String, Object> {'i' => i};
			reqs.add(RT_AsyncRequestService.create(FooAsyncTask.class, data));
		}
		insert reqs;
		RT_AsyncRequestService.enqueue();
		Test.stopTest();
		
		System.assertEquals(50, [ SELECT COUNT() FROM AsyncRequest__c WHERE Status__c = 'Complete' ]);
		System.assertEquals(50, hitAsyncTask);
	}
	
	@isTest static void testEnqueueAsync() {
		RT_AsyncDelegate.enqueueAsync(null);
	}
	
	@isTest static void testScheduleAsync() {
		RT_AsyncDelegate.scheduleAsync();
	}
	
	@isTest static void testAsyncDisabledCoverage() {
		insert new AsyncConfig__c(Name = 'default', Enabled__c = false);
		Test.startTest();
		RT_AsyncDelegate.enqueue(null);
		new RT_AsyncDelegate().execute((Id) null);
		Test.stopTest();
	}
	
	@isTest static void testCreateInvalidAsyncTask() {
		String name = 'invalid!';
		try {
			RT_AsyncDelegate.createAsyncTask(name);
			System.assert(false);
		}
		catch (Exception e) {
			System.assertEquals('Type \'' + name + '\' does not exist', e.getMessage());
		}
	}
	
	@isTest static void testExecuteAtQueryLimits() {
		RT_AsyncDelegate.simulateQueryLimits = true;
		new RT_AsyncDelegate().execute((Id) null);
	}
	
	@isTest static void testErroringAsyncTask() {
		Test.startTest();
		AsyncRequest__c req = RT_AsyncRequestService.create(ErroringAsyncTask.class, new Map<String, Object>());
		insert req;
		Test.stopTest();
		req = [ SELECT Id, Status__c FROM AsyncRequest__c WHERE Id = :req.Id ];
		System.assertEquals('Error', req.Status__c);
	}
	
	@isTest static void testLockedRequest() {
		RT_AsyncDelegate.simulateLockedRequest = true;
		AsyncRequest__c req = RT_AsyncRequestService.create(FooAsyncTask.class, new Map<String, Object>());
		insert req;
	}
	
	@isTest static void testFutureFailure() {
		RT_AsyncDelegate.simulateFutureException = true;
		AsyncRequest__c req = RT_AsyncRequestService.create(FooAsyncTask.class, new Map<String, Object>());
		insert req;
	}
	
	@isTest static void testScheduleFailure() {
		RT_AsyncDelegate.simulateScheduleException = true;
		AsyncRequest__c req = RT_AsyncRequestService.create(FooAsyncTask.class, new Map<String, Object>());
		insert req;
	}
	
	public class FooAsyncTask implements RT_IAsyncTask {
	
		public void execute(AsyncRequest__c asyncRequest, Map<String, Object> params) {
			hitAsyncTask++;
		}
	}
	
	public class ErroringAsyncTask implements RT_IAsyncTask {
	
		public void execute(AsyncRequest__c asyncRequest, Map<String, Object> params) {
			throw new FooException();
		}
	}
	
	class FooException extends Exception {}
}
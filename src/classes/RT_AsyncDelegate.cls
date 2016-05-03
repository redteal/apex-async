public without sharing class RT_AsyncDelegate implements Queueable {

	private class SoqlLimitException extends Exception {}
	
	private class ApexTypeException extends Exception {}
	
	private class FakeException extends Exception {}
	
	private static Boolean isChaining = false;
	
	@testVisible
	private static Boolean simulateQueryLimits = false,
	                       simulateLockedRequest = false,
	                       simulateFutureException = false,
	                       simulateScheduleException = false;
	                       
	private static AsyncConfig__c config;
	static {
		config = AsyncConfig__c.getInstance('default');
		if (config == null) {
			config = new AsyncConfig__c(Name = 'default', Enabled__c = true);
			insert config;
		}
	}
	
	public void execute(QueueableContext context) {
		Id jobId;
		if (context != null) {
			jobId = context.getJobId();
		}
		execute(jobId);
	}
	
	public void execute(Id currentJobId) {
		if (!config.Enabled__c) {
			System.debug(LoggingLevel.INFO, 'App is disabled; exit');
			return;
		}
		if (willHitQueryLimits(1, 1)) {
			System.debug(LoggingLevel.INFO, 'Close to hitting query limit; reattempting...');
			enqueue(currentJobId);
			return;
		}
		
		// Find the current user's oldest pending request
		AsyncRequest__c req = RT_AsyncRequestService.findNextRequest();
		if (req == null) {
			System.debug(LoggingLevel.INFO, 'Done. No pending requests found for the user');
			return;
		}
		try {
			if (simulateLockedRequest) {
				throw new FakeException();
			}
			// Cannot lock and use ORDER BY in same query; lock the record with FOR UPDATE
			req = RT_AsyncRequestService.findById(req.Id);
		}
		catch (Exception e) {
			if (e instanceof QueryException || simulateLockedRequest) {
				System.debug(LoggingLevel.INFO, 'Request seems to be locked by another process; reattempting...');
				enqueue(currentJobId);
			}
			return;
		}
		req.Status__c = 'Pending';
		req.JobId__c = currentJobId;
		
		// dynamically delegate to implementation
		Savepoint sp = Database.setSavepoint();
		try {
			RT_IAsyncTask task = createAsyncTask(req.AsyncType__c);
			System.debug(LoggingLevel.INFO, 'Executing async task (' + req.Id + ')');
			try {
				Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(req.Params__c);
				task.execute(req, params);
			}
			catch (Exception e) {
				throw e;
			}
			System.debug(LoggingLevel.INFO, 'Task completed without errors');
			try {
				req.Error_Message__c = '';
				req.Status__c = 'Complete';
				update req;
			}
			catch (Exception ignored) {}
		}
		catch (Exception e) {
			System.debug(LoggingLevel.ERROR, 'An exception occurred while processing task. Request Id: ' + req.Id);
			RT_AsyncRequestService.setError(req, e);
			Database.rollback(sp);
			update req;
		}
		Boolean hasAdditional;
		if (!willHitQueryLimits(1, 1)) {
			Id userId = UserInfo.getUserId();
			hasAdditional =
			    [ SELECT COUNT() FROM AsyncRequest__c
			      WHERE(Status__c = 'Pending')
			      AND(CreatedById = :userId OR LastModifiedById = :userId)
			      AND(Id != :req.Id)
			      LIMIT 1
			    ] > 0;
		}
		if (hasAdditional == null || hasAdditional) {
			enqueue(currentJobId);
		}
	}
	
	@testVisible
	private static RT_IAsyncTask createAsyncTask(String taskTypeName) {
		Type taskType = Type.forName(taskTypeName);
		if (taskType == null) {
			throw new ApexTypeException('Type \'' + taskTypeName + '\' does not exist');
		}
		Object task = taskType.newInstance();
		if (!(task instanceof RT_IAsyncTask)) {
			throw new ApexTypeException('Type \'' + taskTypeName + '\' must implement ' + RT_IAsyncTask.class);
		}
		return (RT_IAsyncTask) task;
	}
	
	/** Enqueues the current user's async requests with
	 *  automatic fallbacks in case of chaining failure.
	 */
	public static Id enqueue() {
		return enqueue(null);
	}
	
	@testVisible
	private static Id enqueue(Id currentJobId) {
		if (!config.Enabled__c) {
			return null;
		}
		// attempt to queue a job in this context
		if (getAvailableQueueableJobs() > 0 && !simulateFutureException && !simulateScheduleException) {
			if (!RT_AsyncRequestService.hasAvailableQueueSlot(currentJobId)) {
				System.debug('No queueable slots available for user (' + UserInfo.getUserId() +
				             '). Yielding to the current job (' + currentJobId + ').');
				return currentJobId;
			}
			// user has slot available, try to enqueue
			try {
				Id jobId = enqueueJob(currentJobId);
				if (jobId != null) {
					return jobId;
				}
			}
			catch (Exception e) {
				System.debug(LoggingLevel.ERROR, e);
				System.debug(LoggingLevel.INFO, 'Hit an exception while queueing, trying @future...');
			}
		}
		// try @future fallback
		if (getAvailableFutureCalls() > 0 || simulateFutureException) {
			try {
				if (simulateFutureException) {
					throw new FakeException();
				}
				enqueueAsync(currentJobId);
				System.debug('Enqueued async @future method.');
				return null;
			}
			catch (Exception e) {
				System.debug(LoggingLevel.ERROR, e);
				System.debug(LoggingLevel.INFO, 'Hit an exception while calling @future, trying to schedule...');
			}
		}
		// if all else has failed, try scheduled fallback
		try {
			if (simulateScheduleException) {
				throw new FakeException();
			}
			return scheduleAsync();
		}
		catch (Exception e) {
			// failed to schedule?
			System.debug(LoggingLevel.ERROR, e);
			System.debug(LoggingLevel.INFO, 'Hit an exception while scheduling, nothing more to do');
			return null;
		}
	}
	
	@future
	@testVisible
	private static void enqueueAsync(Id currentJobId) {
		System.debug(LoggingLevel.INFO, 'In @future context');
		enqueue(currentJobId);
	}
	
	private static Id enqueueJob(Id currentJobId) {
		if (willHitQueryLimits(1, 1)) {
			throw new SoqlLimitException('SOQL query limit reached');
		}
		System.debug(LoggingLevel.INFO, 'Current job Id: ' + currentJobId);
		String jobId;
		RT_AsyncDelegate delegate = new RT_AsyncDelegate();
		
		if (Test.isRunningTest() && isChaining) {
			// lets just pretend that we're chaining
			// note: this is subject to limits and overflows
			jobId = currentJobId;
			System.debug('Enqueued async job (' + jobId + ')');
			delegate.execute(jobId);
		}
		else {
			jobId = System.enqueueJob(delegate);
			System.debug('Enqueued async job (' + jobId + ')');
			isChaining = true;
			// if jobId is null (eg. tests), then find user's most recently submitted job
			if (jobId == null) {
				jobId = RT_AsyncRequestService.getRecentJobId();
			}
		}
		return jobId;
	}
	
	@testVisible
	private static Id scheduleAsync() {
		Id jobId = RT_SchedulableDispatcher.schedule(QueueableSchedulable.class);
		System.debug('Scheduled async job (' + jobId + ')');
		return jobId;
	}
	
	@testVisible
	private static Integer getAvailableQueueableJobs() {
		return Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
	}
	
	@testVisible
	private static Integer getAvailableFutureCalls() {
		if (System.isFuture() || System.isBatch() && !System.isQueueable()) {
			return 0;
		}
		return Limits.getLimitFutureCalls() - Limits.getFutureCalls();
	}
	
	private static Integer getAvailableQueries() {
		return Limits.getLimitQueries() - Limits.getQueries();
	}
	
	private static Integer getAvailableQueryRows() {
		return Limits.getLimitQueryRows() - Limits.getQueryRows();
	}
	
	private static Boolean willHitQueryLimits(Integer nQueries, Integer nRows) {
		return simulateQueryLimits ||
		       getAvailableQueries() <= nQueries - 1 ||
		       getAvailableQueryRows() <= nRows - 1;
	}
	
	public class QueueableSchedulable implements Schedulable {
	
		public void execute(SchedulableContext context) {
			System.enqueueJob(new RT_AsyncDelegate());
		}
	}
}
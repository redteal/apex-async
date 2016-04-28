public interface RT_IAsyncTask {
	void execute(AsyncRequest__c asyncRequest, Map<String, Object> params);
}
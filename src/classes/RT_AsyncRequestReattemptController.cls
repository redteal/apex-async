public with sharing class RT_AsyncRequestReattemptController {

	private ApexPages.StandardSetController sc;

	@testVisible
	private Boolean throwOnSave = false; // code coverage
	
	public RT_AsyncRequestReattemptController(ApexPages.StandardSetController sc) {
		this.sc = sc;
	}
	
	public PageReference clearErrors() {
		setErrors(true);
		return setErrors(false);
	}
	
	private PageReference setErrors(Boolean err) {
		for (AsyncRequest__c record : (List<AsyncRequest__c>) sc.getSelected()) {
			record.Error_Message__c = null;
			record.Status__c = err ? 'Error' : 'Pending';
		}
		try {
			if (throwOnSave) {
				throw new FakeException();
			}
			return sc.save();
		}
		catch (Exception e) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
			return null;
		}
	}

	class FakeException extends Exception {}
}
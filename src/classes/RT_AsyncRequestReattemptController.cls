public with sharing class RT_AsyncRequestReattemptController {

	private ApexPages.StandardSetController sc;
	
	public RT_AsyncRequestReattemptController(ApexPages.StandardSetController sc) {
		this.sc = sc;
		if (!Test.isRunningTest()) {
			sc.addFields('Status__c'.split(','));
		}
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
			return sc.save();
		}
		catch (Exception e) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
			return null;
		}
	}
}
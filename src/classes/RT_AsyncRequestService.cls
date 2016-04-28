public class RT_AsyncRequestService {

	public static void setChecksum(List<AsyncRequest__c> records) {
		for (AsyncRequest__c record : records) {
			record.Checksum__c = md5(record.AsyncType__c + record.Params__c);
		}
	}
	
	public static void setChecksum(AsyncRequest__c record) {
		setChecksum(new List<AsyncRequest__c> {record});
	}
	
	private static String md5(String input) {
		return EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(input)));
	}
	
	/**
	 * Create an AsyncRequest of the given type and parameters.
	 * @return An AsyncRequest instance, or null if there already exists
	 *         an in-progress record with the same type/parameters.
	 */
	public static AsyncRequest__c create(String asyncType, Object paramsUntyped) {
		AsyncRequest__c req = new AsyncRequest__c(
		    AsyncType__c = asyncType,
		    Status__c = 'Pending',
		    Params__c = JSON.serializePretty(paramsUntyped)
		);
		setChecksum(req);
		return req;
	}
	
	/**
	 * Create an AsyncRequest of the given type and parameters.
	 * @return An AsyncRequest instance, or null if there already exists
	 *         an in-progress record with the same type/parameters.
	 */
	public static AsyncRequest__c create(Type asyncType, Object paramsUntyped) {
		return create('' + asyncType, paramsUntyped);
	}
	
	public static void setError(AsyncRequest__c req, Exception e) {
		req.Status__c = 'Error';
		req.Error_Message__c = e.getTypeName() + ': ' + e.getMessage() + '\n\n' + e.getStackTraceString();
	}
	
	public static void enqueue() {
		RT_AsyncDelegate.enqueue();
	}
	
	public static AsyncRequest__c findById(Id id) {
		List<AsyncRequest__c> reqs =
		    [ SELECT Id, AsyncType__c, Params__c, Status__c
		      FROM AsyncRequest__c
		      WHERE Id = :id FOR UPDATE
		    ];
		return reqs.isEmpty() ? null : reqs.get(0);
	}
	
	public static AsyncRequest__c findNextRequest() {
		Id userId = UserInfo.getUserId();
		List<AsyncRequest__c> reqs =
		    [ SELECT Id FROM AsyncRequest__c
		      WHERE(Status__c = 'Pending')
		      AND(CreatedById = :userId OR LastModifiedById = :userId)
		      ORDER BY LastModifiedDate ASC
		      LIMIT 1
		    ];
		return reqs.isEmpty() ? null : reqs.get(0);
	}
	
	public static Boolean hasAvailableQueueSlot(Id currentJobId) {
		Id userId = UserInfo.getUserId();
		if (currentJobId != null) {
			return
			    [ SELECT COUNT() FROM AsyncApexJob
			      WHERE(Id != :currentJobId)
			      AND(JobType = 'Queueable')
			      AND Status IN('Queued', 'Holding')
			      AND(ApexClass.Name = :('' + RT_AsyncDelegate.class))
			      AND(CreatedById = :userId)
			      LIMIT 1
			    ] == 0;
		}
		else {
			return
			    [ SELECT COUNT() FROM AsyncApexJob
			      WHERE(JobType = 'Queueable')
			      AND Status IN('Queued', 'Holding')
			      AND(ApexClass.Name = :('' + RT_AsyncDelegate.class))
			      AND(CreatedById = :userId)
			      LIMIT 1
			    ] == 0;
		}
	}
	
	public static Id getRecentJobId() {
		Id userId = UserInfo.getUserId();
		List<AsyncApexJob> jobs =
		    [ SELECT Id FROM AsyncApexJob
		      WHERE(JobType = 'Queueable')
		      AND Status IN('Queued', 'Holding')
		      AND(ApexClass.Name = :('' + RT_AsyncDelegate.class))
		      AND(CreatedById = :userId)
		      ORDER BY CreatedDate ASC
		      LIMIT 1
		    ];
		return jobs.isEmpty() ? null : jobs.get(0).Id;
	}
}
# apex-async

[![deploy to salesforce](https://img.shields.io/badge/salesforce-deploy-blue.svg)](https://githubsfdeploy.herokuapp.com)
[![Build Status](https://img.shields.io/travis/redteal/apex-async.svg)](https://travis-ci.org/redteal/apex-async)
[![Coverage Status](https://img.shields.io/coveralls/redteal/apex-async.svg)](https://coveralls.io/github/redteal/apex-async?branch=master)

An abstraction for asynchronous Apex implementations in Salesforce.

[![architecture uml](./docs/async-uml.png)](https://raw.githubusercontent.com/redteal/apex-async/master/docs/async-uml.png)

## Example

```java
public class FooAsyncTask implements RT_IAsyncTask {
	public void execute(AsyncRequest__c asyncRequest, Map<String, Object> params) {
		System.debug(params.get('i'));
	}
}
```

```java
List<AsyncRequest__c> reqs = new List<AsyncRequest__c>();
for (Integer i = 0; i < 50; i++) {
	Map<String, Object> params = new Map<String, Object> {'i' => i};
	reqs.add(RT_AsyncRequestService.create(FooAsyncTask.class, params));
}
insert reqs;
```

Insertion of `AsyncRequest__c` triggers the task to be queued for processing.

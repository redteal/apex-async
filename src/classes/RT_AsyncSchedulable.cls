public class RT_AsyncSchedulable implements Schedulable {
	public Boolean singleRun = true;
	
	public void execute(SchedulableContext context) {
		System.enqueueJob(new RT_AsyncDelegate());
		if (singleRun) {
			System.abortJob(context.getTriggerID());
		}
	}
}
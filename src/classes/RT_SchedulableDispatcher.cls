/**
 *  A centralized router for running Schedulables. Routing Schedulables via this dispatcher
 *  allows for easy redeployment of implementations without risking a job failure.
 *
 *  Effictively removes need for using the Apex job deployment option:
 *  > Allow deployments of components when corresponding Apex jobs are pending or in progress.
 *  > Caution: Enabling this option may cause Apex jobs to fail.
 */
public class RT_SchedulableDispatcher implements Schedulable {
	static final Set<String> FINISHED_STATUSES = new Set<String> {'Completed', 'Error', 'Deleted'};
	
	String name;
	
	public RT_SchedulableDispatcher(String name) {
		this.name = name;
	}
	
	public void execute(SchedulableContext sc) {
		Type targetType = Type.forName(name);
		if (targetType == null) {
			throw new ApexTypeException('Apex type \'' + name + '\' does not exist');
		}
		Object obj = targetType.newInstance();
		if (!(obj instanceof Schedulable)) {
			throw new ApexTypeException('Apex type \'' + name + '\' must implement Schedulable');
		}
		Schedulable sched = (Schedulable) obj;
		sched.execute(sc);
	}
	
	/**
	 * Schedules a one-time job to be dispatched in one minute
	 * @param jobType Apex Type of the implemented Schedulable
	 * @return the job Id
	 */
	public static Id schedule(Type jobType) {
		return schedule(null, null, jobType);
	}

	/**
	 * Schedules a one-time job to be dispatched
	 * @param dt DateTime of when the job should be run
	 * @param jobType Apex Type of the implemented Schedulable
	 * @return the job Id
	 */
	public static Id schedule(DateTime dt, Type jobType) {
		return schedule(dt, null, jobType);
	}
	
	/**
	 * Schedules a recurring job to be dispatched
	 * @param expr Cron expression for scheduling the job
	 * @param jobType Apex Type of the implemented Schedulable
	 * @return the job Id
	 */
	public static Id schedule(String expr, Type jobType) {
		return schedule(null, expr, jobType);
	}
	
	static Id schedule(DateTime dt, String expr, Type jobType) {
		if (jobType == null) { return null; }
		String jobName = '' + jobType;
		
		List<CronTrigger> jobs = [ SELECT Id, State FROM CronTrigger WHERE CronJobDetail.Name = :jobName LIMIT 1 ];
		if (!jobs.isEmpty()) {
			CronTrigger job = jobs.get(0);
			if (!FINISHED_STATUSES.contains(job.State)) {
				// It's already running or scheduled
				return job.Id;
			}
			// If the job is not running, it needs to be deleted
			System.abortJob(job.Id);
		}
		if (expr == null) {
			dt = normalizeDateTime(dt); // Don't try to schedule Apex before current time + buffer
			Integer s = dt.second(), m = dt.minute(), h = dt.hour(), d = dt.day(), mo = dt.month(), y = dt.year();
			expr = s + ' ' + m + ' ' + h + ' ' + d + ' ' + mo + ' ? ' + y;
		}
		return System.schedule(jobName, expr, new RT_SchedulableDispatcher(jobName));
	}
	
	static DateTime normalizeDateTime(DateTime dt) {
		if (dt == null || dt < DateTime.now().addMinutes(1)) {
			dt = DateTime.now().addMinutes(1);
		}
		return dt;
	}
	
	class ApexTypeException extends Exception {}

	public class FakeSchedulable {}
}
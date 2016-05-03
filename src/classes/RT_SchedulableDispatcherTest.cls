@isTest class RT_SchedulableDispatcherTest {

	@isTest static void testScheduleDateTime() {
		RT_SchedulableDispatcher.schedule(DateTime.now(), RT_AsyncDelegate.QueueableSchedulable.class);
	}

	@isTest static void testReschedule() {
		RT_SchedulableDispatcher.schedule(DateTime.now(), RT_AsyncDelegate.QueueableSchedulable.class);
		RT_SchedulableDispatcher.schedule(DateTime.now(), RT_AsyncDelegate.QueueableSchedulable.class);
	}
	
	@isTest static void testScheduleExpr() {
		RT_SchedulableDispatcher.schedule('0 0 * * * ? *', RT_AsyncDelegate.QueueableSchedulable.class);
	}
	
	@isTest static void testScheduleInvalidType() {
		String name = 'invalid!';
		RT_SchedulableDispatcher disp = new RT_SchedulableDispatcher(name);
		try {
			disp.execute(null);
			System.assert(false);
		}
		catch (Exception e) {
			System.assertEquals('Apex type \'' + name + '\' does not exist', e.getMessage());
		}
	}
	
	@isTest static void testScheduleInvalidSchedulable() {
		String name = 'RT_SchedulableDispatcher.FakeSchedulable';
		RT_SchedulableDispatcher disp = new RT_SchedulableDispatcher(name);
		try {
			disp.execute(null);
			System.assert(false);
		}
		catch (Exception e) {
			System.assertEquals('Apex type \'' + name + '\' must implement Schedulable', e.getMessage());
		}
	}
}
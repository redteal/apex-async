@isTest class RT_SchedulableDispatcherTest {

	@isTest static void testScheduleDateTime() {
		RT_SchedulableDispatcher.schedule(DateTime.now(), RT_AsyncSchedulable.class);
	}

	@isTest static void testScheduleExpr() {
		RT_SchedulableDispatcher.schedule('0 0 * * * ? *', RT_AsyncSchedulable.class);
	}
}
@IsTest
private class EventforceTest {

    private static Venue__c makeVenue(Integer capacity) {
        Venue__c v = new Venue__c(Name = 'Hall A', Address__c = '1 Main St', Capacity__c = capacity);
        insert v;
        return v;
    }

    private static Event__c makeEvent(Id venueId, Integer capacity, String status, Datetime startAt) {
        Event__c e = new Event__c(
            Name = 'Dev Summit',
            Start_Date__c = startAt,
            End_Date__c = startAt.addHours(4),
            Venue__c = venueId,
            Capacity__c = capacity,
            Ticket_Price__c = 0,
            Status__c = status
        );
        insert e;
        return e;
    }

    private static Attendee_Registration__c makeReg(Id eventId, String email) {
        return new Attendee_Registration__c(
            Event__c = eventId, Attendee_Name__c = 'Ada Lovelace', Email__c = email, Status__c = 'Registered'
        );
    }

    // ---------------------------------------------------------- Event rules
    @IsTest
    static void endBeforeStartIsRejected() {
        Venue__c v = makeVenue(100);
        Event__c e = new Event__c(
            Name = 'Bad dates', Venue__c = v.Id, Capacity__c = 10, Status__c = 'Draft',
            Start_Date__c = System.now().addDays(2), End_Date__c = System.now().addDays(1)
        );
        Database.SaveResult sr = Database.insert(e, false);
        Assert.isFalse(sr.isSuccess());
    }

    @IsTest
    static void capacityCannotExceedVenue() {
        Venue__c v = makeVenue(50);
        Event__c e = new Event__c(
            Name = 'Too big', Venue__c = v.Id, Capacity__c = 80, Status__c = 'Draft',
            Start_Date__c = System.now().addDays(1), End_Date__c = System.now().addDays(1).addHours(2)
        );
        Assert.isFalse(Database.insert(e, false).isSuccess());
    }

    @IsTest
    static void overlappingEventsAtSameVenueAreRejected() {
        Venue__c v = makeVenue(100);
        Datetime startAt = System.now().addDays(3);
        makeEvent(v.Id, 20, 'Draft', startAt);
        Event__c clash = new Event__c(
            Name = 'Clash', Venue__c = v.Id, Capacity__c = 20, Status__c = 'Draft',
            Start_Date__c = startAt.addHours(1), End_Date__c = startAt.addHours(3)
        );
        Assert.isFalse(Database.insert(clash, false).isSuccess());

        Event__c later = new Event__c(
            Name = 'Later', Venue__c = v.Id, Capacity__c = 20, Status__c = 'Draft',
            Start_Date__c = startAt.addHours(5), End_Date__c = startAt.addHours(6)
        );
        Assert.isTrue(Database.insert(later, false).isSuccess());
    }

    @IsTest
    static void publishedEventNeedsVenue() {
        Event__c e = new Event__c(
            Name = 'No venue', Capacity__c = 10, Status__c = 'Published',
            Start_Date__c = System.now().addDays(1), End_Date__c = System.now().addDays(1).addHours(1)
        );
        Assert.isFalse(Database.insert(e, false).isSuccess());
    }

    // ---------------------------------------------------------- Registration rules
    @IsTest
    static void cannotOversell() {
        Event__c e = makeEvent(makeVenue(100).Id, 1, 'Published', System.now().addDays(5));
        Assert.isTrue(Database.insert(makeReg(e.Id, 'a@example.com'), false).isSuccess());
        Assert.isFalse(Database.insert(makeReg(e.Id, 'b@example.com'), false).isSuccess());
    }

    @IsTest
    static void duplicateEmailIsRejected() {
        Event__c e = makeEvent(makeVenue(100).Id, 5, 'Published', System.now().addDays(5));
        insert makeReg(e.Id, 'dup@example.com');
        Assert.isFalse(Database.insert(makeReg(e.Id, 'DUP@example.com'), false).isSuccess());
    }

    @IsTest
    static void unpublishedEventRejectsRegistration() {
        Event__c e = makeEvent(makeVenue(100).Id, 5, 'Draft', System.now().addDays(5));
        Assert.isFalse(Database.insert(makeReg(e.Id, 'x@example.com'), false).isSuccess());
    }

    @IsTest
    static void cancelledSeatIsFreedUp() {
        Event__c e = makeEvent(makeVenue(100).Id, 1, 'Published', System.now().addDays(5));
        Attendee_Registration__c first = makeReg(e.Id, 'a@example.com');
        insert first;
        first.Status__c = 'Cancelled';
        update first;
        Assert.isTrue(Database.insert(makeReg(e.Id, 'b@example.com'), false).isSuccess());
    }

    // ---------------------------------------------------------- Service / controller
    @IsTest
    static void registerAndCheckInFlow() {
        Event__c e = makeEvent(makeVenue(100).Id, 10, 'Published', System.now().addDays(2));

        Assert.areEqual(1, EventController.getUpcomingEvents().size());

        EventService.RegistrationResult res = EventController.register(e.Id, 'Grace Hopper', 'grace@example.com');
        Assert.isTrue(res.success, res.message);
        Assert.isTrue(res.ticketNumber.startsWith('TKT-'));

        Event__c refreshed = [SELECT Registered_Count__c, Seats_Available__c FROM Event__c WHERE Id = :e.Id];
        Assert.isTrue(refreshed.Registered_Count__c == 1);
        Assert.isTrue(refreshed.Seats_Available__c == 9);

        Assert.isTrue(EventController.checkIn(res.ticketNumber).success);
        Assert.isFalse(EventController.checkIn(res.ticketNumber).success, 'second check-in should fail');
        Assert.isFalse(EventController.checkIn('TKT-9999').success);

        Attendee_Registration__c saved = [
            SELECT Status__c, Checked_In_At__c FROM Attendee_Registration__c WHERE Name = :res.ticketNumber
        ];
        Assert.areEqual('Checked In', saved.Status__c);
        Assert.isNotNull(saved.Checked_In_At__c);
    }

    @IsTest
    static void registerValidatesInput() {
        Assert.isFalse(EventService.register(null, 'x', 'x@example.com').success);
        Event__c e = makeEvent(makeVenue(100).Id, 10, 'Published', System.now().addDays(2));
        Assert.isFalse(EventService.register(e.Id, '', 'x@example.com').success);
    }

    // ---------------------------------------------------------- Batch
    @IsTest
    static void reminderBatchMarksRegistrations() {
        Event__c e = makeEvent(makeVenue(100).Id, 10, 'Published', System.now().addHours(12));
        insert makeReg(e.Id, 'soon@example.com');

        Test.startTest();
        Database.executeBatch(new EventReminderBatch(), 100);
        Test.stopTest();

        Attendee_Registration__c reg = [SELECT Reminder_Sent__c FROM Attendee_Registration__c LIMIT 1];
        Assert.isTrue(reg.Reminder_Sent__c);
    }

    @IsTest
    static void reminderCanBeScheduled() {
        Test.startTest();
        String jobId = EventReminderBatch.scheduleHourly();
        Test.stopTest();
        Assert.isNotNull(jobId);
    }
}

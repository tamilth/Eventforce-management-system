trigger AttendeeRegistrationTrigger on Attendee_Registration__c (before insert, before update) {
    AttendeeRegistrationTriggerHandler.validate(Trigger.new, Trigger.oldMap);
}

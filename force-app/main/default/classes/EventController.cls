public with sharing class EventController {

    @AuraEnabled(cacheable=true)
    public static List<Event__c> getUpcomingEvents() {
        return EventService.getUpcomingEvents();
    }

    @AuraEnabled
    public static EventService.RegistrationResult register(Id eventId, String attendeeName, String email) {
        return EventService.register(eventId, attendeeName, email);
    }

    @AuraEnabled
    public static EventService.RegistrationResult checkIn(String ticketNumber) {
        return EventService.checkIn(ticketNumber);
    }
}

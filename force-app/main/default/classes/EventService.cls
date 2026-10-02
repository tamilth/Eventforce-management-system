/**
 * Service layer used by the LWC controller (and reusable from Flow / other Apex).
 */
public with sharing class EventService {

    public class RegistrationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String ticketNumber;

        public RegistrationResult(Boolean success, String message, String ticketNumber) {
            this.success = success;
            this.message = message;
            this.ticketNumber = ticketNumber;
        }
    }

    public static List<Event__c> getUpcomingEvents() {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Venue__r.Name, Capacity__c,
                   Ticket_Price__c, Seats_Available__c, Description__c
            FROM Event__c
            WHERE Status__c = 'Published' AND End_Date__c >= :System.now()
            WITH USER_MODE
            ORDER BY Start_Date__c ASC
            LIMIT 50
        ];
    }

    public static RegistrationResult register(Id eventId, String attendeeName, String email) {
        if (eventId == null || String.isBlank(attendeeName) || String.isBlank(email)) {
            return new RegistrationResult(false, 'Name and email are required.', null);
        }
        List<Event__c> events = [
            SELECT Id, Ticket_Price__c FROM Event__c WHERE Id = :eventId WITH USER_MODE LIMIT 1
        ];
        if (events.isEmpty()) {
            return new RegistrationResult(false, 'Event not found.', null);
        }

        Boolean isFree = events[0].Ticket_Price__c == null || events[0].Ticket_Price__c == 0;
        Attendee_Registration__c reg = new Attendee_Registration__c(
            Event__c = eventId,
            Attendee_Name__c = attendeeName.trim(),
            Email__c = email.trim(),
            Status__c = 'Registered',
            Payment_Status__c = isFree ? 'Free' : 'Pending'
        );
        try {
            Database.insert(reg, true, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            return new RegistrationResult(false, e.getDmlMessage(0), null);
        } catch (Exception e) {
            return new RegistrationResult(false, e.getMessage(), null);
        }

        Attendee_Registration__c saved = [
            SELECT Name FROM Attendee_Registration__c WHERE Id = :reg.Id WITH USER_MODE
        ];
        return new RegistrationResult(true, 'You are registered!', saved.Name);
    }

    public static RegistrationResult checkIn(String ticketNumber) {
        if (String.isBlank(ticketNumber)) {
            return new RegistrationResult(false, 'Enter a ticket number.', null);
        }
        List<Attendee_Registration__c> regs = [
            SELECT Id, Name, Status__c, Checked_In_At__c, Attendee_Name__c
            FROM Attendee_Registration__c
            WHERE Name = :ticketNumber.trim()
            WITH USER_MODE
            LIMIT 1
        ];
        if (regs.isEmpty()) {
            return new RegistrationResult(false, 'Ticket not found.', null);
        }
        Attendee_Registration__c reg = regs[0];
        if (reg.Status__c == 'Cancelled') {
            return new RegistrationResult(false, 'This registration was cancelled.', reg.Name);
        }
        if (reg.Status__c == 'Checked In') {
            return new RegistrationResult(false, 'Already checked in.', reg.Name);
        }
        reg.Status__c = 'Checked In';
        reg.Checked_In_At__c = System.now();
        try {
            Database.update(reg, true, AccessLevel.USER_MODE);
        } catch (Exception e) {
            return new RegistrationResult(false, e.getMessage(), reg.Name);
        }
        return new RegistrationResult(true, 'Welcome, ' + reg.Attendee_Name__c + '!', reg.Name);
    }
}

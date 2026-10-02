/**
 * Business rules for Attendee_Registration__c:
 *  - only Published events accept registrations
 *  - events cannot be oversold
 *  - one active registration per email per event
 *  - stamps Checked_In_At__c when status becomes "Checked In"
 */
public with sharing class AttendeeRegistrationTriggerHandler {

    public static void validate(List<Attendee_Registration__c> newList, Map<Id, Attendee_Registration__c> oldMap) {
        Set<Id> eventIds = new Set<Id>();
        for (Attendee_Registration__c r : newList) {
            if (r.Event__c != null) {
                eventIds.add(r.Event__c);
            }
        }
        if (eventIds.isEmpty()) {
            return;
        }

        Map<Id, Event__c> events = new Map<Id, Event__c>(
            [SELECT Id, Status__c, Capacity__c FROM Event__c WHERE Id IN :eventIds]
        );
        Map<Id, Integer> activeCounts = new Map<Id, Integer>();
        Map<Id, Set<String>> activeEmails = new Map<Id, Set<String>>();
        for (Id eventId : eventIds) {
            activeCounts.put(eventId, 0);
            activeEmails.put(eventId, new Set<String>());
        }
        for (Attendee_Registration__c existing : [
            SELECT Id, Event__c, Email__c
            FROM Attendee_Registration__c
            WHERE Event__c IN :eventIds AND Status__c != 'Cancelled'
        ]) {
            activeCounts.put(existing.Event__c, activeCounts.get(existing.Event__c) + 1);
            if (existing.Email__c != null) {
                activeEmails.get(existing.Event__c).add(existing.Email__c.toLowerCase());
            }
        }

        for (Attendee_Registration__c r : newList) {
            if (r.Status__c == 'Checked In' && r.Checked_In_At__c == null) {
                r.Checked_In_At__c = System.now();
            }
            if (r.Status__c == 'Cancelled') {
                continue;
            }

            Attendee_Registration__c old = (oldMap == null) ? null : oldMap.get(r.Id);
            Boolean alreadyActive = old != null && old.Status__c != 'Cancelled';
            if (alreadyActive) {
                continue; // already counted in the totals above
            }

            Event__c ev = events.get(r.Event__c);
            if (ev == null) {
                continue;
            }
            if (ev.Status__c != 'Published') {
                r.addError('Registration is only open for published events.');
                continue;
            }
            Integer count = activeCounts.get(ev.Id);
            if (ev.Capacity__c != null && count >= ev.Capacity__c) {
                r.addError('Sorry, this event is sold out.');
                continue;
            }
            String key = (r.Email__c == null) ? null : r.Email__c.toLowerCase();
            if (key != null && activeEmails.get(ev.Id).contains(key)) {
                r.Email__c.addError('This email is already registered for the event.');
                continue;
            }
            activeCounts.put(ev.Id, count + 1);
            if (key != null) {
                activeEmails.get(ev.Id).add(key);
            }
        }
    }
}

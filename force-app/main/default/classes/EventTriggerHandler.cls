/**
 * Business rules for Event__c:
 *  - end date must be after start date
 *  - event capacity cannot exceed the venue capacity
 *  - a venue cannot host two overlapping (non-cancelled) events
 */
public with sharing class EventTriggerHandler {

    public static void validate(List<Event__c> newList, Map<Id, Event__c> oldMap) {
        Set<Id> venueIds = new Set<Id>();
        Set<Id> selfIds = new Set<Id>();

        for (Event__c e : newList) {
            if (e.Id != null) {
                selfIds.add(e.Id);
            }
            if (e.Start_Date__c != null && e.End_Date__c != null && e.End_Date__c <= e.Start_Date__c) {
                e.End_Date__c.addError('End date must be after the start date.');
            }
            if (e.Venue__c != null) {
                venueIds.add(e.Venue__c);
            }
        }
        if (venueIds.isEmpty()) {
            return;
        }

        Map<Id, Venue__c> venues = new Map<Id, Venue__c>(
            [SELECT Id, Capacity__c FROM Venue__c WHERE Id IN :venueIds]
        );

        Map<Id, List<Event__c>> bookedByVenue = new Map<Id, List<Event__c>>();
        for (Id venueId : venueIds) {
            bookedByVenue.put(venueId, new List<Event__c>());
        }
        for (Event__c existing : [
            SELECT Id, Venue__c, Start_Date__c, End_Date__c
            FROM Event__c
            WHERE Venue__c IN :venueIds AND Status__c != 'Cancelled' AND Id NOT IN :selfIds
        ]) {
            bookedByVenue.get(existing.Venue__c).add(existing);
        }

        for (Event__c e : newList) {
            if (e.Venue__c == null || e.Status__c == 'Cancelled') {
                continue;
            }
            Venue__c venue = venues.get(e.Venue__c);
            if (venue != null && venue.Capacity__c != null && e.Capacity__c != null
                && e.Capacity__c > venue.Capacity__c) {
                e.Capacity__c.addError('Capacity exceeds the venue capacity of ' + venue.Capacity__c + '.');
            }
            if (e.Start_Date__c == null || e.End_Date__c == null) {
                continue;
            }
            List<Event__c> booked = bookedByVenue.get(e.Venue__c);
            for (Event__c other : booked) {
                if (other.Start_Date__c < e.End_Date__c && other.End_Date__c > e.Start_Date__c) {
                    e.Venue__c.addError('This venue is already booked for an overlapping event.');
                    break;
                }
            }
            booked.add(e); // also catches overlaps inside the same batch
        }
    }
}

/**
 * Emails attendees of Published events starting within the next 24 hours.
 * Run once:      Database.executeBatch(new EventReminderBatch(), 100);
 * Schedule hourly: EventReminderBatch.scheduleHourly();
 */
global with sharing class EventReminderBatch implements Database.Batchable<SObject>, Schedulable {

    global static String scheduleHourly() {
        return System.schedule('Eventforce Reminders', '0 0 * * * ?', new EventReminderBatch());
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime now = System.now();
        Datetime cutoff = now.addHours(24);
        return Database.getQueryLocator([
            SELECT Id, Attendee_Name__c, Email__c, Event__r.Name, Event__r.Start_Date__c
            FROM Attendee_Registration__c
            WHERE Status__c = 'Registered'
              AND Reminder_Sent__c = false
              AND Event__r.Status__c = 'Published'
              AND Event__r.Start_Date__c > :now
              AND Event__r.Start_Date__c <= :cutoff
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Attendee_Registration__c> scope) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Attendee_Registration__c r : scope) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ r.Email__c });
            mail.setSubject('Reminder: ' + r.Event__r.Name + ' starts soon');
            mail.setPlainTextBody(
                'Hi ' + r.Attendee_Name__c + ',\n\n' +
                r.Event__r.Name + ' starts on ' +
                r.Event__r.Start_Date__c.format('MMM d, yyyy h:mm a') + '.\n\nSee you there!'
            );
            mail.setSaveAsActivity(false);
            mails.add(mail);
            r.Reminder_Sent__c = true;
        }
        if (!mails.isEmpty()) {
            Messaging.sendEmail(mails, false);
            update scope;
        }
    }

    global void finish(Database.BatchableContext bc) {
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new EventReminderBatch(), 100);
    }
}

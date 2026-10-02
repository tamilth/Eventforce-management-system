// sf apex run --file scripts/apex/seed.apex
Venue__c hall = new Venue__c(Name = 'Grand Hall', Address__c = '1 Market Street', Capacity__c = 300);
Venue__c lab = new Venue__c(Name = 'Innovation Lab', Address__c = '22 Tech Park', Capacity__c = 40);
insert new List<Venue__c>{ hall, lab };

Datetime nextWeek = System.now().addDays(7);
insert new List<Event__c>{
    new Event__c(Name = 'Salesforce Developer Meetup', Venue__c = hall.Id, Capacity__c = 200,
        Ticket_Price__c = 0, Status__c = 'Published', Start_Date__c = nextWeek, End_Date__c = nextWeek.addHours(3),
        Description__c = 'Lightning Web Components, Apex and Flow tips from the community.'),
    new Event__c(Name = 'Apex Hands-on Workshop', Venue__c = lab.Id, Capacity__c = 30,
        Ticket_Price__c = 25, Status__c = 'Published', Start_Date__c = nextWeek.addDays(2), End_Date__c = nextWeek.addDays(2).addHours(6),
        Description__c = 'Triggers, batch jobs and testing, with a working lab.')
};

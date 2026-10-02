trigger EventTrigger on Event__c (before insert, before update) {
    EventTriggerHandler.validate(Trigger.new, Trigger.oldMap);
}

# Eventforce Management system 

An event management system built on the Salesforce platform (SFDX project).

## Features
- **Data model**: `Venue__c`, `Event__c`, `Session__c`, `Attendee_Registration__c` (master-detail to Event, auto-numbered ticket `TKT-0001`).
- **Business rules (Apex triggers)**
  - End date after start date; event capacity cannot exceed venue capacity
  - No overlapping events at the same venue
  - Registrations only for *Published* events, no overselling, one active registration per email
  - Check-in timestamp stamped automatically
- **Roll-up + formula**: `Registered_Count__c` (active registrations) and `Seats_Available__c`
- **Lightning Web Components**
  - `eventforceHome`: public-style event list with a registration modal
  - `eventCheckIn`: ticket-number check-in screen for door staff
- **Batch / Schedulable**: `EventReminderBatch` emails attendees 24h before an event
- **Security**: `Eventforce_Admin` and `Eventforce_Organizer` permission sets
- **CI**: GitHub Actions runs all Apex tests in a scratch org

## Getting started
```bash
sf org login web --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --alias eventforce --set-default
sf project deploy start
sf org assign permset --name Eventforce_Admin
sf apex run --file scripts/apex/seed.apex
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10
sf org open
```

Then, in the org:
1. Open **App Launcher → Eventforce**.
2. Use **Setup → Lightning App Builder** to create an App Page and drag in `eventforceHome` and `eventCheckIn`.
3. (Optional) schedule reminders: run `EventReminderBatch.scheduleHourly();` in Anonymous Apex.

## Project layout
```
force-app/main/default/
  applications/   objects/   tabs/   permissionsets/
  classes/        triggers/  lwc/
config/           scripts/apex/   .github/workflows/ci.yml
```

## Ideas for next steps
- Approval process / Flow for *Pending Approval → Published*
- Experience Cloud site exposing `eventforceHome` to guests (add guest-user permissions)
- Payment integration for paid tickets (`Payment_Status__c` is ready)
- Sessions/agenda component and QR-code tickets

## CI setup
Add a repository secret `DEVHUB_SFDX_URL` (output of `sf org display --verbose --target-org <devhub>`, the *Sfdx Auth Url* value).

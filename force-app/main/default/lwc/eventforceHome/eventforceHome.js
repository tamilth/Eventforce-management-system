import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CURRENCY from '@salesforce/i18n/currency';
import getUpcomingEvents from '@salesforce/apex/EventController.getUpcomingEvents';
import register from '@salesforce/apex/EventController.register';

export default class EventforceHome extends LightningElement {
    events = [];
    error;
    selectedEvent;
    attendeeName = '';
    email = '';
    isSaving = false;
    wiredResult;

    @wire(getUpcomingEvents)
    wiredEvents(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            const money = new Intl.NumberFormat(undefined, { style: 'currency', currency: CURRENCY });
            this.events = data.map((e) => ({
                ...e,
                soldOut: e.Seats_Available__c <= 0,
                venueName: e.Venue__r ? e.Venue__r.Name : 'Venue TBA',
                priceLabel: e.Ticket_Price__c > 0 ? money.format(e.Ticket_Price__c) : 'Free'
            }));
            this.error = undefined;
        } else if (error) {
            this.events = [];
            this.error = error.body ? error.body.message : 'Unable to load events.';
        }
    }

    get hasEvents() {
        return this.events.length > 0;
    }

    openModal(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedEvent = this.events.find((e) => e.Id === id);
    }

    closeModal() {
        this.selectedEvent = undefined;
        this.attendeeName = '';
        this.email = '';
        this.isSaving = false;
    }

    handleChange(event) {
        this[event.target.name] = event.target.value;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handleRegister() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        if (!inputs.every((i) => i.reportValidity())) {
            return;
        }
        this.isSaving = true;
        try {
            const res = await register({
                eventId: this.selectedEvent.Id,
                attendeeName: this.attendeeName,
                email: this.email
            });
            if (res.success) {
                this.toast('Registered', `${res.message} Your ticket: ${res.ticketNumber}`, 'success');
                this.closeModal();
                await refreshApex(this.wiredResult);
            } else {
                this.toast('Could not register', res.message, 'error');
                this.isSaving = false;
            }
        } catch (e) {
            this.toast('Error', e.body ? e.body.message : e.message, 'error');
            this.isSaving = false;
        }
    }
}

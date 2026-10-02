import { LightningElement } from 'lwc';
import checkIn from '@salesforce/apex/EventController.checkIn';

export default class EventCheckIn extends LightningElement {
    ticketNumber = '';
    result;
    isBusy = false;

    get resultClass() {
        const tone = this.result && this.result.success ? 'slds-theme_success' : 'slds-theme_error';
        return `slds-m-top_small slds-p-around_small slds-text-align_center ${tone}`;
    }

    handleChange(event) {
        this.ticketNumber = event.target.value;
    }

    handleKey(event) {
        if (event.key === 'Enter') {
            this.handleCheckIn();
        }
    }

    async handleCheckIn() {
        this.isBusy = true;
        try {
            this.result = await checkIn({ ticketNumber: this.ticketNumber });
            if (this.result.success) {
                this.ticketNumber = '';
            }
        } catch (e) {
            this.result = { success: false, message: e.body ? e.body.message : e.message };
        } finally {
            this.isBusy = false;
        }
    }
}

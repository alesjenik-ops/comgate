/**
 * Created by LukášGregora on 02/05/2022.
 */

import { LightningElement, api } from 'lwc';

export default class InfoDropdown extends LightningElement {
    @api heading;
    @api bodyText;
    @api expanded = false;
    @api hideHeading = false;
    @api customClass;
   
    
    get openerClasses(){
        return 'button-opener slds-align-middle slds-m-right_small ' + (this.expanded ? ' down ' : ' up ');
    }
    
    get expandedBoxClass(){
        return `impact-button-content ${this.customClass}`;
    }
    
    handleDropdownOpener(){
        this.expanded = !this.expanded;
    }
}
/**
 * Created by LukášGregora on 11/06/2021.
 */

public with sharing class FieldSetWrapper{
    @AuraEnabled public Boolean required {get;set;}
    @AuraEnabled public String label {get;set;}
    @AuraEnabled public String fieldPath {get;set;}
    @AuraEnabled public String displayType {get;set;}
    @AuraEnabled public List<PicklistValue> picklistValues {get;set;}

    public FieldSetWrapper(FieldSetMember fieldSetMember){
        this.required = fieldSetMember.getRequired();
        this.label = fieldSetMember.getLabel();
        this.fieldPath = fieldSetMember.getFieldPath();
        getDisplayType(fieldSetMember.getType(), fieldSetMember.getSObjectField());
    }

    public void getDisplayType(DisplayType displayType, SObjectField fieldDefinition){
        //TEMPORARY solution - after the SFDC Country/State picklist is enabled this could be removed
        if(this.fieldPath == 'Country__c'){
            this.displayType = 'picklist';
            return;
        }
        switch on displayType{
            when PICKLIST{
                this.displayType = 'picklist';
                this.picklistValues = PicklistValue.getPicklistValues(fieldDefinition.getDescribe().getPicklistValues());
            }
            when MULTIPICKLIST{
                this.displayType = 'multipicklist';
                this.picklistValues = PicklistValue.getPicklistValues(fieldDefinition.getDescribe().getPicklistValues());
            }
            when CURRENCY{
                this.displayType = 'currency';
            }
            when DATE{
                this.displayType = 'date';
            }
            when DATETIME{
                this.displayType = 'datetime';
            }
            when EMAIL{
                this.displayType = 'email';
            }
            when INTEGER,DOUBLE{
                this.displayType = 'number';
            }
            when PERCENT{
                this.displayType = 'percent';
            }
            when PHONE{
                this.displayType = 'tel';
            }
            when BOOLEAN{
                this.displayType = 'boolean';
            }
            when else{
                this.displayType = 'text';
            }
        }
    }
}

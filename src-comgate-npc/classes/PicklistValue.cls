/**
 * Created by LukášGregora on 10/06/2021.
 */

public with sharing class PicklistValue{
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;

    public PicklistValue(String label, String value){
        this.label = label;
        this.value = value;
    }

    public static List<PicklistValue> getPicklistValues(List<PicklistEntry> picklistEntries){
        List<PicklistValue> picklistValues = new List<PicklistValue>();
        for(PicklistEntry entry : picklistEntries){
            picklistValues.add(new PicklistValue(entry.getLabel(), entry.getValue()));
        }
        return picklistValues;
    }
}
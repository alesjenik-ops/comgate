/**
 * Created by LukášGregora on 13/06/2021.
 */

({
    onValueChange : function(component, event, helper){
        const value = event.getSource().get('v.value');
        const name = event.getSource().get('v.name');
        const donor = component.get('v.donor');
        donor[name] = value;
        component.set('v.donor', donor);
        component.set('v.selectedValue', value ? true : false)
    },
    
    onCheckedChange : function(component, event, helper){
        const value = event.getSource().get('v.checked');
        const name = event.getSource().get('v.name');
        const donor = component.get('v.donor');
        donor[name] = value;
        component.set('v.donor', donor);
    },
    
    validate : function(component, event, helper){
        const validateField = component.find("validateField");
        if(!validateField) return true;

        const fieldsToValidate = validateField.length ? validateField : [validateField];
        return fieldsToValidate.reduce((acc,field) => {
            field.showHelpMessageIfInvalid();
            return (field.get("v.validity") ? field.get("v.validity").valid : true) && acc;
        },true);
    },
    
    doInit : function(component, event, helper){
        const fieldPath = component.get('v.item.fieldPath');
        const donor = component.get('v.donor');
        component.find('validateField').set('v.value', donor[fieldPath]);
    },
});
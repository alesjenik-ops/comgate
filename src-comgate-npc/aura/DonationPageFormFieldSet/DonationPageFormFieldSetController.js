/**
 * Created by LukášGregora on 10/06/2021.
 */

({
    validate : function(component, event, helper){
        const validateCmp = component.find('cmpValidate').length ?  component.find('cmpValidate') : [component.find('cmpValidate')];
        const cmpValid = validateCmp.reduce((acc,item) =>  (item.validate ? item.validate() : true) && acc, true);
        
        const validateField = component.find("validateField");
        if(!validateField) return cmpValid;

        const fieldsToValidate = validateField.length ? validateField : [validateField];
        let validityOfFields = fieldsToValidate.reduce((acc,field) => {
            field.showHelpMessageIfInvalid();
            return (field.get("v.validity") ? field.get("v.validity").valid : true) && acc;
        },true);
       
        return validityOfFields && cmpValid;
    },
});
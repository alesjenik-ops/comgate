/**
 * Created by LukášGregora on 11/03/2021.
 */

({
    loadFieldSets : function(component, helper){
        component.set('v.spinner', true);
        const action = component.get('c.getFieldSetWrapper');
        action.setParams({
            fieldSetName : component.get('v.fieldSetSelection'),
            donorId : component.get('v.donor.Id'),
            campaignId : component.get('v.campaignId')
        });
        
        helper.doPromise(component, action, true)
        .then(resolve => {
            const resolveBody = JSON.parse(resolve);
            let campaignId = component.get('v.campaignId');
            if(resolveBody.donor) component.set('v.donor', resolveBody.donor);
            component.set('v.fieldSetWrapper', resolveBody.fieldSetWrapper);
            component.set('v.campaigns', resolveBody.campaigns);
            component.set('v.countryOptions', resolveBody.countryOptions);
             if(campaignId == null || campaignId == ''){
                 if(resolveBody.campaigns.length > 0) {
                     campaignId =  resolveBody.campaigns[0].Id;
                     component.set('v.campaignId', campaignId);
                     component.set('v.thankYouText', resolveBody.campaigns[0].Donation_Page_Thank_You_Text__c);
                     helper.setFieldsFromSelectedCampaign(component, campaignId);
                     window.setTimeout(
                         $A.getCallback(function() {
                                component.find("campaignChangeMessage").publish({recordId : campaignId});
                         }), 100
                     );
                 }
             } else {
                 helper.setFieldsFromSelectedCampaign(component, campaignId);
             }
        })
        .finally(() => {
            component.set('v.spinner', false);
            $A.util.addClass(component.find('loadingSpinner'), 'hidden');
        });
    },
    
    filterAllowedPaymentMethods : function(component){
        const defaultPaymentOption = component.get('v.defaultPaymentOption');
        const configObject = this.getPaymentOptionsConfigObject(component);
        
        const paymentOptions = component.get('v.paymentOptions').filter(item => configObject[item.value]);
        component.set('v.paymentOptions', paymentOptions);
        component.set('v.paymentWrapper.allowedPaymentMethods', paymentOptions.map(item => item.value, []));
        component.set('v.paymentWrapper.paymentOption', defaultPaymentOption);
    },
    
    filterAllowedDonationTypeOptions : function(component){
        const defaultDonationTypeOption = component.get('v.defaultDonationTypeOption');
        const configObject = {
            oneoff : component.get('v.donationTypeOption_oneOff'),
            recurring_monthly : component.get('v.donationTypeOption_monthly'),
            recurring_yearly : component.get('v.donationTypeOption_yearly'),
        }
        
        const donationTypeOptions = component.get('v.donationTypeOptions').filter(item => configObject[item.value]);
        component.set('v.donationTypeOptions', donationTypeOptions);
        component.set('v.paymentWrapper.donationType', defaultDonationTypeOption);
    },
    
    setDonationAmounts : function(component){
        component.set('v.donationOptions', this.getDefaultDonationAmounts(component));
        this.setDefaultDonationAmount(component, component.get('v.defaultDonationTypeOption'));
    },
    
    getDefaultDonationAmounts : function(component, additionalSettings){
        const donationOptions = component.get('v.donationOptions');
        this.filterDonationAmountOptions(donationOptions, 'oneoff', component.get('v.donationTypeOption_oneOff_amounts'), additionalSettings);
        this.filterDonationAmountOptions(donationOptions, 'recurring_monthly', component.get('v.donationTypeOption_monthly_amounts'), additionalSettings);
        this.filterDonationAmountOptions(donationOptions, 'recurring_yearly', component.get('v.donationTypeOption_yearly_amounts'), additionalSettings);
        return donationOptions;
    },
    
    filterDonationAmountOptions : function(donationOptions, type, selections, additionalSettings){
        const {symbol = 'Kč', conversionRate } = additionalSettings ? additionalSettings : {};
        donationOptions[type] = selections.split(';').map(item => {
            const itemValue = isNaN(item) || !conversionRate ? item : Math.round(item * conversionRate);
            return {'label': ((isNaN(itemValue) ? itemValue.toLowerCase() : itemValue) === 'other' ? 'Jiná' : itemValue + ' ' + symbol), 'value': itemValue}
        });
    },
    
    setDefaultDonationAmount : function(component, type){
        const donationOptions = component.get('v.donationOptions');
        if(!type){
            component.set('v.donationOptionSelected', ''); 
            component.set('v.paymentWrapper.donationValue', null); 
            return;
        }
                
        const actualDonationType = donationOptions[type];
        let amount = null;
        if(actualDonationType.length && actualDonationType.length > 1){
            amount = actualDonationType[1].value;
        } else if (actualDonationType.length && actualDonationType.length == 1){
            amount = actualDonationType[0].value;
        }
                
        component.set('v.donationOptionSelected', amount + ''); 
        component.set('v.paymentWrapper.donationValue', amount); 
    },
    
    applyUrlPrefill : function(component, helper){
        if(component.get('v.success')) return;

        const frequencyAliases = {
            oneoff : 'oneoff',
            once : 'oneoff',
            monthly : 'recurring_monthly',
            recurring_monthly : 'recurring_monthly',
            yearly : 'recurring_yearly',
            recurring_yearly : 'recurring_yearly'
        };
        const urlFrequency = helper.getUrlParameter('frequency');
        const donationType = frequencyAliases[String(urlFrequency || '').toLowerCase()];
        const allowedTypes = component.get('v.donationTypeOptions').map(item => item.value);
        if(donationType && allowedTypes.indexOf(donationType) !== -1){
            component.set('v.paymentWrapper.donationType', donationType);
            helper.setDefaultDonationAmount(component, donationType);
        }

        const urlAmount = helper.getUrlParameter('amount');
        if(urlAmount !== undefined){
            const normalized = String(urlAmount).replace(',', '.');
            const numericValue = parseFloat(normalized);
            if(!isNaN(numericValue) && numericValue > 0){
                const donationOptions = component.get('v.donationOptions')[component.get('v.paymentWrapper.donationType')] || [];
                const preset = donationOptions.find(item => !isNaN(item.value) && parseFloat(item.value) === numericValue);
                component.set('v.donationOptionSelected', preset ? preset.value + '' : 'other');
                component.set('v.paymentWrapper.donationValue', preset ? preset.value : normalized);
            }
        }

        const urlStep = helper.getUrlParameter('step');
        if((urlStep === '2' || urlStep === 'personDetails') && component.get('v.currentStep') === 'first'){
            const donationValue = parseFloat(String(component.get('v.paymentWrapper.donationValue')).replace(',', '.'));
            if(!isNaN(donationValue) && donationValue >= 15){
                component.set('v.currentStep', 'personDetails');
            }
        }
    },

    getPaymentOptionsConfigObject : function(component){
        return {
           card : component.get('v.paymentOption_card'),
           banktransfer : component.get('v.paymentOption_banktransfer')
       };
    },
    
    createRelatedRecords : function(component, event, paymentReferenceId, shopperReferenceId){
        const action = component.get('c.createRelatedRecords');
        action.setBackground();
        action.setParams({paymentReferenceId, shopperReferenceId});
        this.doPromise(component, action, false);
    },
    
    doPromise : function(component, action, handleErrors, debugMode){
        component.set('v.errorMessage',{message : '', type : ''});
        return new Promise(
            $A.getCallback((resolve, reject) => {
                action.setBackground();
                action.setCallback(this, response => {
                    const state = response.getState();
                    if(state === 'SUCCESS'){
                        resolve(response.getReturnValue());
                    } else {
                        if(handleErrors){
                            const errors = response.getError();
                            if(debugMode){
                                this.showToast('error',`Message: ${errors[0].message}, Stack trace: ${errors[0].stackTrace}`,'Error');
                            } else {
                                this.showToast('error',`Message: ${errors[0].message}`,'Error');
                            }
                        }

                        reject(response.getError());
                    }
                });
                $A.enqueueAction(action);
            }
        ));
    },
    
    validateForm : function(component, event, helper){
        const cmpForValidation = component.find('cmpValidate');
        const validateCmp = cmpForValidation && cmpForValidation.length ?  cmpForValidation : [cmpForValidation];
        const cmpValid = validateCmp.reduce((acc,item) => acc && (item && item.validate ? item.validate() : true), true);
        
        const validateField = component.find("validateField") || [];
        if(component.find('donationAmount')) validateField.push(component.find('donationAmount'));
        if(!validateField || validateField.length == 0) return cmpValid;

        const fieldsToValidate = validateField.length ? validateField : [validateField];
        let validityOfFields = fieldsToValidate.reduce((acc,field) => {
            field.showHelpMessageIfInvalid();
            return (field.get("v.validity") ? field.get("v.validity").valid : true) && acc;
        },true);
        
        return validityOfFields && cmpValid;
    },
    
    pushCheckoutDataLayer : function(component, recordId){
        const donor = component.get('v.donor');
        const paymentWrapper = component.get('v.paymentWrapper');
        
        //GTM
        const dataLayerObject = {
            'event' : 'checkout',
            'ecommerce' : {
                'checkout' : {
                    'actionField' : {
                        'step' : component.get('v.currentStep'), //ex. first;second;last
                        'option' : this.getPaymentType(component, paymentWrapper.paymentOption) //ex. creditcard
                    },
                    'products' : [
                        {
                            'name' : window.location.pathname, //ex. /s/adopt-bobby
                            'id' : this.getPaymentFrequency(component, paymentWrapper.donationType), //ex. once
                            'price' : paymentWrapper.donationValue, //ex. 100
                            'brand' : '',
                            'category' : this.getPaymentType(component, paymentWrapper.paymentOption), //ex. creditcard
                            'variant' : this.getPaymentFrequency(component, paymentWrapper.donationType), //ex. once
                            'quantity' : 1,
                            'coupon' : ''
                        }
                    ]
                }
            }
        };
        document.dispatchEvent(new CustomEvent("pushDataLayer", { "detail" : { event: dataLayerObject} }));
        
        
        //JENTIS
        const jentisObject = {
            event : 'begin_checkout',
            ecommerce : {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(component, paymentWrapper.donationType),
                payment_type: this.getPaymentType(component, paymentWrapper.paymentOption),
                items: [{
                    item_name: window.location.pathname,
                    currency: paymentWrapper.currencyIsoCode,
                    price: paymentWrapper.donationValue,
                    quantity: 1
                }]  
            }
        };
        document.dispatchEvent(new CustomEvent("user_interaction", { "detail" : jentisObject }));
    },
    
    pushPurchaseDataLayer : function(component){
        const dataLayerEvents = localStorage.getItem('dataLayerEvents') ? JSON.parse(localStorage.getItem('dataLayerEvents')) : null;
        if(dataLayerEvents){
            document.dispatchEvent(new CustomEvent("pushDataLayer", { "detail" : { event: dataLayerEvents.gtm} }));
            document.dispatchEvent(new CustomEvent("user_interaction", { "detail" : dataLayerEvents.jentis }));
            localStorage.removeItem('dataLayerEvents');
        }
    },
    
    
    storePurchaseDataLayer : function(component, recordId){
        const donor = component.get('v.donor');
        const paymentWrapper = component.get('v.paymentWrapper');

        localStorage.setItem('dataLayerEvents', JSON.stringify({
            gtm : this.purchaseGTMEvent(component, {recordId, donor, paymentWrapper}),
            jentis : this.purchaseJentisEvent(component, {recordId, donor, paymentWrapper})
        }));
    },
    
    purchaseGTMEvent : function(component, inputValues){
        const {recordId, donor, paymentWrapper} = inputValues;
        //GTM
        return {
            'event' : 'purchase',
            'ecommerce' : {
                'purchase' : {
                    'actionField' : {
                        'id' : recordId, // ex. 00x537UJFU2UI2
                        'affiliation' : '',
                        'revenue' : this.getTransactionTotal(component, paymentWrapper), //ex. 200
                        'tax' : '',
                        'shipping' : '',
                        'coupon' : ''
                    },
                    'products' : [{
                        'name' : window.location.pathname, //ex. /s/adopt-bobby
                        'id' : this.getPaymentFrequency(component, paymentWrapper.donationType), //ex. once
                        'category' : this.getPaymentType(component, paymentWrapper.paymentOption), //ex. creditcard
                        'brand' : '',
                        'price' : paymentWrapper.donationValue, //ex. 100
                        'variant' : this.getPaymentFrequency(component, paymentWrapper.donationType), //ex. once
                        'quantity' : 1, //constant
                        'coupon' : ''
                    }]
                }
            }
        };
    },
    
    purchaseJentisEvent : function(component, inputValues){
        const {recordId, donor, paymentWrapper} = inputValues;
        
        //jentis purchase
        return {
            event : 'Purchase',
            ecommerce : {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(component, paymentWrapper.donationType),
                payment_type: this.getPaymentType(component, paymentWrapper.paymentOption),
                items: [{
                    item_name: window.location.pathname,
                    currency: paymentWrapper.currencyIsoCode,
                    price: paymentWrapper.donationValue,
                    quantity: 1
                }]  
            }
        };
    },
   
    
    getTransactionTotal : function(component, paymentWrapper){
        switch(paymentWrapper.donationType) {
            case 'recurring_monthly':
            case 'recurring_yearly','oneoff':
                return paymentWrapper.donationValue;
            default:
                return 0;
        }
    },    
    
    getPaymentFrequency : function(component, donationType){
        switch(donationType) {
            case 'recurring_monthly':
                return 'monthly';
            case 'oneoff':
                return 'once';
            case 'recurring_yearly':
                return 'yearly';
            default:
                return '';
        }
    },   
    
    getPaymentType : function(component, paymentOption){
        switch(paymentOption) {
            case 'card':
                return 'creditcard';
            case 'paypal':
                return 'paypal';
            case 'sepadirectdebit':
                return 'directdebit';
            default:
                return '';
        }
    },
    
    showToast: function(type, title, message, mode){
        const toastEvent = $A.get("e.force:showToast");
        if(!toastEvent) {
            console.log(message);
            return;
        }
        toastEvent.setParams({
            title,
            type,
            message,
            mode,
        });
        toastEvent.fire();
    },
    
    getUrlParameter : function(sParam) {
        let sPageURL = decodeURIComponent(window.location.search.substring(1)),
            sURLVariables = sPageURL.split('&'),
            sParameterName,
            i;

        for (i = 0; i < sURLVariables.length; i++) {
            sParameterName = sURLVariables[i].split('=');
            if (sParameterName[0] === sParam) {
                return sParameterName[1] === undefined ? true : sParameterName[1];
            }
        }
    },
    
    justCreateRecords : function(component, event, helper){
        const paymentWrapper = component.get('v.paymentWrapper');
        const action = component.get('c.justCreateRecords');
        action.setParams({
            donorString : JSON.stringify(component.get('v.donor')),
            conString : JSON.stringify(component.get('v.contactPerson')),
            isPersonAccount : JSON.stringify(component.get('v.isPersonAccount')),
            campaignId : component.get('v.campaignId'),
            paymentWrapperString : JSON.stringify(paymentWrapper)});
        helper.doPromise(component, action, true)
        .then(resolve => {
            component.set('v.bankAccountDetails', resolve);
            component.set('v.currentStep', 'last');
            component.set('v.spinner', false);
        })
        .catch(e => {
        })
        .finally(() => {
            component.set('v.spinnerMessage', '');
            component.set('v.spinner', false);
        });
    },
    
    fireScrollDonationFormTop : function(component, event, helper){
        const appEvent = $A.get("e.c:DonationPageScrollEvent");
        appEvent.setParams({
            type : 'donationFormUp' 
        });
        appEvent.fire();
    },
    
    onError : function(component, error){
        error = error || {};
        console.error(error.name, error.message, error.stack, component);
        const paymentWrapper = component.get('v.paymentWrapper');
        const recordId = component.get('v.paymentReferenceId');
        
        //GTM
        const dataLayerObject = {
            'event' : 'donation_error',
            'error_code' : error.name,
            'error_message' : error.message,
            'error_stack' : error.stack,
            'ecommerce' : {
                'products' : [
                    {
                        'name' : window.location.pathname,
                        'id' : this.getPaymentFrequency(component, paymentWrapper.donationType),
                        'price' : paymentWrapper.donationValue,
                        'brand' : '',
                        'category' : this.getPaymentType(component, paymentWrapper.paymentOption),
                        'variant' : this.getPaymentFrequency(component, paymentWrapper.donationType),
                        'quantity' : 1,
                        'coupon' : ''
                    }
                ]
            }
        };
        document.dispatchEvent(new CustomEvent("pushDataLayer", { "detail" : { event: dataLayerObject} }));
        
        
        //JENTIS
        const jentisObject = {
            event : 'error',
            error_code : error.name,
            error_message : error.message,
            error_stack : error.stack,
            ecommerce : {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(component, paymentWrapper.donationType),
                payment_type: this.getPaymentType(component, paymentWrapper.paymentOption),
                items: [{
                    item_name: window.location.pathname,
                    currency: paymentWrapper.currencyIsoCode,
                    price: paymentWrapper.donationValue,
                    quantity: 1
                }]  
            }
        };
        document.dispatchEvent(new CustomEvent("user_interaction", { "detail" : jentisObject }));
    },
    
    addEventListeners : function(component, event, helper){
        window.addEventListener("message", function(event){
            if (event.data.id === 'onSuccessPage'){
                component.set('v.success', true);
                component.set('v.currentStep', 'last');
                helper.redirectToThankYouPage(component);
            }
        })
    },

    //When thankYouPageUrl is configured the donor leaves the form entirely instead of seeing the thank you step.
    //The in-form thank you step is set up by the caller first, so it stays visible if the navigation is refused.
    redirectToThankYouPage : function(component){
        const thankYouPageUrl = (component.get('v.thankYouPageUrl') || '').trim();
        if(!thankYouPageUrl) return false;

        try {
            //Break out of the payment gateway iframe - a same-window redirect would only swap the iframe content
            window.top.location.href = thankYouPageUrl;
        } catch (error) {
            window.location.href = thankYouPageUrl;
        }
        return true;
    },

    fillDefaultDonorData : function(component){
        const pageName = window.location.pathname.split('/').pop();
        if(pageName == 's' || pageName == '') {
            //component.set('v.donor.Donation_Page_Name__c', 'home');
            return;
        }
        //component.set('v.donor.Donation_Page_Name__c', pageName);
    },

    payByBankTransfer : function(component, event, helper){
        component.set('v.spinner', true);
        helper.justCreateRecords(component, event, helper);
        helper.fireScrollDonationFormTop(component, event, helper);
    },

    setFieldsFromSelectedCampaign : function(component, campaignId){
        if(campaignId == null) return;
         const options = component.get("v.campaigns");
         const selectedOption = options.find(function(option) {
             return option.Id === campaignId;
         });

         component.set('v.formHeaderLabel', selectedOption.Name);
         component.set('v.thankYouText', selectedOption.Donation_Page_Thank_You_Text__c);
    },

})
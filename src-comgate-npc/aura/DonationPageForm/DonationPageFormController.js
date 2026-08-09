({
    doInit : function(component, event, helper){
        const status = helper.getUrlParameter('status');
        const campaignId = helper.getUrlParameter('campaignId');
        const contactId = helper.getUrlParameter('contactId');
        
        if(contactId) component.set('v.donor.Id', contactId);
        if (window.frameElement){
            parent.postMessage({id : 'onSuccessPage', data : {isSuccess : true}}, '*');
            return;
        } else if(status && status === 'success' ) {
            component.set('v.success', true);
            component.set('v.currentStep', 'last');
            helper.pushPurchaseDataLayer(component);
        }
        if(campaignId) component.set('v.campaignId', campaignId);
        
        component.set('v.paymentWrapper.redirectURL', window.location.href);
        helper.loadFieldSets(component, helper);
        helper.filterAllowedPaymentMethods(component);
        helper.filterAllowedDonationTypeOptions(component);
        helper.setDonationAmounts(component);
        helper.addEventListeners(component, event, helper);
        
        component.set('v.helper', helper);
    },
               
    handleDonationOptionChanged : function(component, event, helper){
        const value = event.getSource().get('v.value');
        component.set('v.paymentWrapper.donationValue', isNaN(value) ? null : parseInt(value)); 
        if(value === 'other') {
            Promise.resolve(true)
            .then((resolve, reject) => {
                component.find('donationAmount').focus();
            })
        } else {
            component.find('donationAmount').reportValidity();
        }
       
    },
    
    //One-off, Monthly, Yearly           
    handleDonationTypeChanged : function(component, event, helper){
        const value = event.getSource().get('v.value');
        helper.setDefaultDonationAmount(component, value);
    },
    
    
    handleDonate : function(component, event, helper){
        if(!helper.validateForm(component, event, helper)) return;
        const currentStep = component.get('v.currentStep');

        if(currentStep === 'first'){
            component.set('v.currentStep', 'personDetails');
            helper.fireScrollDonationFormTop(component, event, helper);
            return;
        } else if (currentStep === 'personDetails'){
            component.set('v.currentStep', 'paymentMethodsSelection');
            helper.fireScrollDonationFormTop(component, event, helper);
            return;
        }  else if (currentStep === 'paymentMethodsSelection'){
              const paymentOption = component.get('v.paymentWrapper.paymentOption');
              if(paymentOption === 'bankTransfer'){
                  helper.payByBankTransfer(component, event, helper);
                  return;
              }
              component.set('v.currentStep', 'paymentMethods');
              helper.fireScrollDonationFormTop(component, event, helper);
        }
        
        component.set('v.spinner', true);
        component.set('v.spinnerMessage', 'processing');

        const action1 = component.get('c.getReferenceId');
        const action2 = component.get('c.createComgatePayment');
        const paymentWrapper = component.get('v.paymentWrapper');
        if(isNaN(paymentWrapper.donationValue)) paymentWrapper.donationValue = paymentWrapper.donationValue.replace(',','.');
                
        action1.setParams({
            donorString : JSON.stringify(component.get('v.donor')),
            conString : '{}',
            campaignId : component.get('v.campaignId'),
            paymentWrapperString : JSON.stringify(paymentWrapper),
            isPersonAccount : component.get('v.isPersonAccount')});
        helper.doPromise(component, action1)
        .then(resolve => {
            const responseObj = JSON.parse(resolve);
            component.set('v.paymentWrapper.shopperReferenceId', responseObj.shopperReferenceId);
            component.set('v.paymentWrapper.paymentReferenceId', responseObj.paymentReferenceId);

            action2.setParams({
                paymentReferenceId : responseObj.paymentReferenceId,
                donorString : JSON.stringify(component.get('v.donor')),
                campaignId : component.get('v.campaignId'),
                paymentWrapperString : JSON.stringify(component.get('v.paymentWrapper'))
            });
            helper.storePurchaseDataLayer(component, responseObj.paymentReferenceId);
            component.set('v.spinnerMessage', 'redirecting');
            return helper.doPromise(component, action2);
        })
        .then(resolve => {
            const paymentReferenceId = component.get('v.paymentWrapper.paymentReferenceId');
            const shopperReferenceId = component.get('v.paymentWrapper.shopperReferenceId');
            helper.createRelatedRecords(component, event, paymentReferenceId, shopperReferenceId);
            helper.pushCheckoutDataLayer(component, paymentReferenceId);
            
            if(resolve == null) {
                component.set('v.currentStep', 'paymentMethodsSelection');
                component.set('v.spinnerMessage', '');
                component.set('v.spinner', false);
                helper.showToast('error','Creation of payment session failed, please try it again. In case this error persist contact the ' + component.get('v.supportEmail'),'Error','sticky');
                return; //when the payment session creation failed
            }
            
            component.set('v.paymentUrl', resolve);
            
            window.setTimeout(
                $A.getCallback(function() {
                        component.set('v.spinnerMessage', '');
                        component.set('v.spinner', false);
                }), 1000
            );
            //helper.displayDropInComponent(component, event, helper);
            
        })
        .catch(e => {
            console.log(e);
            helper.showToast('error',`${e[0].message}`,'Error', 'sticky');
            helper.onError(component, {
                name : 'HandleDonate',
                message : (e.length ? e[0].message : e.message),
            });
            component.set('v.spinnerMessage', '');
            component.set('v.spinner', false);
            component.set('v.currentStep', 'personDetails');
        })
        .finally(() => {
        });
    },
    
    handleStepBack : function(component, event, helper){
        const currentStep = component.get('v.currentStep');
        if(currentStep === 'personDetails') {
            component.set('v.currentStep', 'first');
        } else if (currentStep === 'paymentMethodsSelection'){
            component.set('v.currentStep', 'personDetails');
        } else if (currentStep === 'paymentMethods'){
            component.set('v.paymentSessionConfiguration', null);
            component.set('v.currentStep', 'paymentMethodsSelection');
        }
        
    },
    
    handleDonationExpander : function(component, event, helper){
        component.set('v.donationWrapperOpened', !component.get('v.donationWrapperOpened'));
    },
    
    handleCurrencyChange : function(component, event, helper){
        const selectedCurrency = event.getSource().get('v.value');
        const currencyItem = component.get('v.currencies').find(item => item.label === selectedCurrency);
        const donationOptions = helper.getDefaultDonationAmounts(component, currencyItem);
        component.set('v.currentCurrencySymbol', currencyItem.symbol);
        component.set('v.donationOptions', donationOptions);
        helper.setDefaultDonationAmount(component, component.get('v.defaultDonationTypeOption'));
    }
});
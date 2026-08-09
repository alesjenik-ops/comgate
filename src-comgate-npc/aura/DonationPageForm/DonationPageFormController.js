({
    doInit : function(component, event, helper){
        const status = helper.getUrlParameter('status');
        const campaignId = helper.getUrlParameter('campaignId');
        const donorId = helper.getUrlParameter('donorId');
        
        if(donorId){
            component.set('v.donor.Id', donorId);
        } else {
            helper.fillDefaultDonorData(component);
        }
        if (window.frameElement){
            parent.postMessage({id : 'onSuccessPage', data : {isSuccess : true}}, '*');
            return;
        }
        if(status && status === 'success' ) {
            component.set('v.success', true);
            component.set('v.currentStep', 'last');
            helper.pushPurchaseDataLayer(component);
        }
        if(campaignId) component.set('v.campaignId', campaignId);

        //If we have campaignId from the url or component design parameter
        if(component.get('v.campaignId')){
            window.setTimeout(
                $A.getCallback(function() {
                        component.find("campaignChangeMessage").publish({recordId : component.get('v.campaignId')});
                }), 100
            );
        }

        component.set('v.paymentWrapper.redirectURL', location.protocol + '//' + location.host + location.pathname);
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
        } else if (currentStep === 'paymentMethodsSelection'){
            const paymentOption = component.get('v.paymentWrapper.paymentOption');
            if(paymentOption === 'banktransfer'){
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
            conString : JSON.stringify(component.get('v.contactPerson')),
            isPersonAccount : JSON.stringify(component.get('v.isPersonAccount')),
            campaignId : component.get('v.campaignId'),
            paymentWrapperString : JSON.stringify(paymentWrapper)});
        let shopperReference;
        helper.doPromise(component, action1)
        .then(resolve => {
            const responseObj = JSON.parse(resolve);
            shopperReference = responseObj.shopperReference;
            if(!component.get('v.isPersonAccount')) {
                component.set('v.donor.PersonEmail', component.get('v.contactPerson.Email'));
            }
            action2.setParams({
                paymentReferenceId : responseObj.paymentReference,
                donorString : JSON.stringify(component.get('v.donor')),
                campaignId : component.get('v.campaignId'),
                paymentWrapperString : JSON.stringify(component.get('v.paymentWrapper'))
            });
            helper.storePurchaseDataLayer(component, responseObj.paymentReference);
            component.set('v.spinnerMessage', 'redirecting');  
            return helper.doPromise(component, action2);
        })
        .then(resolve => {
            const paymentReferenceId = action2.getParam('paymentReferenceId');
            const shopperReferenceId = shopperReference;
            component.set('v.paymentReferenceId', paymentReferenceId)
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
            component.set('v.currentStep', 'paymentMethodsSelection');
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
            component.set('v.paymentUrl', null);
            component.set('v.currentStep', 'paymentMethodsSelection');
        }
        
    },
    
    handleDonationExpander : function(component, event, helper){
        component.set('v.donationWrapperOpened', !component.get('v.donationWrapperOpened'));
    },

    handleCampaignChange : function(component, event, helper){
        const campaignId = event.getSource().get('v.value');
        component.find("campaignChangeMessage").publish({recordId : campaignId});

        helper.setFieldsFromSelectedCampaign(component, campaignId);
    },

    handleAccountTypeChange : function(component, event, helper){
        const value = event.getParam('value');
        component.set('v.isPersonAccount', value === 'person');
        component.set('v.donor', {'sobjectType': 'Account'});
        component.set('v.contactPerson', {'sobjectType': 'Contact'});
    },
});
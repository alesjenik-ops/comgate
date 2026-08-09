/**
 * Created by LukášGregora on 04/05/2022.
 */

({
    doInit : function(component, event, helper){
        window.addEventListener('resize', (event) => {
        });
        
        window.addEventListener('scroll', (event) => {
            component.set('v.showDonateButton', component.find('donationForm').getElement() != null &&  component.find('donationForm').getElement().getBoundingClientRect().bottom < 0);
        });

        helper.setBaseColor(component);
    },
    
    handleDonateNow : function(component, event, helper){
       window.scrollTo({top:component.find('donationForm').getElement().offsetTop, 'behavior' :'smooth'});
    },
    
    handleScrollEvent : function(component, event, helper){
        const type = event.getParam('type');
        switch (type) {
            case 'donationFormUp':
               window.scrollTo({top:0, 'behavior' :'smooth'});
        }
    }
});
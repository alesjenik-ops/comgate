public with sharing class ComgateService {
    public static ComgatePaymentResponseWrapper getPayment(ComgatePaymentRequestWrapper requestWrapper){
        System.debug(requestWrapper);
        HttpResponse res = ComgateCallouts.doCallout(
                ComgateCallouts.URL_PAYMENT,
                'POST',
                JSON.serialize(requestWrapper));
        if(res.getStatusCode() == 201){
            ComgatePaymentResponseWrapper responseWrapper = (ComgatePaymentResponseWrapper) JSON.deserialize(res.getBody(), ComgatePaymentResponseWrapper.class);
            System.debug(res.getBody());
            return responseWrapper;
        } else if (res.getStatusCode() == 400) {
            ComgatePaymentResponseWrapper responseWrapper = (ComgatePaymentResponseWrapper) JSON.deserialize(res.getBody(), ComgatePaymentResponseWrapper.class);
            throw new ComgateServiceException('Error code: ' + responseWrapper.code + ', Message: ' + responseWrapper.message + '. Please contact us to resolve the issue.');
        } else {
            return null;
        }
    }

    public static ComgatePaymentResponseWrapper getRecurringPayment(ComgateRecurringRequestWrapper requestWrapper){
        System.debug(requestWrapper);
        HttpResponse res = ComgateCallouts.doCallout(
                ComgateCallouts.URL_RECURRING,
                'POST',
                JSON.serialize(requestWrapper));
        ComgatePaymentResponseWrapper responseWrapper;
        if(res.getStatusCode() == 200){
            responseWrapper = (ComgatePaymentResponseWrapper) JSON.deserialize(res.getBody(), ComgatePaymentResponseWrapper.class);
            System.debug(res.getBody());
        } else if (res.getStatusCode() == 400) {
            responseWrapper = (ComgatePaymentResponseWrapper) JSON.deserialize(res.getBody(), ComgatePaymentResponseWrapper.class);
            System.debug(res.getBody());
            //throw new ComgateServiceException('Error code: ' + responseWrapper.code + ', Message: ' + responseWrapper.message + '. Please contact us to resolve the issue.');
        }
        return responseWrapper;
    }

    public static ComgatePaymentStatusResponseWrapper getPaymentStatus(String transactionId){
        HttpResponse res = ComgateCallouts.doCallout(
                ComgateCallouts.URL_PAYMENT_STATUS + transactionId + '.json',
                'GET',
                null);
        if(res.getStatusCode() == 200){
            ComgatePaymentStatusResponseWrapper responseWrapper = (ComgatePaymentStatusResponseWrapper) JSON.deserialize(res.getBody(), ComgatePaymentStatusResponseWrapper.class);
            System.debug(res.getBody());
            return responseWrapper;
        } else {
            return null;
        }
    }

    private class ComgateServiceException extends Exception{}
}
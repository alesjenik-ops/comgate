//https://stripe.com/docs/api/errors
public virtual class StripeErrorResponseWrapper {
    public ErrorWrapper error;
    
    public class ErrorWrapper{
        public String code;
        public String doc_url;
        public String message;
        public String type;
        public String decline_code;
        public String param;
    }
}
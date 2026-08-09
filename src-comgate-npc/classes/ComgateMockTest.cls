@IsTest
public with sharing class ComgateMockTest {
    public static final String TRANS_ID = 'AB12-CD34-EF56';
    public static final String REDIRECT_URL = 'https://payments.comgate.cz/client/instructions/index?id=AB12-CD34-EF56';
    public static final Integer ERROR_CODE = 1400;
    public static final String ERROR_MESSAGE = 'unauthorized location or wrong secret';

    public class PaymentCreatedResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                    'code' => 0,
                    'message' => 'OK',
                    'transId' => TRANS_ID,
                    'redirect' => REDIRECT_URL
            }));
            return res;
        }
    }

    public class RecurringCreatedResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                    'transId' => TRANS_ID
            }));
            return res;
        }
    }

    public class ErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                    'code' => ERROR_CODE,
                    'message' => ERROR_MESSAGE
            }));
            return res;
        }
    }

    public class ServerErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    public class PaymentStatusResponse implements HttpCalloutMock {
        private final String status;

        public PaymentStatusResponse(String status) {
            this.status = status;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                    'code' => 0,
                    'message' => 'OK',
                    'transId' => TRANS_ID,
                    'status' => this.status,
                    'price' => 20000,
                    'curr' => 'CZK',
                    'method' => 'CARD_CZ_COMGATE',
                    'vs' => '1234567890'
            }));
            return res;
        }
    }
}

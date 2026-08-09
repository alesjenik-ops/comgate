@IsTest
public with sharing class StripeWebhookTest {
    private static final String STRIPE_SIGNATURE = 't=1705264216,v1=cff9c806295383e7b19286f79a48ac5dd301e83d4a2c68c817fb441c27ef1663,v0=c338225229f58ea92ef9f6ecf26600091ec247bcb6379b5a000dc56a0f44548f';
    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Account donor = StripeTestFactory.getDonor();
        insert donor;

        GiftTransaction giftTransaction = StripeTestFactory.getGiftTransaction(donor.Id, 'Pledged');
        insert giftTransaction;
    }

    @IsTest
    public static void test_invalidHmac(){
        StripeWebhookWrapper notification = new StripeWebhookWrapper();

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(notification));
        req.headers.put('Stripe-Signature', STRIPE_SIGNATURE);
        RestContext.request = req;

        RestContext.response = new RestResponse();

        Test.startTest();
        StripeWebhook.doPost();
        Test.stopTest();

        RestResponse resp = RestContext.response;
        System.assertEquals(200, resp.statusCode);
        System.assertEquals(0, [SELECT Id FROM Payment_Log__c].size());
    }

    @IsTest
    public static void test_validHmac(){
        Test.startTest();
        Boolean hmacResult = StripeWebhook.checkHmac(
                STRIPE_SIGNATURE,
                SESSION_SUCCESS_PAYLOAD
        );
        Test.stopTest();
        
        Assert.isTrue(hmacResult);
    }

    @IsTest
    public static void test_validMessage(){
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(SESSION_SUCCESS_PAYLOAD);
        req.headers.put('Stripe-Signature', STRIPE_SIGNATURE);
        RestContext.request = req;

        RestContext.response = new RestResponse();

        Test.startTest();
        StripeWebhook.doPost();
        Test.stopTest();

        RestResponse resp = RestContext.response;
        System.assertEquals('[accepted]', resp.responseBody.toString());
        System.assertEquals(200, resp.statusCode);
        System.assertEquals(1, [SELECT Id FROM Payment_Log__c].size());
    }
    
    
    private static final String SESSION_SUCCESS_PAYLOAD = '{\n' +
            '  "id": "evt_1OYA5ELqN4DuZlYxb9eT4AYc",\n' +
            '  "object": "event",\n' +
            '  "api_version": "2023-10-16",\n' +
            '  "created": 1705163360,\n' +
            '  "data": {\n' +
            '    "object": {\n' +
            '      "id": "cs_test_a101pUeMXfCLGL2NwNAYU3Y0Oc3sbdqKEqFJJ80oYNV3g98XeoDLZNTbiB",\n' +
            '      "object": "checkout.session",\n' +
            '      "after_expiration": null,\n' +
            '      "allow_promotion_codes": null,\n' +
            '      "amount_subtotal": 5000,\n' +
            '      "amount_total": 5000,\n' +
            '      "automatic_tax": {\n' +
            '        "enabled": false,\n' +
            '        "status": null\n' +
            '      },\n' +
            '      "billing_address_collection": null,\n' +
            '      "cancel_url": null,\n' +
            '      "client_reference_id": "a1gUC000000MWVtYAO",\n' +
            '      "client_secret": null,\n' +
            '      "consent": null,\n' +
            '      "consent_collection": null,\n' +
            '      "created": 1705163343,\n' +
            '      "currency": "eur",\n' +
            '      "currency_conversion": null,\n' +
            '      "custom_fields": [\n' +
            '\n' +
            '      ],\n' +
            '      "custom_text": {\n' +
            '        "after_submit": null,\n' +
            '        "shipping_address": null,\n' +
            '        "submit": null,\n' +
            '        "terms_of_service_acceptance": null\n' +
            '      },\n' +
            '      "customer": "cus_PC2NNWLbuFvXVd",\n' +
            '      "customer_creation": null,\n' +
            '      "customer_details": {\n' +
            '        "address": {\n' +
            '          "city": null,\n' +
            '          "country": "CZ",\n' +
            '          "line1": null,\n' +
            '          "line2": null,\n' +
            '          "postal_code": null,\n' +
            '          "state": null\n' +
            '        },\n' +
            '        "email": "tst@test.test",\n' +
            '        "name": "TEST",\n' +
            '        "phone": null,\n' +
            '        "tax_exempt": "none",\n' +
            '        "tax_ids": [\n' +
            '\n' +
            '        ]\n' +
            '      },\n' +
            '      "customer_email": null,\n' +
            '      "expires_at": 1705249743,\n' +
            '      "invoice": null,\n' +
            '      "invoice_creation": {\n' +
            '        "enabled": false,\n' +
            '        "invoice_data": {\n' +
            '          "account_tax_ids": null,\n' +
            '          "custom_fields": null,\n' +
            '          "description": null,\n' +
            '          "footer": null,\n' +
            '          "metadata": {\n' +
            '          },\n' +
            '          "rendering_options": null\n' +
            '        }\n' +
            '      },\n' +
            '      "livemode": false,\n' +
            '      "locale": null,\n' +
            '      "metadata": {\n' +
            '        "payment_reference": "a1gUC000000MWVtYAO"\n' +
            '      },\n' +
            '      "mode": "payment",\n' +
            '      "payment_intent": "pi_3OYA56LqN4DuZlYx1i7JoK7A",\n' +
            '      "payment_link": null,\n' +
            '      "payment_method_collection": "if_required",\n' +
            '      "payment_method_configuration_details": {\n' +
            '        "id": "pmc_1OG0dLLqN4DuZlYxRTOWbb3O",\n' +
            '        "parent": null\n' +
            '      },\n' +
            '      "payment_method_options": {\n' +
            '      },\n' +
            '      "payment_method_types": [\n' +
            '        "card",\n' +
            '        "paypal"\n' +
            '      ],\n' +
            '      "payment_status": "paid",\n' +
            '      "phone_number_collection": {\n' +
            '        "enabled": false\n' +
            '      },\n' +
            '      "recovered_from": null,\n' +
            '      "redirect_on_completion": "always",\n' +
            '      "return_url": "https://four-paws--stripe.sandbox.my.site.com/donation/s/?status=success",\n' +
            '      "setup_intent": null,\n' +
            '      "shipping_address_collection": null,\n' +
            '      "shipping_cost": null,\n' +
            '      "shipping_details": null,\n' +
            '      "shipping_options": [\n' +
            '\n' +
            '      ],\n' +
            '      "status": "complete",\n' +
            '      "submit_type": "donate",\n' +
            '      "subscription": null,\n' +
            '      "success_url": null,\n' +
            '      "total_details": {\n' +
            '        "amount_discount": 0,\n' +
            '        "amount_shipping": 0,\n' +
            '        "amount_tax": 0\n' +
            '      },\n' +
            '      "ui_mode": "embedded",\n' +
            '      "url": null\n' +
            '    }\n' +
            '  },\n' +
            '  "livemode": false,\n' +
            '  "pending_webhooks": 1,\n' +
            '  "request": {\n' +
            '    "id": null,\n' +
            '    "idempotency_key": null\n' +
            '  },\n' +
            '  "type": "checkout.session.completed"\n' +
            '}';
}
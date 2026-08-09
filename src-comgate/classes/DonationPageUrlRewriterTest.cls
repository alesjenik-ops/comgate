@IsTest
public with sharing class DonationPageUrlRewriterTest {

    @IsTest
    public static void test_mapRequestUrl(){
        PageReference pageRef = new PageReference('http://test.test/apple-developer-merchantid-domain-association');
        
        Test.startTest();
        PageReference pageRefResult = new DonationPageUrlRewriter().mapRequestUrl(pageRef);
        Test.stopTest();
        
        Assert.areEqual(Page.ResourceReader.getUrl(), pageRefResult.getUrl());
    }

    @IsTest
    public static void test_generateUrlFor(){
        PageReference pageRef = new PageReference('http://test.test/apple-developer-merchantid-domain-association');

        Test.startTest();
        List<PageReference> pageRefResults = new DonationPageUrlRewriter().generateUrlFor(new List<PageReference>{pageRef});
        Test.stopTest();

        Assert.areEqual(Page.ResourceReader.getUrl(), pageRefResults[0].getUrl());
    }
}
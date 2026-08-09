global class DonationPageUrlRewriter implements Site.UrlRewriter{
    global PageReference mapRequestUrl(PageReference myFriendlyUrl){
        String url = myFriendlyUrl.getUrl();
        if(url.contains('apple-developer-merchantid-domain-association')){
            return Page.ResourceReader;
        }

        //If the URL isn't in the form of a contact or
        //account page, continue with the request
        return null;
    }
    
    global PageReference[] generateUrlFor(PageReference[] mySalesforceUrls){
        List<PageReference> myFriendlyUrls = new List<PageReference>();

        for(PageReference mySalesforceUrl : mySalesforceUrls){
            PageReference pageRef = mapRequestUrl(mySalesforceUrl);
            if(pageRef != null) myFriendlyUrls.add(pageRef);
        }
        return myFriendlyUrls;
    }
}
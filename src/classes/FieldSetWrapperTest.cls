@IsTest
public with sharing class FieldSetWrapperTest {

    @IsTest
    public static void test_getDisplayType(){
        Test.startTest();
        FieldSetWrapper fsw = new FieldSetWrapper(null);
        fsw.getDisplayType(DisplayType.PICKLIST, Account.FirstName);
        fsw.getDisplayType(DisplayType.MULTIPICKLIST,  Account.FirstName);
        fsw.getDisplayType(DisplayType.CURRENCY,  Account.FirstName);
        fsw.getDisplayType(DisplayType.DATE,  Account.FirstName);
        fsw.getDisplayType(DisplayType.DATETIME,  Account.FirstName);
        fsw.getDisplayType(DisplayType.EMAIL,  Account.FirstName);
        fsw.getDisplayType(DisplayType.INTEGER,  Account.FirstName);
        fsw.getDisplayType(DisplayType.DOUBLE,  Account.FirstName);
        fsw.getDisplayType(DisplayType.PERCENT,  Account.FirstName);
        fsw.getDisplayType(DisplayType.PHONE,  Account.FirstName);
        fsw.getDisplayType(DisplayType.BOOLEAN,  Account.FirstName);
        fsw.getDisplayType(DisplayType.BASE64,  Account.FirstName);
        Test.stopTest();
    }
    
    @IsTest
    public static void test_getPicklistValues(){
        Test.startTest();
        PicklistValue.getPicklistValues(Account.PersonGenderIdentity.getDescribe().getPicklistValues());
        Test.stopTest();
    }
}
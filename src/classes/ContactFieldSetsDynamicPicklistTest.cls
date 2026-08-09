@IsTest
public with sharing class ContactFieldSetsDynamicPicklistTest {
    
    @IsTest
    public static void test_getDefaultValue(){
        Test.startTest();
        VisualEditor.DataRow defaultValue = new ContactFieldSetsDynamicPicklist().getDefaultValue();
        Test.stopTest();
        
        Assert.isNotNull(defaultValue);
    }
    
    @IsTest
    public static void test_getValues(){
        Test.startTest();
        VisualEditor.DynamicPickListRows picklistRows = new ContactFieldSetsDynamicPicklist().getValues();
        Test.stopTest();
        
        Assert.isNotNull(picklistRows);
    }
}
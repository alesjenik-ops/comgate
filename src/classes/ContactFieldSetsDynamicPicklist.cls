/**
 * Created by LukášGregora on 10/06/2021.
 */

public with sharing class ContactFieldSetsDynamicPicklist extends VisualEditor.DynamicPickList{
    public override VisualEditor.DataRow getDefaultValue(){
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow('', '');
        return defaultValue;
    }
    
    public override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows  myValues = new VisualEditor.DynamicPickListRows();
        for(FieldSet fs : Account.SObjectType.getDescribe().fieldSets.getMap().values()){
            if(fs.getNameSpace() != null) continue;
            myValues.addRow(new VisualEditor.DataRow(fs.getLabel(), fs.getName()));
        }
        return myValues;
    }
}
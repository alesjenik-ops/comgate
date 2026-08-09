import { LightningElement, api } from 'lwc';
import qrcode from './qrcode.js';


export default class QrCodeGenerator extends LightningElement {

    @api payload;

    renderedCallback() {
        const qrCodeGenerated = new qrcode(0, 'H');
        qrCodeGenerated.addData(this.payload);
        qrCodeGenerated.make();
        let element = this.template.querySelector(".qrcode2");
        element.innerHTML = qrCodeGenerated.createSvgTag({});
    }
}
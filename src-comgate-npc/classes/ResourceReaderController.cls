/**
 * Created by LukášGregora on 12/01/2024.
 */

public with sharing class ResourceReaderController {
    public String getContent() {
        return new PageReference('/resource/AppleVerification').getContent().toString();
    }
}
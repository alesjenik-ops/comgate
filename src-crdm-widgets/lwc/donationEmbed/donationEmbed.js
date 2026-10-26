// Pomocne funkce pro vlozeni darovaciho widgetu do ciziho webu pres iframe.
// Hostitelska stranka posloucha zpravy dkdResize (vyska obsahu, bez scrollbaru)
// a dkdNavigate (prejit v hlavnim okne na URL - platebni brana, dekovaci stranka).

// In-app prohlizece socialnich siti: v iframe v nich nefunguje 3D Secure (banka otvira
// okno nebo aplikaci, ktere webview z vnoreneho iframe nepusti), brana proto musi bezet v hlavnim okne.
const IN_APP_UA = /Instagram|FBAN|FBAV|FB_IAB|FBIOS|Messenger|musical_ly|BytedanceWebview|TikTok|LinkedInApp|Snapchat|Pinterest|Twitter|Line\//i;

export function isInAppBrowser() {
    return typeof navigator !== 'undefined' && IN_APP_UA.test(navigator.userAgent || '');
}

// Bezi stranka uvnitr iframe (typicky vlozena na webu darujemekrouzky.cz)?
export function isEmbedded() {
    try {
        return window.self !== window.top;
    } catch (e) {
        return true;
    }
}

// Brana v hlavnim okne: v in-app prohlizeci vzdy, v gatewayMode=redirect taky.
// gatewayMode=iframe necha branu vzdy v iframe (puvodni chovani).
export function shouldRedirectToGateway(gatewayMode) {
    if (gatewayMode === 'redirect') return true;
    if (gatewayMode === 'iframe') return false;
    return isInAppBrowser();
}

// Navigace hlavniho okna. Z cross-origin iframe ji browser bez user gesture blokuje,
// proto nejdriv pozadame hostitelskou stranku (embed skript) a az pak zkusime sami.
export function navigateTop(url) {
    if (!url) return;
    if (!isEmbedded()) {
        window.location.href = url;
        return;
    }
    window.parent.postMessage({ id: 'dkdNavigate', url }, '*');
    // Kdyz hostitel skript nema, zkusime top navigaci primo; selze-li, aspon nove okno
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    window.setTimeout(() => {
        try {
            window.top.location.href = url;
        } catch (e) {
            window.open(url, '_blank');
        }
    }, 300);
}

// Posila hostitelske strance vysku obsahu, aby iframe nemel vlastni scrollbar.
// Vraci funkci pro odpojeni.
export function startHeightReporting(element) {
    if (!isEmbedded() || typeof ResizeObserver === 'undefined' || !element) return () => {};
    let last = 0;
    const send = () => {
        const height = Math.ceil(element.getBoundingClientRect().height);
        if (height && height !== last) {
            last = height;
            window.parent.postMessage({ id: 'dkdResize', height }, '*');
        }
    };
    const observer = new ResizeObserver(send);
    observer.observe(element);
    send();
    return () => observer.disconnect();
}
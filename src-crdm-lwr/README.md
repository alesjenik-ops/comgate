# Darovací stránky CRDM na LWR

Nová Experience Cloud site **Darci LWR** postavená na LWR (Build Your Own LWR). Funguje
a vypadá stejně jako původní Aura site `Donation_Page1` (darci.darujemekrouzky.cz).
Nasazuje se jako **unmanaged metadata přímo do CRDM orgu**.

Adresa: `https://czechcouncilofchildrenandyouth.my.site.com/darci/`

| Složka | Co obsahuje |
| --- | --- |
| `src-crdm-lwr/` | LWC komponenty hlavní stránky a CSS (tahle složka) |
| `src-site-crdm-lwr/` | DigitalExperienceBundle `site/Darci_LWR1` a Network `Darci LWR` – stránky, cesty, layout |
| `src-crdm-widgets/` | sdílené widgety (`donationWidget`, `donationThankYou`, …) a modul `donationEmbed` |

## Komponenty

| Komponenta | Účel |
| --- | --- |
| `dkdDonationPage` | Hlavní stránka: hlavička, formulář, popis kampaně, patička. Port Aura theme layoutu `DonationPageLayout` a komponent `DonationPageHeader`, `donationPageCampaignDetail` a `DonationPageFooter`. |
| `dkdDonationForm` | Port Aura `DonationPageForm` (kroky částka → údaje → způsob platby → brána → poděkování), včetně událostí GTM/Jentis. |
| `dkdThemeLayout` | Prázdný theme layout bez hlavičky a patičky. Výchozí LWR layout přidává nahoře a dole 16px pruh, který ve vloženém iframe dělal bílý okraj. |
| `DkdLwrSiteCss` | Kopie `DonationPageCss` bez `@font-face` (fonty vstřikuje `donationFonts`, relativní cesty ke static resource v LWR nefungují). |

Komponenty běží v **light DOM**, aby původní Aura CSS (`.THIS` → `.dkd-form`, `.dkd-header`…)
sedělo na stejný DOM.

## Stránky

| URL | Komponenta | Poznámka |
| --- | --- | --- |
| `/darci/` | `dkdDonationPage` | kampaň `701Te00000gDlc7IAC`, částky 500/1000/1500/jiná |
| `/darci/widget-popup` | `donationWidget` | stejné nastavení jako na staré site |
| `/darci/widget-landing` | `donationWidget` | |
| `/darci/widget-darci` | `donationWidget` | děkovací URL vede na `/darci/dekujeme` |
| `/darci/widget-krouzek-landing` | `donationWidget` | personalizace `?krouzek=` |
| `/darci/widget-krouzek-popup` | `donationWidget` | |
| `/darci/dekujeme` | `donationThankYou` | |
| `/darci/obchodni-podminky` | `donationPageLegal` | `terms` |
| `/darci/ochrana-osobnich-udaju` | `donationPageLegal` | `privacy` |

Guest user site má profil **Darci LWR Profile** (přístup ke třídám Comgate a `DonationPageController`)
a permission sety `Comgate_Integration_Guest` a `DKD_Thank_You_Automation`.

## Nasazení

Pořadí: `src-crdm-widgets` → `src-crdm-lwr` → `src-site-crdm-lwr`, potom publikovat site.

```
sf project deploy start --metadata-dir src-crdm-widgets -o crdm
sf project deploy start --metadata-dir src-crdm-lwr -o crdm
sf project deploy start --metadata-dir src-site-crdm-lwr -o crdm
sf community publish -n "Darci LWR" -o crdm
```

Vlastní cesty v DigitalExperienceBundle musí mít ID s příponou `__c` (`Widget_Popup__c`),
jinak deploy selže.

## Vložení na web (iframe bez scrollbarů, 3D Secure v Instagramu)

### Proč ne Lightning Out

Lightning Out 2.0 nepodporuje nepřihlášené (guest) uživatele, vyžaduje cookies třetích stran
a každou komponentu stejně vykreslí v iframe. Pro veřejný darovací formulář se nehodí.
Správná cesta je obyčejný iframe a malý skript na hostitelské stránce.

### Jednorázové nastavení v orgu (ručně, API to neumí)

Experience Builder → site **Darci LWR** → Settings → Security & Privacy →
**Clickjack Protection Level: Allow framing by any page** → Publish.
Bez toho prohlížeč iframe na cizím webu zablokuje (`X-Frame-Options: SAMEORIGIN`).

### Kód pro web

```html
<iframe id="dkd-darovani"
        src="https://czechcouncilofchildrenandyouth.my.site.com/darci/widget-landing"
        style="display:block;width:100%;height:420px;border:0;overflow:hidden"
        scrolling="no" allow="payment" title="Darovací formulář"></iframe>
<script>
(function () {
  var SITE = 'https://czechcouncilofchildrenandyouth.my.site.com';
  // Kam smi widget poslat hlavni okno: platebni brana Comgate a nase stranky
  var ALLOWED = /^https:\/\/(payments\.comgate\.cz|pay1\.comgate\.cz|czechcouncilofchildrenandyouth\.my\.site\.com|(www\.)?darujemekrouzky\.cz)\//;
  var frame = document.getElementById('dkd-darovani');
  // UTM a dalsi parametry z adresy stranky predame widgetu
  if (location.search) frame.src += (frame.src.indexOf('?') < 0 ? '?' : '&') + location.search.slice(1);
  window.addEventListener('message', function (e) {
    if (e.origin !== SITE || !e.data) return;
    if (e.data.id === 'dkdResize') frame.style.height = e.data.height + 'px';
    if (e.data.id === 'dkdNavigate' && ALLOWED.test(e.data.url)) window.location.href = e.data.url;
  });
})();
</script>
```

Pro jiný widget stačí změnit `src` (`widget-popup`, `widget-krouzek-landing?krouzek=hudba`, …).
V modálním popup okně webu se vkládá stejný kód.

### Jak to funguje

- **Scrollbary:** widget přes `ResizeObserver` posílá zprávu `dkdResize` s výškou obsahu
  a skript nastaví výšku iframe. Iframe má `scrolling="no"`, takže scrollbar nevznikne
  ani při přechodu na delší krok formuláře.
- **3D Secure v Instagramu:** v in-app prohlížečích (Instagram, Facebook, Messenger, TikTok,
  LinkedIn…) se brána Comgate neotevře v iframe, ale v **hlavním okně** (zpráva `dkdNavigate`).
  Ve vnořeném iframe webview neotevře okno nebo aplikaci banky a ověření 3DS se zasekne.
  Po zaplacení vrátí Comgate dárce na stránku widgetu (`?status=success`) a ten ho přesměruje
  na děkovací stránku.
- **Ostatní prohlížeče:** brána zůstává v iframe jako dosud (Apple Pay a Google Pay díky `allow="payment"`).

Chování řídí vlastnost **Platební brána** (`gatewayMode`) na widgetu v Experience Builderu:
`auto` (výchozí), `iframe` (vždy v iframe), `redirect` (vždy v hlavním okně). Kdyby se 3DS
zasekávalo i jinde, přepni na `redirect`.

Bez skriptu na hostitelské stránce widget zkusí navigovat hlavní okno sám
a když to prohlížeč zablokuje, otevře bránu v novém okně. Skript je ale potřeba kvůli výšce.

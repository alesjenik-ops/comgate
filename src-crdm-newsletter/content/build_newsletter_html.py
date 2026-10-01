import html, re

def urls(path):
    out = {}
    for line in open(path, encoding='utf-8'):
        _, name, url = line.strip().split('|', 2)
        out[name] = html.escape(url, quote=True)
    return out

u = urls('dist.txt')
u.update(urls('disth.txt'))
LOGO = u['newsletter-dkd-jeden-klik-html-logo']
KOLAZ = u['newsletter-dkd-jeden-klik-06-kolaz']
MAPA = u['newsletter-dkd-jeden-klik-html-mapa']
GRAF = u['newsletter-dkd-jeden-klik-html-aktivity-kolac']

JEDENKLIK = 'https://www.darujemekrouzky.cz/jedenklik/'
VIDEO = 'https://www.youtube.com/watch?v=H9NI9qgVSnU'
FB = 'https://www.facebook.com/darujemekrouzkydetem'
IG = 'https://www.instagram.com/darujeme_krouzky/'
LI = 'https://cz.linkedin.com/company/crdm-cz'

PLUM = '#382133'
HEAD = '#312030'
DARK = '#372032'
BEIGE = '#f3f0eb'
LIGHTBLUE = '#e5f7fb'
PINK = '#fa95c1'
LAV = '#c1bbe9'
BLUE = '#9ad2e3'
TPINK = '#e29ac0'
TEXT = '#3d2b38'
FONT = "'Fira Sans', 'Segoe UI', Arial, Helvetica, sans-serif"

P = f"margin:0 0 16px 0;font-family:{FONT};font-size:16px;line-height:26px;color:{TEXT};"
H2 = f"margin:0 0 16px 0;font-family:{FONT};font-size:26px;line-height:32px;font-weight:700;color:{PLUM};"
PAD = "padding:36px 40px;"


def section(bg, inner, pad=PAD, cls='px'):
    return (f'<tr><td class="{cls}" bgcolor="{bg}" style="background:{bg};{pad}">{inner}</td></tr>\n')


def button(label, href, bg, color=PLUM):
    return (f'<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:8px 0 0 0;">'
            f'<tr><td bgcolor="{bg}" style="background:{bg};">'
            f'<a href="{href}" target="_blank" style="display:inline-block;padding:16px 22px;font-family:{FONT};'
            f'font-size:15px;line-height:18px;font-weight:700;color:{color};text-decoration:none;">{label}</a>'
            f'</td></tr></table>')


def tile(bg, number, label):
    return (f'<td class="stack" width="33%" valign="top" style="padding:0 6px 12px 6px;">'
            f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
            f'<td bgcolor="{bg}" style="background:{bg};padding:24px 18px;height:96px;" valign="top">'
            f'<div style="font-family:{FONT};font-size:28px;line-height:34px;font-weight:700;color:{PLUM};">{number}</div>'
            f'<div style="font-family:{FONT};font-size:14px;line-height:20px;color:{TEXT};padding-top:8px;">{label}</div>'
            f'</td></tr></table></td>')


def quote(text):
    return (f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 14px 0;">'
            f'<tr><td width="5" bgcolor="#dd9abd" style="background:#dd9abd;width:5px;font-size:0;line-height:0;">&nbsp;</td>'
            f'<td style="padding:4px 0 4px 16px;font-family:{FONT};font-size:17px;line-height:26px;font-style:italic;'
            f'font-weight:700;color:{PLUM};">{text}</td></tr></table>')


LEGEND = (f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">'
    + ''.join(f'<tr><td width="14" valign="middle" style="padding:3px 0;"><div style="width:12px;height:12px;background:{c};font-size:0;line-height:0;">&nbsp;</div></td>'
              f'<td valign="middle" style="padding:3px 0 3px 8px;font-family:{FONT};font-size:14px;line-height:20px;color:{TEXT};">{t}</td></tr>'
              for c, t in [('#93ccdf', 'Sport 39&nbsp;%'), ('#e199be', 'Hudba 19&nbsp;%'), ('#c2bbe7', 'Výtvarný obor 12&nbsp;%'), ('#2c1a28', 'Oddíly a tábory 12&nbsp;%'), ('#4f6a95', 'Tanec 10&nbsp;%'), ('#e2b075', 'Vzdělávání 5&nbsp;%'), ('#96c3a4', 'Ostatní 2&nbsp;%')])
    + '</table>')

rows = []

# hlavicka
rows.append(section(HEAD,
    f'<img src="{LOGO}" width="140" alt="Darujeme kroužky dětem" style="display:block;width:140px;height:auto;border:0;margin:0 0 28px 0;">'
    f'<h1 style="margin:0 0 12px 0;font-family:{FONT};font-size:32px;line-height:38px;font-weight:700;color:#ffffff;">'
    f'Podívejte se, co se díky vám daří</h1>'
    f'<p style="margin:0;font-family:{FONT};font-size:17px;line-height:26px;color:#f0e6ee;">'
    f'Výsledky jarní výzvy a nová kampaň Jeden klik</p>',
    pad='padding:40px 40px 40px 40px;'))

# uvod
rows.append(section(BEIGE,
    f'<p style="{P}font-size:20px;font-weight:700;color:{PLUM};">Milí dárci,</p>'
    f'<p style="{P}">Podzim je už v plném proudu a s ním i pravidelná podzimní výzva projektu Darujeme kroužky dětem. '
    f'Tentokrát se s Vámi chceme podělit i o velkou novinku, ze které máme opravdu radost – spustili jsme dárcovskou '
    f'kampaň Jeden klik.</p>'
    f'<p style="{P}margin:0;">Než Vám ji představíme blíže, chceme Vám nejprve krátce ukázat, co se podařilo během jarní '
    f'výzvy. Díky Vaší podpoře mohly děti sportovat, hrát na hudební nástroj, tvořit, tančit nebo být součástí oddílu. '
    f'Mohly se věnovat tomu, co je baví, rozvíjet své dovednosti, získávat sebevědomí a navazovat nová přátelství. '
    f'Podívejte se s námi, co se během jarní výzvy podařilo.</p>'))

# cisla
rows.append(
    f'<tr><td class="px" bgcolor="#f1f0ec" style="background:#f1f0ec;padding:36px 34px 24px 34px;border-top:1px solid #e4e0d9;border-bottom:1px solid #e4e0d9;">'
    f'<h2 style="{H2}padding:0 6px;">Jarní výzva v číslech</h2>'
    f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
    + tile(BLUE, '3&nbsp;075', 'podpořených dětí')
    + tile(LAV, '4,46&nbsp;mil.&nbsp;Kč', 'rozdělené podpory')
    + tile(TPINK, '1&nbsp;091', 'zapojených poskytovatelů aktivit')
    + '</tr></table></td></tr>\n')

rows.append(section(BEIGE,
    f'<p style="{P}margin:0;">Pokud byste se chtěli o výsledcích jarní výzvy dozvědět více – například jaké aktivity děti '
    f'nejčastěji navštěvovaly, ze kterých krajů pocházelo nejvíce podpořených dětí nebo jak jejich rodiče vnímají přínos '
    f'volnočasových aktivit – podrobnější vyhodnocení najdete níže.</p>'))

# novinka
rows.append(section(LIGHTBLUE,
    f'<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 20px 0;"><tr>'
    f'<td bgcolor="{PINK}" style="background:{PINK};padding:7px 14px;font-family:{FONT};font-size:12px;line-height:16px;'
    f'font-weight:700;letter-spacing:1px;color:{PLUM};">NOVINKA</td></tr></table>'
    f'<h2 style="{H2}">Kampaň Jeden klik</h2>'
    f'<p style="{P}">Teď už ale k naší velké novince. Možná už na Vás kampaň Jeden klik vykoukla na sociálních sítích '
    f'nebo jinde v online prostoru. Rádi bychom Vám přiblížili, proč vznikla, co stojí za její podobou a čeho bychom '
    f'díky ní chtěli dosáhnout.</p>'
    f'<p style="{P}margin:0;">Rozhodli jsme se do takto rozsáhlé kampaně pustit, protože žádostí o pomoc přibývá a zároveň '
    f'rostou ceny kroužků. Abychom mohli i nadále pomáhat co největšímu počtu dětí, potřebujeme získat více prostředků '
    f'a oslovit také nové dárce.</p>'))

# kolaz
rows.append(
    f'<tr><td style="padding:0;font-size:0;line-height:0;"><a href="{JEDENKLIK}" target="_blank">'
    f'<img src="{KOLAZ}" width="640" alt="Vizuály kampaně Jeden klik – hudební, oddílový, sportovní a umělecký kroužek" '
    f'style="display:block;width:100%;max-width:640px;height:auto;border:0;"></a></td></tr>\n')

# pribeh
rows.append(section(BEIGE,
    f'<p style="{P}">Hlavním symbolem kampaně se stal QR kód propojený s předměty z jednotlivých kroužků. '
    f'Odtud název Jeden klik – stačí naskenovat, kliknout a přispět.</p>'
    f'<p style="{P}">Za originální ideou QR kódu i celou kreativní podobou kampaně stojí agentura Loosers Prague, '
    f'která ke spolupráci přizvala fotografa Tomáše Třeštíka. Jeho fotografie dodaly celému konceptu potřebnou emoci '
    f'a autentičnost.</p>'
    f'<p style="{P}">Kromě fotografií vznikla také série krátkých videí. Chtěli jsme, aby kampaň nebyla jen o číslech, '
    f'ale ukázala, co kroužky pro podpořené děti znamenají a co jim dávají.</p>'
    + button('Prohlédnout kampaň Jeden klik', JEDENKLIK, PINK)))

# video
rows.append(section(LAV,
    f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 24px 0;"><tr>'
    f'<td bgcolor="{DARK}" style="background:{DARK};padding:22px 24px;">'
    f'<a href="{VIDEO}" target="_blank" style="text-decoration:none;">'
    f'<table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr>'
    f'<td width="56" valign="middle" style="width:56px;">'
    f'<table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr>'
    f'<td width="56" height="56" align="center" valign="middle" bgcolor="{PINK}" style="width:56px;height:56px;background:{PINK};'
    f'border-radius:28px;font-family:Arial,sans-serif;font-size:22px;line-height:56px;color:{PLUM};">&#9654;</td>'
    f'</tr></table></td>'
    f'<td valign="middle" style="padding-left:20px;">'
    f'<div style="font-family:{FONT};font-size:19px;line-height:24px;font-weight:700;color:#ffffff;">Malá ochutnávka kampaně</div>'
    f'<div style="font-family:{FONT};font-size:14px;line-height:20px;color:#f0e6ee;padding-top:6px;">Co znamenají kroužky pro rodiče podpořených dětí</div>'
    f'</td></tr></table></a></td></tr></table>'
    f'<p style="{P}">Vedle videí s dětmi vzniklo také video s rodiči podpořených dětí. Právě toto video jsme pro Vás '
    f'vybrali jako malou ochutnávku kampaně, abyste přímo od rodičů slyšeli, co Vaše podpora dětem a jejich rodinám '
    f'přináší.</p>'
    + button('Přehrát video rodičů', VIDEO, BEIGE)))

# podekovani + site
PL = f"margin:0 0 16px 0;font-family:{FONT};font-size:16px;line-height:26px;color:#faeaf4;"
social = (f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:8px 0 0 0;"><tr>'
          + ''.join(
              f'<td class="stack" width="33%" style="padding:0 6px 10px 0;"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
              f'<td align="center" bgcolor="{PINK}" style="background:{PINK};">'
              f'<a href="{href}" target="_blank" style="display:block;padding:15px 10px;font-family:{FONT};font-size:15px;'
              f'line-height:18px;font-weight:700;color:{PLUM};text-decoration:none;">{label}</a></td></tr></table></td>'
              for label, href in (('Facebook', FB), ('Instagram', IG), ('LinkedIn', LI)))
          + '</tr></table>')
rows.append(section(DARK,
    f'<p style="{PL}">Vy jste byli součástí našeho příběhu ještě předtím, než tato kampaň vznikla. Díky Vaší podpoře '
    f'můžeme už od roku 2022 pomáhat dětem, jejichž rodiny by si kroužky nemohly dovolit. I proto jsme se o tuto novinku '
    f'chtěli podělit právě s Vámi.</p>'
    f'<p style="{PL}">Budeme moc rádi, když nám zachováte svou přízeň a zůstanete s námi i nadále. Vaše zapojení je pro nás '
    f'nyní obzvlášť důležité – v probíhající podzimní výzvě už na podporu čekají stovky dětí. I proto se na Vás obracíme '
    f's prosbou o pomoc.</p>'
    f'<p style="{PL}">Podpora přitom nemusí mít vždy jen podobu finančního příspěvku. Velmi nám pomůžete také tím, když '
    f'budete kampaň sdílet se svými blízkými, přáteli nebo kolegy.</p>'
    f'<p style="{PL}">Pokud byste nás chtěli podpořit i touto cestou, sledujte profily Darujeme kroužky dětem na sociálních '
    f'sítích. Průběžně na nich zveřejňujeme příspěvky ke kampani a můžete si vybrat ten, který Vám bude nejbližší.</p>'
    + social))

# detailnejsi pohled
rows.append(section(LIGHTBLUE,
    f'<h2 style="{H2}">Detailnější pohled na vyhodnocení jarní výzvy</h2>'
    f'<p style="{P}margin:0;">Podívejte se podrobněji, odkud podpořené děti pocházely, jaké aktivity nejčastěji '
    f'navštěvovaly a jak přínos kroužků vnímají jejich rodiče.</p>'))

# mapa
rows.append(section(BEIGE,
    f'<p style="{P}">Již podruhé bylo nejvíce podpořených dětí z <strong>Moravskoslezského kraje</strong>, těsně za ním '
    f'následovala <strong>Praha</strong>. Jak se podpora rozdělila mezi jednotlivé kraje, se můžete podívat na mapě.</p>'
    f'<img src="{MAPA}" width="560" alt="Mapa: počet podpořených dětí dle krajů, 2. pol. 2025/2026, celkem 3 075 dětí. '
    f'Nejvíce Moravskoslezský kraj, druhá Praha." style="display:block;width:100%;max-width:560px;height:auto;border:0;">'))

# aktivity
rows.append(
    f'<tr><td class="px" bgcolor="#f1f0ec" style="background:#f1f0ec;padding:36px 40px;border-top:1px solid #e4e0d9;border-bottom:1px solid #e4e0d9;">'
    f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
    f'<td class="stack" width="52%" valign="top" style="padding-right:20px;">'
    f'<h2 style="{H2}">Co děti nejvíce bavilo?</h2>'
    f'<p style="{P}">Nejčastěji děti využívaly příspěvek na <strong>sportovní aktivity (39&nbsp;%)</strong>, následovaly '
    f'<strong>hudební aktivity (19&nbsp;%)</strong>. Významné zastoupení měly také výtvarné aktivity, oddílová a táborová '
    f'činnost a tanec.</p>'
    f'<p style="{P}margin:0;">Příspěvky děti využívaly u 1&nbsp;091 zapojených poskytovatelů. Největší zastoupení měly '
    f'základní umělecké školy a sportovní kluby.</p></td>'
    f'<td class="stack" width="48%" valign="top" style="padding-top:8px;">'
    f'<img src="{GRAF}" width="200" alt="Graf aktivit dětí" style="display:block;width:200px;max-width:100%;height:auto;border:0;margin:0 auto 16px auto;">'
    + LEGEND +
    f'</td></tr></table></td></tr>\n')

# prinos
rows.append(section(BEIGE,
    f'<h2 style="{H2}">Co kroužky dětem přinášejí</h2>'
    f'<p style="{P}">Do našeho šetření se zapojilo <strong>431 rodičů námi podpořených dětí</strong>.</p>'
    f'<p style="{P}"><strong>95&nbsp;% rodičů</strong> vnímá, že kroužek dává jejich dítěti více příležitostí navazovat '
    f'přátelství a být součástí kolektivu. <strong>94&nbsp;% rodičů</strong> zároveň velmi pozitivně hodnotí radost '
    f'a smysluplné trávení času, které kroužek dítěti přináší.</p>'
    f'<p style="{P}"><strong>84&nbsp;% rodičů</strong> vidí pozitivní dopad pravidelné účasti na volnočasové aktivitě '
    f'na sebevědomí dětí.</p>'
    f'<p style="{P}margin-bottom:24px;">Rodiče ve svých odpovědích často zmiňovali také pocit přijetí a bezpečí, lepší '
    f'zvládání stresu, rozvoj dovedností, větší samostatnost a radost z pohybu či tvoření.</p>'
    + quote('„Kroužek měl na moje dítě velmi pozitivní vliv – rozvíjel jeho dovednosti, sebevědomí i vztahy s ostatními.“')
    + quote('„Dítě je šťastnější, má pocit ‚dospělosti‘, že to, co dělá ve svém volném čase, má smysl.“')
    + quote('„Díky této příležitosti nejsou mé děti vystrkované z kolektivu.“')))

# zapati
rows.append(section(BLUE,
    f'<p style="margin:0 0 10px 0;font-family:{FONT};font-size:19px;line-height:27px;font-weight:700;color:{PLUM};text-align:center;">'
    f'Děkujeme, že jste s námi a pomáháte dětem dělat to, co je baví.</p>'
    f'<p style="margin:0;font-family:{FONT};font-size:14px;line-height:20px;color:{TEXT};text-align:center;">'
    f'Tým Darujeme kroužky dětem</p>',
    pad='padding:32px 40px;'))

doc = f'''<!DOCTYPE html>
<html lang="cs">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<title>Podívejte se, co se díky vám daří</title>
<link href="https://fonts.googleapis.com/css2?family=Fira+Sans:ital,wght@0,400;0,700;1,700&amp;display=swap" rel="stylesheet">
<style>
  body {{ margin:0; padding:0; background:{BEIGE}; -webkit-text-size-adjust:100%; }}
  table {{ border-collapse:collapse; }}
  img {{ border:0; outline:none; text-decoration:none; }}
  a {{ color:{PLUM}; }}
  @media only screen and (max-width:620px) {{
    .wrap {{ width:100% !important; }}
    .px {{ padding-left:20px !important; padding-right:20px !important; }}
    .stack {{ display:block !important; width:100% !important; padding-left:0 !important; padding-right:0 !important; }}
    h1 {{ font-size:26px !important; line-height:32px !important; }}
  }}
</style>
</head>
<body style="margin:0;padding:0;background:{BEIGE};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Výsledky jarní výzvy a nová kampaň Jeden klik</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="{BEIGE}" style="background:{BEIGE};">
<tr><td align="center" style="padding:0;">
<table role="presentation" class="wrap" width="640" cellspacing="0" cellpadding="0" border="0" style="width:640px;max-width:640px;">
{''.join(rows)}</table>
</td></tr>
</table>
</body>
</html>
'''
open('final_html_text.html', 'w', encoding='utf-8').write(doc)
print(len(doc))

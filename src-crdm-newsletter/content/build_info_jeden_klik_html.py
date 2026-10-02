import os
import re

# Info dopis darcum Jeden klik - hlavicka, tlacitka a paticka se berou z newsletteru 10/2026
HERE = os.path.dirname(os.path.abspath(__file__))
h = open(os.path.join(HERE, 'newsletter-dkd-jeden-klik-2026-10.html'), encoding='utf-8').read().rstrip('\n')
F = "font-family:'Fira Sans', 'Segoe UI', Arial, Helvetica, sans-serif;"
# hlavicka (head + body start) az po otevreni obalove tabulky
head = h[:h.find('<tr><td class="px" bgcolor="#312030"')]
# socialni tlacitka - beze zmeny ze vzoru
s0 = h.find('<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:8px 0 0 0;"><tr><td class="stack"')
s1 = h.find('LinkedIn</a>') + len('LinkedIn</a></td></tr></table></td></tr></table>')
social = h[s0:s1]
assert 'facebook' in social and social.endswith('</table>')
logo = re.search(r'<img src="[^"]*ids=068Te00000b0Wvc[^>]*>', h).group(0)
tail = h[h.rfind('</table>\n</td></tr>\n</table>'):]

TITLE = 'Díky vám se kroužky dostávají k dalším dětem'
PRE = 'Jak to vypadá po prvním týdnu kampaně Jeden klik'
head = head.replace('<title>Podívejte se, co se díky vám daří</title>', '<title>' + TITLE + '</title>')
head = head.replace('>Výsledky jarní výzvy a nová kampaň Jeden klik</div>', '>' + PRE + '</div>')
assert TITLE in head and PRE in head

def p(t, col='#3d2b38', extra=''):
    return f'<p style="margin:0 0 16px 0;{F}font-size:16px;line-height:26px;color:{col};{extra}">{t}</p>'
def card(bg, num, lbl):
    return (f'<td class="stack" width="33%" valign="top" style="padding:0 6px 12px 6px;"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr><td bgcolor="{bg}" style="background:{bg};padding:24px 18px;height:96px;" valign="top">'
            f'<div style="{F}font-size:28px;line-height:34px;font-weight:700;color:#382133;">{num}</div>'
            f'<div style="{F}font-size:14px;line-height:20px;color:#3d2b38;padding-top:8px;">{lbl}</div></td></tr></table></td>')

rows = []
rows.append(f'<tr><td class="px" bgcolor="#312030" style="background:#312030;padding:40px 40px 40px 40px;">{logo}'
            f'<h1 style="margin:0 0 12px 0;{F}font-size:32px;line-height:38px;font-weight:700;color:#ffffff;">{TITLE}</h1>'
            f'<p style="margin:0;{F}font-size:17px;line-height:26px;color:#f0e6ee;">{PRE}</p></td></tr>')
rows.append('<tr><td class="px" bgcolor="#f3f0eb" style="background:#f3f0eb;padding:36px 40px;">'
            + p('Milí dárci,', extra='font-size:20px;font-weight:700;color:#382133;')
            + p('děkujeme, že jste se zapojili do kampaně Jeden klik a společně s námi pomáháte měnit dětské příběhy.')
            + p('Během prvního týdne kampaně se díky vám podařilo vybrat již neuvěřitelných <strong>355 tisíc korun</strong>. Díky této částce může <strong>236 dětí</strong> začít chodit na svůj vybraný kroužek celé pololetí.', extra='margin:0;')
            + '</td></tr>')
rows.append(f'<tr><td class="px" bgcolor="#f1f0ec" style="background:#f1f0ec;padding:36px 34px 24px 34px;border-top:1px solid #e4e0d9;border-bottom:1px solid #e4e0d9;">'
            f'<h2 style="margin:0 0 16px 0;{F}font-size:26px;line-height:32px;font-weight:700;color:#382133;padding:0 6px;">První týden kampaně v číslech</h2>'
            '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
            + card('#9ad2e3', '355&nbsp;tis.&nbsp;Kč', 'vybraných za první týden')
            + card('#c1bbe9', '236', 'dětí může chodit na kroužek celé pololetí')
            + card('#e29ac0', '≈&nbsp;400', 'dětí nyní čeká na podporu (přibližně)')
            + '</tr></table></td></tr>')
rows.append('<tr><td class="px" bgcolor="#f3f0eb" style="background:#f3f0eb;padding:36px 40px;">'
            + p('Nejde přitom jen o samotný kroužek. Děti získají nové zkušenosti, mohou rozvíjet svůj talent a sebevědomí, navazovat přátelství a zažívat pocit, že někam patří. To vše je možné právě díky vám.')
            + p('Za každý příspěvek i za důvěru, kterou jste nám svou podporou projevili, vám moc děkujeme.', extra='margin:0;')
            + '</td></tr>')
rows.append('<tr><td class="px" bgcolor="#372032" style="background:#372032;padding:36px 40px;">'
            + p('Budeme moc rádi, když nám pomůžete rozšířit řady dárců, aby takových lidí, jako jste vy, bylo více. Můžete nás sledovat na sociálních sítích, vybrat si třeba příspěvek, který je vám blízký, a sdílet ho dál – nebo dát ostatním vědět, že jste naši kampaň sami podpořili. Za jakoukoli podporu tohoto typu budeme moc vděční.', col='#faeaf4')
            + social
            + f'<p style="margin:16px 0 0 0;{F}font-size:17px;line-height:26px;font-style:italic;font-weight:700;color:#fa95c1;">Každé sdílení může pomoci změnit příběh dalšího dítěte.</p>'
            + '</td></tr>')
rows.append('<tr><td class="px" bgcolor="#e5f7fb" style="background:#e5f7fb;padding:36px 40px;">'
            + p('Na podporu nyní čeká přibližně <strong>400 dětí</strong>. Protože je výzva otevřená až do <strong>24. listopadu</strong>, může jejich počet ještě vzrůst. Pevně věříme, že společnými silami dokážeme pomoci všem dětem, které na svou příležitost čekají, a umožnit jim chodit na kroužek, který si vybraly.')
            + p('O výsledcích a dalším průběhu kampaně vás budeme průběžně informovat.', extra='margin:0;')
            + '</td></tr>')
rows.append(f'<tr><td class="px" bgcolor="#9ad2e3" style="background:#9ad2e3;padding:32px 40px;">'
            f'<p style="margin:0 0 10px 0;{F}font-size:19px;line-height:27px;font-weight:700;color:#382133;text-align:center;">Ještě jednou vám ze srdce děkujeme, že pomáháte dětem rozvíjet jejich talent, získávat nové zážitky a být součástí party.</p>'
            f'<p style="margin:0;{F}font-size:14px;line-height:20px;color:#3d2b38;text-align:center;">Tým Darujeme kroužky dětem</p></td></tr>\n')
out = head + '\n'.join(rows) + tail
open(os.path.join(HERE, '..', 'email', 'DKD_Newslettery', 'DKD_Info_Jeden_klik_2026_10.email'), 'w', encoding='utf-8').write(out)
txt = re.sub(r'\n\s*\n+', '\n', re.sub(r'<[^>]+>', '\n', re.sub(r'<(style|title)>.*?</\1>', '', out, flags=re.S))).replace('&nbsp;', ' ')
print(len(out)); print(txt)

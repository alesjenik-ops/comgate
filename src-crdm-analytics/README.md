# Dashboardy NPC Analytics (CRDM)

Dva dashboardy nad analytikou balíčku **fpack analytics** (`fpnpc_analytics`).
Žádná dlaždice už nestojí na `DonorGiftSummary` ani na `OutreachSummary`.

| Dashboard | Složka |
| --- | --- |
| NPC Analytics — provozní přehled | `NPC Analytics Dashboards` |
| NPC Analytics — výroční zpráva | `NPC Analytics Dashboards` |

## Co se vyměnilo a proč

`DonorGiftSummary` a `OutreachSummary` jsou standardní NPC rollupy, které plní
Data Processing Engine. Ten v tomhle orgu nikdy nasazený nebyl, takže obě
tabulky mají **nula záznamů** a dlaždice nad nimi byly trvale prázdné.

| Původní dlaždice | Stála na | Nově |
| --- | --- | --- |
| Top 10 dárců (NPC rollup) | `Donor_Gift_Summary_NPC__c` | `FP_Top_Darci` – Account + fpack |
| Objem darů podle úrovně dárcovství | `Donor_Gift_Summary_NPC__c` | `FP_Uroven_Darcovstvi` – Donor History |
| Dárci k reaktivaci (nad 365 dní) | `Donor_Gift_Summary_NPC__c` | `FP_Darci_K_Reaktivaci` – scénář dárce |
| Top 10 kampaní (NPC rollup) | `Outreach_Summary_NPC__c` | `FP_Kampane_Pocet_Darcu` – Campaign + fpack |

Mimo tuhle složku se stejným způsobem předělala dlaždice *Top dárci* na
`Fundraising Dashboard` – viz `src-crdm-fundraising`.

### Čím se co nahradilo

- **Úroveň dárcovství** (`GivingLevel`) má protějšek v `fpnpc_analytics__Donor_History__c.Donor_Level__c`
  na ročním snapshotu dárce.
- **Recency** (`DaysSinceLastGift > 365`) se nahradila scénářem dárce:
  `Donor_Scenario_Analytics__c` v hodnotách *Regular - Lapsed*, *Regular - To Restart*,
  *Regular - Lapsed to One-Off* a *One-Off - Lapsed*. Je to přesnější – rozlišuje
  vyhaslého pravidelného dárce od jednorázového.
- **Celkový objem darů** (`TotalGiftsAmount`) fpack v jednom poli nemá, proto je
  v reportu vlastní souhrnný vzorec `Celkem darováno` =
  `OneOff_Donation_Amount__c + Regular_Donation_Amount_Total__c`.
- **Výkon kampaní** z Outreach Summary pokrývají pole `fpnpc_analytics__*` přímo
  na `Campaign`; nová dlaždice ukazuje počty dárců, protože objemy už vedle ní
  ukazuje *Top 10 kampaní — jednorázové dary*.

## Pozor: fpack analytika zatím nic nepočítá

Reporty se spouštějí a vracejí správné řádky (373 účtů, 6 kampaní), ale **všechna
čísla jsou nulová** a každý dárce má scénář *Non - Donor*. Denní dávky
(`DonorStatsBatch`, `DonorScenarioAnalyticsBatch`, `CampaignAnalyticsBatch`,
`DonorHistoryBackfillBatch`) doběhnou bez chyby, jen nemají podle čeho počítat:

```
fpnpc_analytics__Gift_Type_Settings__mdt   0 zaznamu
fpnpc_analytics__Donor_Level__mdt          0 zaznamu
fpnpc_analytics__Donor_History__c          0 zaznamu
```

Bez záznamu v `Gift_Type_Settings__mdt` nemá balíček namapovaný žádný typ daru na
pole v Donor History, takže nespočítá nic. Doplnit je **nemůžeme** – všechna pole
obou custom metadata typů mají `createable: false` i `updateable: false`
(`fieldManageability = DeveloperControlled`), takže je smí naplnit jen dodavatel
balíčku, ne subscriber.

Dokud to dodavatel nedodá, jsou dlaždice prázdné – ale prázdné ze správného
zdroje. Jakmile konfigurace dorazí, naplní se samy, nic se nemusí předělávat.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-analytics --target-org <alias>
```

Složka je samostatně nasaditelná: obsahuje i reporty, které se neměnily, ale na
které dashboardy odkazují.

## Smazané reporty

Devět reportů nad prázdnými NPC rollupy už v orgu není – nevisely na žádném
dashboardu a jejich zdroj nemá ani jeden záznam:

| Report | Report typ |
| --- | --- |
| Top dárci (Donor Gift Summary) | `Donor_Gift_Summary_NPC__c` |
| Dárci podle úrovně (Giving Level) | `Donor_Gift_Summary_NPC__c` |
| Dárci bez daru déle než rok (recency) | `Donor_Gift_Summary_NPC__c` |
| Meziroční srovnání darů (3 roky) | `Donor_Gift_Summary_NPC__c` |
| RFM segmentace dárců | `Donor_Gift_Summary_NPC__c` |
| Soft credity dárců | `Donor_Gift_Summary_NPC__c` |
| Výkon kampaní (Outreach Summary) | `Outreach_Summary_NPC__c` |
| Výkon podle source kódu | `Outreach_Summary_NPC__c` |
| Kampaně: jednorázové vs. pravidelné | `Outreach_Summary_NPC__c` |

Smazáno deployem s `destructiveChangesPost.xml`. Ve složce *NPC Analytics*
zůstalo 19 reportů, všechny nad analytikou fpack, `GiftTransaction` nebo
`GiftCommitment`.

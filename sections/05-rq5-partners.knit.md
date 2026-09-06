# RQ5 — Tegund samstarfsaðila



> Hvaða fyrirtæki og stofnanir koma oftast að meistaraverkefnum?

Undirspurningar:

- Hvaða atvinnugreinar eru mest áberandi?
- Hvaða stofnanir eru virkastar?
- Eru tengslin dreifð eða byggð á fáum lykilaðilum?

::: {.callout-important title="Krefst hreinsunar og flokkunar"}
Byggir á sömu breytu og [RQ4](04-rq4-collaboration.qmd) og erfir þekjuvandann. Að auki þarf
tvennt: **samræmingu heita** og **aðgreiningu styrkveitenda frá samstarfsaðilum**.
:::

## Skráðir styrktaraðilar


::: {.cell}

```{.r .cell-code}
dbGetQuery(con, "
  select m.sponsor as styrktaradili, count(*) as fjoldi
  from thesis t
  join thesis_metadata m on m.thesis_id = t.id
  where m.degree_level = 'master' and m.sponsor is not null
  group by 1
  order by 2 desc
  limit 20
") |>
  knitr::kable(caption = "Tuttugu tíðustu gildi í `sponsor`, óhreinsuð.")
```

::: {.cell-output-display}


Table: Tuttugu tíðustu gildi í `sponsor`, óhreinsuð.

|styrktaradili                                                              | fjoldi|
|:--------------------------------------------------------------------------|------:|
|Rannís                                                                     |     14|
|Vegagerðin                                                                 |     10|
|Orkurannsóknarsjóður Landsvirkjunar                                        |      9|
|Rannsóknasjóður Háskóla Íslands                                            |      9|
|Icelandair                                                                 |      8|
|Isavia                                                                     |      8|
|Landsvirkjun                                                               |      8|
|Orkurannsóknasjóður Landsvirkjunar                                         |      5|
|Rannsóknasjóður                                                            |      4|
|Rannsóknarsjóður Vegagerðarinnar                                           |      4|
|Íslensk erfðagreining                                                      |      4|
|Rannsóknarsjóður Háskóla Íslands                                           |      3|
|RANNÍS                                                                     |      3|
|Orkuveita Reykjavíkur                                                      |      3|
|Rannsóknasjóður (Rannís) Rannsóknasjóður Háskóla Íslands                   |      3|
|Tækniþróunarsjóður                                                         |      2|
|Rannsóknamiðstöð Íslands                                                   |      2|
|Háskólinn í Reykjavík                                                      |      2|
|Markáætlun í tungu og tækni 2019, styrknúmer 180027-5301.                  |      2|
|This work was supported by the Icelandic Research Fund (grant no. 196228). |      2|


:::
:::


## Tvö vandamál sem taflan sýnir

**Heiti eru ósamræmd.** Sami aðili birtist í mörgum myndum — `Rannís`, `RANNÍS` og
`Rannsóknamiðstöð Íslands` eru eitt og hið sama, og `Orkurannsóknarsjóður Landsvirkjunar`
og `Orkurannsóknasjóður Landsvirkjunar` greinast aðeins á einum staf. Talning án
samræmingar vantelur stærstu aðilana.

**Styrkveitendur og samstarfsaðilar blandast saman.** Reiturinn geymir bæði
rannsóknasjóði (`Rannís`, `Rannsóknasjóður Háskóla Íslands`) og fyrirtæki (`Marel`,
`Össur`, `Icelandair`). Rannsóknarspurningin spyr um **fyrirtæki og stofnanir**, sem er
annar hópur en fjármögnunaraðilar. Þessu þarf að skipta upp áður en talið er.

Sum gildi eru heldur ekki heiti heldur heilar setningar úr styrkjatexta, sem bendir til að
reiturinn sé notaður frjálslega.

## Næstu skref

1. `config/sponsors.yaml` með samræmingu heita.
2. Flokkun í styrkveitanda / fyrirtæki / opinbera stofnun / háskóla.
3. Vörpun á atvinnugrein fyrir fyrirtækin.
4. Fyrst þá er hægt að meta hvort tengslin séu dreifð eða byggð á fáum lykilaðilum.


# Streif (Hahnenkamm-Abfahrt, Kitzbühel): Recherche

Stand: 25.11.2026. Alle Zahlen mit Quelle. Wenn Quellen sich widersprechen, steht dort ein Bereich und der gewählte Wert (**fett**).

## Quellen

| Kürzel | URL |
|---|---|
| [HKR] | https://hahnenkamm.com/en/racetracks/the-streif-downhill/ (offizielle Seite des Kitzbüheler Ski Club) |
| [HKR-Inkl] | https://hahnenkamm.com/en/news/assessing-the-streif-with-an-inclinometer/ |
| [WP-DE] | https://de.wikipedia.org/wiki/Streif |
| [WP-EN] | https://en.wikipedia.org/wiki/Streif |
| [FS] | https://www.flashscore.de/news/ein-streif-zug-vor-weltcup-in-kitzbuhel-alles-zur-legendaren-alpin-strecke/lvlr0Dte/ |
| [VIE] | https://www.vienna.at/13-zahlen-zur-streif-zwischen-grossen-siegen-rekorden-und-schweren-stuerzen/5625887 |
| [BZ] | https://www.berliner-zeitung.de/article/weltcup-am-hahnenkamm-was-die-ski-rennfahrer-in-kitzbuehel-auf-der-streif-erwartet-2178053 |
| [AF] | https://austria-forum.org/af/Heimatlexikon/Die_Streif |
| [OLY24] | https://olympics.com/en/news/alpine-ski-world-cup-23-24-cyprien-sarrazin-emerges-as-new-downhill-ace-with-triumph-over-marco-odermatt-at-kitzbuhel |
| [S24] | https://www.salzburg24.at/sport/wintersport/sarrazin-legt-in-kitzbuehel-traumfahrt-hin-art-273012 |
| [OSM] | OpenStreetMap, Route-Relation 12870777 „Streif-Rennstrecke“: https://www.openstreetmap.org/relation/12870777 (abgefragt über https://overpass-api.de am 25.11.2026) |
| [DEM] | EU-DEM 25 m über https://api.opentopodata.org/v1/eudem25m (eigene Abfrage entlang der OSM-Linie, 40-m-Raster) |

## 1. Kenndaten der Strecke

| Größe | Wert | Quelle / Anmerkung |
|---|---|---|
| Länge | **3312 m** | [HKR], [WP-DE], [WP-EN], [AF]. OSM-Linie Start bis Zielsprung/Zielraum: ca. 3090 m horizontal, ganze Relation bis ins Tal 3373 m [OSM] |
| Starthöhe | **1665 m** | [HKR], [WP-DE], [VIE]. DEM am OSM-Startpunkt: 1640 m [DEM], weil das 25-m-Raster glättet und das Starthaus erhöht steht |
| Zielhöhe | **805 m** | [HKR], [WP-DE], [AF] |
| Höhendifferenz | **860 m** | [HKR], [WP-EN] |
| Maximalgefälle | 85 % = **40,4°** | [HKR], [WP-DE], [WP-EN], [FS]. [BZ] nennt 86 % |
| Ort des Maximalgefälles | **Mausefalle** | [WP-DE], [WP-EN], [FS], [AF], [VIE]. [HKR] ordnet die 85 % dagegen dem Steilhang zu. Für das Spiel: Mausefalle |
| Minimalgefälle | 2 % (1,1°), Oberhausberg | [HKR], [WP-EN]. Die Kenndaten 2025 nennen laut Suchtreffer „Oberhausberg 2%“ |
| Durchschnittsgefälle | **27 % (15,1°)** | [HKR], [WP-DE], [WP-EN]. Kontrolle: 860/3312 = 26 % |
| Starthang | 160 m, 51 % (27°) | [HKR], [FS], [WP-EN]. [AF] und [VIE] nennen 50 % (26,6°) |
| Homologation | FIS 14579/09/22 | [HKR] |
| Starthaus | Oberhalb der Hahnenkammbahn-Bergstation, nordöstlich unter dem Hahnenkamm-Gipfel (1712 m) | [OSM], Koordinaten in Abschnitt 5 |

Rekord-Durchschnittsgeschwindigkeit: 106,9 km/h (Strobl 1997) [WP-EN]. [VIE] nennt 103 km/h als typischen Schnitt.

## 2. Streckenabschnitte (Start → Ziel)

Die Spalte **s** ist die Distanz entlang der OSM-Rennlinie ab dem Start, gemessen an den benannten Punkten der OSM-Relation [OSM]. Sie ist horizontal gemessen (2D) und daher etwa 3–7 % kürzer als die Schräglänge. Die Spalte **H** ist die Höhe aus EU-DEM 25 m [DEM] an diesem Punkt, gerundet. Sie ist geglättet: Echte Spitzengefälle über 60 % zeigt das DEM nur als ca. 45–55 %.

| # | Abschnitt | s (m) | H (m) | Gefälle | Charakter | Tempo | Sprung |
|---|---|---|---|---|---|---|---|
| 1 | Start / Starthang | 0–160 | 1640 (offiziell 1665) | 51 % [HKR] | Schuss aus dem Starthaus, danach scharfe Linkskurve [FS] | 100 km/h nach 8,5 s [WP-EN]; 60 km/h in < 3 s [WP-DE] | – |
| 2 | Mausefalle | 183 | 1570 | 85 % [HKR, WP-DE] | Sprung über die Kante in den Steilhang, Landung mit Kompression, danach links [FS] | 110–120 km/h [HKR, FS] | bis 80 m (Rekord, 1970er), heute meist 50–60 m [WP-DE, AF, HKR]; Inklinometer: knapp 60 m bei 105 km/h [HKR-Inkl] |
| 3 | Kompression (nach der Mausefalle) | 258 | 1537 | DEM ~40 % | Kompression, Ausfahrt in die Querung zum Karussell | – | – |
| 4 | Karussell | 402 | 1499 | DEM-Mulde ~8 % vor dem Abfall | 180°-**Rechts**kurve [WP-DE, FS, BZ] | 60–80 km/h [FS] | – |
| 5 | Steilhang | 534 | 1455 | 72 % (35,8°) [WP-EN]; DEM max. ~55 % bei s≈600 | Steile Hangschräge, Kurve an der Ausfahrt (Steilhangausfahrt) mit Fangzaun-Nähe, dann Übergang in den Weg | 90–100 km/h [FS] | – |
| 6 | Brückenschuss | 724 | 1397 | DEM 10–15 % | Gleitschuss auf einem schmalen Weg | ca. 110 km/h [FS] | – |
| 7 | Gschöss | 1061 | 1344 | DEM 1–16 %, kurze Gegensteigung | Längstes Gleitstück (650 m) [FS, BZ]; Rechtsknick mit kleinem Sprung [FS, HKR]. Brückenschuss und Gschöss zusammen ca. 20 s Gleiten [WP-DE] | ca. 90 km/h [FS] | kleiner Sprung [HKR] |
| 8 | Alte Schneise | 1388 | 1262 | DEM bis ~55 % davor | Nach rechts hängende Schräge [BZ, FS], Sprung [WP-DE] | ca. 120 km/h Anfahrt [FS] | Sprung, Weite nicht veröffentlicht |
| 9 | Seidlalmsprung | 1615 | 1225 | DEM ~25–30 % | Sprung in Streckenmitte, seit 1994 [HKR]; leichter Anstieg vor der Kante [WP-DE]; Rotation nach rechts in der Luft [HKR] | 80–90 km/h [FS] | Weite nicht veröffentlicht (Schätzung 30–40 m, keine Quelle) |
| 10 | Seidlalmkurve | ~1650–1750 | ~1215 | – | S-Kurve: erst rechts, dann links [HKR, FS] | 80–90 km/h [FS] | – |
| 11 | Lärchenschuss | 2035 | 1121 | DEM 25–40 % | Schuss durch Wald, danach fast 90°-Kurve [HKR] | 100–110 km/h [FS] | – |
| 12 | Oberhausberg | 2330 | 1076 | 2 % [HKR], DEM ~8–20 % | Flache S-Passage [HKR], leichter Gegenanstieg [WP-DE] | 60–80 km/h [FS] | – |
| 13 | Hausbergkante | 2443 | 1037 | 70 % (35°) [WP-EN]; DEM ~45–53 % | Sprung nach rechts über die Kante [FS] in eine Kompression | ca. 100 km/h [FS] | Weite nicht veröffentlicht |
| 14 | Hausberg-Kompression | ~2480–2520 | ~1010 | – | Kompression mit Linkskurve, bis 3,5 g [FS] | ca. 100 km/h [FS] | – |
| 15 | Querfahrt / Traverse | 2602 | 963 | DEM 30–40 % (Hangneigung quer) | Schräge Querfahrt mit Wellen und Schlägen [WP-DE]; leichter Rechtsknick [FS] | 90–105 km/h [FS] | – |
| 16 | Zielhang / Zielschuss | 2816 | 884 | 63 % [FS, BZ]; DEM ~45 % | Schuss mit Zielschuss-Kompression [WP-DE, AF] | > 140 km/h [FS, WP-DE] | – |
| 17 | Zielsprung | 2976 | 830 | DEM ~28 % | Letzter Sprung, in tiefer Hocke [HKR] | 120–150 km/h [FS, HKR] | 50–80 m: [FS] 50 m, [VIE] 70 m, [WP-DE] 80 m; **Spiel: 50–60 m** |
| 18 | Ziel | ~3090 | ~805 | DEM ~20 % auslaufend | Zielraum (Rasmusleiten) [AF] | – | – |

Die s-Werte von Seidlalmkurve, Hausberg-Kompression und Ziel sind interpoliert (Ziel = DEM-Höhe 805 m auf der OSM-Linie). Die übrigen s-Werte stammen von benannten OSM-Knoten.

Für Karussell, Steilhang, Brückenschuss, Gschöss, Lärchenschuss und Traverse gibt es keine veröffentlichten Sprungweiten. Die Weiten von Alte Schneise, Seidlalm und Hausbergkante prüft der Veranstalter jährlich per Inklinometer (2-m-Raster). Ziel ist eine äquivalente Landehöhe unter 2 m, Gefahrengrenze 2,5 m [HKR-Inkl].

## 3. Siegerzeiten

Volle Strecke, wenn nicht anders vermerkt. Quelle: [WP-EN], 2024 zusätzlich [OLY24] und [S24].

| Jahr | Sieger | Zeit | Anmerkung |
|---|---|---|---|
| 2026 | Giovanni Franzoni (ITA) | 1:52,31 | |
| 2025 | James Crawford (CAN) | 1:53,64 | |
| 2024 Sa | Cyprien Sarrazin (FRA) | 1:52,96 | [OLY24] |
| 2024 Fr | Cyprien Sarrazin (FRA) | 1:55,75 | [S24]; Zusatzrennen |
| 2023 Sa | Aleksander Aamodt Kilde (NOR) | 1:56,90 | |
| 2023 Fr | Vincent Kriechmayr (AUT) | 1:56,16 | Zusatzrennen |
| 2022 So | Beat Feuz (SUI) | 1:56,68 | auf Sonntag verlegt |
| 2022 Fr | Aleksander Aamodt Kilde (NOR) | 1:55,92 | **verkürzt**: Start 45 m tiefer (Wind) |
| 2021 So | Beat Feuz (SUI) | 1:55,29 | |
| 2021 Fr | Beat Feuz (SUI) | 1:53,77 | Ersatz für Wengen |
| 2020 | Matthias Mayer (AUT) | 1:55,59 | |
| 2019 | Dominik Paris (ITA) | 1:56,82 | |
| 2018 | Thomas Dreßen (GER) | 1:56,15 | |
| 2017 | Dominik Paris (ITA) | 1:55,01 | |
| 2016 | Peter Fill (ITA) | 1:52,37 | **verkürzt**: Start 40 m tiefer (Wind) |
| 2015 | Kjetil Jansrud (NOR) | 0:58,16 | **stark verkürzt**: Start Seidlalmsprung, ca. 1,6 km (Nebel) |
| 2014 | Hannes Reichelt (AUT) | 2:03,38 | **geändert**: Querfahrt und Zielschuss umfahren (Schneemangel) |
| 2013 | Dominik Paris (ITA) | 1:57,56 | |
| 2012 | Didier Cuche (SUI) | 1:13,28 | **verkürzt**: Start Alte Schneise, ca. 2 km |
| 2011 | Didier Cuche (SUI) | 1:57,72 | |
| 2010 | Didier Cuche (SUI) | 1:53,74 | |

- **Streckenrekord:** 1:51,58, Fritz Strobl (AUT), 1997 [HKR], [WP-DE], [WP-EN], [AF]. [FS] und [BZ] nennen 1:51,57, was ein Rundungs- oder Übertragungsfehler sein dürfte. **Verwendet: 1:51,58.**
- **Erste Austragung auf der Streif:** 1937, Thaddäus Schwabl, 3:53,1 [HKR], [AF].
- **Spannweite der vollen Strecke 2010–2026:** 1:52,31 bis 1:57,72. Median ca. 1:55,6.

## 4. Geschwindigkeiten, Sprünge, Kräfte

| Größe | Wert | Quelle |
|---|---|---|
| Höchsttempo (Rekord) | **153 km/h**, Michael Walchhofer 2006, Zielschuss | [WP-EN], [FS], [VIE] |
| Typisches Höchsttempo | 140–145 km/h (Zielschuss), 143 km/h genannt | [WP-DE], [WP-EN], [VIE]; [HKR]: bis 150 km/h am Zielsprung |
| Weitere Messwerte | 142,3 km/h (Défago 2009), 141,2 km/h (Macartney, Sturz 2008) | [WP-EN], [WP-DE], [VIE] |
| Beschleunigung am Start | 0 auf 60 km/h in < 3 s; 100 km/h nach 8,5 s | [WP-DE], [WP-EN] |
| Mausefalle | Absprung 105–120 km/h; Weite heute ~50–60 m, Rekord 80 m | [HKR-Inkl], [FS], [AF], [WP-DE] |
| Zielsprung | 50–80 m (siehe Tabelle oben) | [FS], [VIE], [WP-DE] |
| Karussell | 3,1 g Fliehkraft | [HKR], [WP-EN], [FS] |
| Hausberg-Kompression | 3,5 g | [FS] |
| Mausefalle-Landung/Kompression | ca. 3-faches Körpergewicht [WP-DE]; [VIE] nennt „etwa zehnfach“ (unplausibel als Dauerwert, allenfalls Kraftspitze). **Verwendet: 3–3,5 g** | |

## 5. Geografie / Karte (WGS84)

| Punkt | Lat | Lon | Quelle |
|---|---|---|---|
| Starthaus (OSM-Fläche „Starthaus“) | 47.42613 | 12.37123 | [OSM] Weg 330751394 |
| Rennstart (OSM „Hahnenkamm Race Start“) | 47.42622 | 12.37077 | [OSM] Weg 228967553 |
| Beginn der OSM-Rennlinie | 47.42633 | 12.37076 | [OSM] Relation 12870777 |
| Mausefalle | 47.42780 | 12.37023 | [OSM] Knoten 3308152316 |
| Karussell | 47.42819 | 12.36772 | [OSM] |
| Steilhang | 47.42900 | 12.36746 | [OSM] |
| Seidlalmsprung | 47.43734 | 12.37185 | [OSM] Knoten 3308192322 |
| Hausbergkante | 47.43978 | 12.37903 | [OSM] Knoten 3308210432 |
| Zielsprung | 47.44248 | 12.38334 | [OSM] |
| Ziellinie ca. (DEM = 805 m auf der Linie) | 47.4431 | 12.3845 | [OSM] + [DEM], abgeleitet |
| Hahnenkammbahn Bergstation | 47.42681 | 12.37252 | [OSM] Knoten 343186043 |
| Hahnenkammbahn Talstation | 47.44323 | 12.38936 | [OSM] Knoten 1685958015 |
| Hahnenkamm-Gipfel (1712 m) | 47.42379 | 12.36492 | [OSM] Knoten 256041750 |

Bounding Box der Rennstrecke, ungefähr: Lat 47.4260–47.4445, Lon 12.3672–12.3880.

Hinweis: Die Koordinate in den Wikipedia-Infoboxen (47.42417, 12.36528) [WP-DE], [WP-EN] liegt beim Hahnenkamm-Gipfel, ca. 500 m südwestlich des Starthauses. Sie ist nicht der Start.

### OpenStreetMap-Abdeckung

- Es gibt eine eigene Route-Relation **12870777**: `type=route`, `route=piste`, `piste:type=downhill`, `piste:difficulty=expert`, `name=Streif-Rennstrecke`, `oneway=yes`, `wikidata=Q18091`. Sie ist geordnet und enthält 10 Wege von Start bis Tal [OSM].
- Die Wege heißen `Streif-Rennstrecke`, `Streif-Rennstrecke (nur während Rennen präpariert)`, zwei Abschnitte `Streif Familienabfahrt` und ein Stück `Walde`. Alle haben `ref=21`, Wegs-IDs: 1037424943, 229220048, 956695993, 229220044, 229220049, 183009202, 1472105874, 956695997, 320430167, 547439924 [OSM].
- Die Relation enthält außerdem 14 Knoten mit `place=locality` als Abschnittsnamen: Mausefalle, Kompression, Karussell, Steilhang, Brückenschuss, Gschöss, Alte Schneise, Seidlalmsprung, Lärchenschuss, Oberhausberg, Hausbergkante, Traverse, Zielhang, Zielsprung. Daraus stammt die s-Spalte in Abschnitt 2.
- Achtung: Die Wege sind Pistenmittellinien, keine exakte Rennlinie. Die Relation läuft über das Ziel hinaus bis ins Tal (Ende 47.44416, 12.38758, DEM ~772 m). Für das Spiel bei ca. s = 3090 m abschneiden. Die separat gemappte „Streif Familienabfahrt“ (ebenfalls ref 21) umfährt Mausefalle und Steilhang und darf nicht mit der Rennlinie verwechselt werden.
- Overpass-Abfrage zum Nachladen:
  `[out:json];relation(12870777);way(r);out geom;`

### DEM-Höhenprofil entlang der OSM-Linie (Auszug, EU-DEM 25 m)

| s (m) | 0 | 200 | 400 | 600 | 800 | 1000 | 1200 | 1400 | 1600 | 1800 | 2000 | 2200 | 2400 | 2600 | 2800 | 3000 | 3090 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H (m) | 1640 | 1562 | 1500 | 1420 | 1388 | 1348 | 1348 | 1260 | 1229 | 1172 | 1131 | 1098 | 1058 | 964 | 891 | 823 | ~805 |

Bei s ≈ 1080–1160 (Gschöss) zeigt das DEM einen kurzen Gegenanstieg von ca. 10 m, was zur Beschreibung „Gegensteigung“ passt.

## 6. Hinweise für das Spieldesign

Zielwerte für Physik und Bot-Validierung, volle Strecke mit 3312 m und 860 Hm:

- **Siegerzeit (perfekte Fahrt, Bot „Weltklasse“):** 1:52–1:57. Unter 1:51,5 ist schneller als der Rekord, über 2:00 ist zu langsam. Optimum etwa 1:53–1:55.
- **Durchschnittstempo:** 101–107 km/h (3312 m / 112–118 s).
- **Höchsttempo:** typisch 140–145 km/h im Zielschuss. Harte Obergrenze ca. 153 km/h, nur bei extremen Bedingungen.
- **Zwischenwerte als Checkpoints:** 100 km/h nach 8,5 s und 160 m. Mausefalle-Absprung 105–120 km/h. Karussell 60–80 km/h. Steilhang 90–100 km/h. Gleitstücke (Brückenschuss, Gschöss) 90–110 km/h. Alte Schneise ~120 km/h. Seidlalm 80–90 km/h. Oberhausberg 60–80 km/h, das langsamste Stück. Hausbergkante ~100 km/h. Traverse 90–105 km/h. Zielsprung 120–145 km/h.
- **Sprungweiten:** Mausefalle 50–60 m Standard, bis 80 m nur bei Fehlabstimmung. Zielsprung 40–60 m (bis 70–80 m). Kleinere Sprünge (Gschöss, Alte Schneise, Seidlalm, Hausbergkante) 20–40 m (Schätzung).
- **Lasten:** Kurven und Kompressionen 3,0–3,5 g als Spitzenwert (Karussell 3,1 g, Hausberg-Kompression 3,5 g). Sturzschwelle im Spiel knapp darüber ansetzen.
- **Landehärte:** Äquivalente Fallhöhe unter 2 m ist unkritisch, ab 2,5 m gefährlich [HKR-Inkl]. Das eignet sich direkt als Sturz- oder Strafkriterium (2,5 m entsprechen v_vertikal ≈ 7 m/s).
- **Gefälle-Validierung des Terrains:** Max. 85 % in der Mausefalle, 72 % Steilhang, 70 % Hausbergkante, 63 % Zielschuss, 51 % Starthang, Ø 27 %. Ein 25-m-DEM liefert nur ca. 45–55 %. Für die Schlüsselstellen das Gelände lokal nachmodellieren (Kanten schärfen) oder ein höher aufgelöstes DGM verwenden, z. B. das österreichische ALS-DGM 1 m / Tirol 0,5 m (data.gv.at).
- **Verkürzte Varianten** für Wetter- oder Testmodi: Start „Alte Schneise“ (~2 km, Sieg ~1:13), Start „Seidlalm“ (~1,6 km, Sieg ~0:58), Start 40–45 m tiefer (Sieg ~1:52–1:56).

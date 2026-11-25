# Credits & Lizenzen

Schussfahrt (Projekt SkiChallange) verwendet ausschließlich offene Daten und freie Assets.
Diese Liste wird auch im Spiel unter "Credits" angezeigt (`game/data/credits.json`).

## Engine & Werkzeuge
| Komponente | Lizenz | Quelle |
|---|---|---|
| Godot Engine 4.7.2 | MIT | https://godotengine.org |
| GUT – Godot Unit Test 9.7.1 | MIT | https://github.com/bitwes/Gut |
| Terrain3D 1.1.0 | MIT | https://github.com/TokisanGames/Terrain3D |
| GDAL (über rasterio) | MIT | https://gdal.org |

Exportierte Builds enthalten die Godot-Lizenz und Drittanbieter-Hinweise (`Engine.get_license_text()`,
`Engine.get_copyright_info()`), angezeigt im Credits-Screen.

## Geodaten
| Daten | Lizenz | Namensnennung |
|---|---|---|
| Land Tirol: DGM/DOM 50 cm (ALS), Orthofoto | CC BY 4.0 | "Datenquelle: Land Tirol – data.tirol.gv.at" |
| OpenStreetMap (Pistenlinie, Relation 12870777) | ODbL 1.0 | "© OpenStreetMap contributors" |

Aus OSM abgeleitete Dateien (`line.json`, `racing_line.json`, `gates.json`, `sections.json`) stehen als
abgeleitete Datenbank unter **ODbL 1.0** (Share-Alike).

Konkret verwendete Datensätze (abgerufen 2026-11-25, Pipeline `tools/pipeline/`):
- Land Tirol WCS `terrain`: `Gelaendemodell_50cm_M31`, `Oberflaechenmodell_50cm_M31` (EPSG:31255,
  ALS-Mosaik, aktueller Stand des Dienstes; Flugjahre je Kachel 2020er) – CC BY 4.0.
- Land Tirol WCS `orthofoto`: `Aktuell_RGB` (EPSG:31254, 0,5 m abgerufen) – CC BY 4.0, winterlich umgefärbt.
- OpenStreetMap: Route-Relation 12870777 „Streif-Rennstrecke“ und Gebäudeumrisse (`building=*`)
  im Kernausschnitt – ODbL 1.0.

## Assets
| Asset | Verwendung | Lizenz | Quelle |
|---|---|---|---|
| Snow 02 – Rob Tuytel (Poly Haven) | Terrain-Material „Neuschnee“ | CC0 | https://polyhaven.com/a/snow_02 |
| Snow 006 – ambientCG | Terrain-Material „Piste“ (verdichteter Schnee) | CC0 | https://ambientcg.com/view?id=Snow006 |
| Snow Field Aerial – Rob Tuytel (Poly Haven) | Terrain-Material „Waldboden mit Schnee“ | CC0 | https://polyhaven.com/a/snow_field_aerial |
| Rock 032 – ambientCG | Terrain-Material „Fels“ | CC0 | https://ambientcg.com/view?id=Rock032 |
| Horn-Koppe Snow – Grzegorz Wronkowski (Poly Haven) | Himmel/Umgebungslicht (HDRI, `sky_2k.hdr`) | CC0 | https://polyhaven.com/a/horn-koppe_snow |

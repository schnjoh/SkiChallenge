# Datenquellen und Tooling – Streif (Kitzbühel)

Stand: 2026-11-25. Alle Endpunkte unten wurden per `curl` getestet, sofern nicht anders vermerkt.

## 0. Eckdaten Streif (aus OSM + DGM verifiziert)

| | WGS84 (lat, lon) | EPSG:31255 (x, y) | EPSG:31254 (x, y) | Höhe DGM |
|---|---|---|---|---|
| Start (OSM-Rennlinie, erster Knoten) | 47.4263265, 12.3707607 | -72570, 254617 | 153744, 256183 | ~1663 m |
| Ende (OSM-Rennlinie, letzter Knoten) | 47.4441594, 12.3875775 | -71277, 256584 | 154961, 258198 | ~778 m |
| BBox inkl. ~300 m Rand | 47.4223–47.4476, 12.3622–12.3916 | x -73221…-70969, y 254178…256963 | x 153110…155254, y 255718…258589 | |

Die Annahme „Start ~47.4255/12.3700“ stimmt ungefähr. Das Ziel liegt bei ~47.444/12.388 (Rand von Kitzbühel), nicht bei 47.44/12.39. Rennlinie in OSM ≈ 3,37 km (Polylinie). Die offizielle Länge beträgt 3312 m.

**Wichtig – CRS:** Kitzbühel liegt östlich von 11°50' und damit im Tiroler Meridianstreifen **M31 = EPSG:31255 (MGI / Austria GK Central)**. Dort liegen auch die 50-cm-Höhendaten. Die Orthofotos des Landes Tirol gibt es nur in **EPSG:31254 (GK West, M28)**. Höhen sind Gebrauchshöhen (EPSG:5778).

## 1. Land Tirol – DGM / DOM 50 cm

**Lizenz:** CC BY 4.0. Pflicht-Namensnennung gemäß https://www.tirol.gv.at/data/nutzungsbedingungen:
`Datenquelle: Land Tirol - data.tirol.gv.at`
Datensatz: https://www.data.gv.at/katalog/dataset/0454f5f3-1d8c-464e-847d-541901eb021a („Digitales Geländemodell Tirol“, JSON: `https://www.data.gv.at/api/hub/search/datasets/0454f5f3-1d8c-464e-847d-541901eb021a`)

### 1a. Kacheln (Blattschnitt 1:2000) – empfohlen

- Index (ArcGIS FeatureService, öffentlich, ohne Key):
  `https://services3.arcgis.com/hG7UfxX49PQ8XkXh/arcgis/rest/services/als_tif_3857/FeatureServer/0/query?geometry=12.3622,47.4223,12.3916,47.4476&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=NAME,URL,EPSG&returnGeometry=false&f=json`
  Felder: `NAME`, `URL`, `M28`, `M31`, `EPSG`. Analoge Indizes: `als_xyz_3857` (XYZ 1 m), `als_dxf_3857` (Höhenlinien), `als_flugjahr_3857`.
- URL-Muster: `https://gis.tirol.gv.at/geo/als/mosaik_50cm/m31/geotiff/geotiff_50cm_<BLATT>.zip` (für M28: `.../m28/...`, nicht getestet)
- **Streif-Kacheln (9 Stück, alle EPSG:31255):** `3826-30, 3826-31, 3826-32, 3826-38, 3826-39, 3826-40, 3826-46, 3826-47, 3826-48`
- HEAD getestet: `200 OK`, `application/zip`, jeweils ~27–28 MB.
- ZIP-Inhalt (Beispiel 3826-38): `dgm_50cm_3826-38_2020.tif`, `dom_50cm_3826-38_2020.tif`, `dgm_50cm_shd_…tif/.tfw`, `dom_50cm_shd_…tif/.tfw`. Das Suffix `_2020` ist das Flugjahr, also für Skripte per Glob matchen (`dgm_50cm_*.tif`).
- GeoTIFF: 2501×2001 px, 0,5 m, float32, nodata -9999, deflate, EPSG:31255. Die Kachel deckt 1250×1000 m ab, mit Pixelzentren auf vollen 0,5 m (Bounds ±0,25 m). Benachbarte Kacheln überlappen um 1 px.

### 1b. WCS (blattschnittfrei, beliebiger Ausschnitt)

Basis: `https://gis.tirol.gv.at/arcgis/services/Service_Public/terrain/MapServer/WCSServer`

Coverages: `Gelaendemodell_50cm_M31`, `Oberflaechenmodell_50cm_M31`, `Gelaendemodell_50cm_M28`, `Oberflaechenmodell_50cm_M28`, `Gelaendemodell_5m_M28`, `Oberflaechenmodell_5m_M28`, `Gelaendeneigung-Prozent`, `Gelaendeneigung-Grad`, `Gelaendeneigung_Wintersport-Grad`, `Exposition`, `Schummerung_*`.

- **WCS 1.0.0 liefert ein reines GeoTIFF und ist für Skripte am einfachsten** (getestet):
  ```
  ...WCSServer?service=WCS&version=1.0.0&request=GetCoverage&coverage=Gelaendemodell_50cm_M31&crs=EPSG:31255&bbox=-73221,254178,-70969,256963&resx=0.5&resy=0.5&format=GeoTIFF
  ```
- WCS 2.0.1 (`subset=x(..)&subset=y(..)`, axisLabels `y x`) antwortet mit `multipart/related` (GML + TIFF). Das TIFF muss man selbst aus dem MIME-Body schneiden. `mediaType=image/tiff` führt zu einem Fehler.
- Getestet: 2100×2100 m bei 0,5 m (4200×4200 px, ~71 MB) in ~30 s ohne Fehler. Für die gesamte BBox (~4500×5600 px) sollte man sicherheitshalber in 2–4 Teilen anfragen.
- Ausdehnung M31-Coverage: x -120000…-27500, y 167000…291000. Abfragen ins falsche Meridiansystem liefern `InvalidSubsetting`.
- WMS (Darstellung, nicht für Höhenwerte): `.../terrain/MapServer/WMSServer`

### 1c. Landesweit grob (große Dateien)

`https://gis.tirol.gv.at/ogd/geografie_planung/DGM/` + `DGM_Tirol_5m_epsg31255.zip`, `DGM_Tirol_10m_epsg31255.zip`, `DOM_Tirol_5m_epsg31255.zip` (bzw. `…31254`). HEAD: 200, ca. 1,17 GB (DGM 5 m), 310 MB (DGM 10 m), 1,25 GB (DOM 5 m). Für die Umgebung/Fernsicht lieber per WCS mit `resx=5` holen.

Punktwolken (LAZ) und 50-cm-Höhenlinien sind nicht frei. Man bestellt sie per Mail an geodatenbestellung@tirol.gv.at (kostenpflichtig, Stundensatz).

## 2. Orthofotos

### 2a. Land Tirol (20 cm, nur Sommer)
- WCS: `https://gis.tirol.gv.at/arcgis/services/Service_Public/orthofoto/MapServer/WCSServer`
  Coverages: `Aktuell_RGB`, `Aktuell_CIR`, `2022`, `2019_2021`, `2016_2018`, `2013_2015`, … `1940`. **Nur EPSG:31254**, 0,2 m.
  Getestet (WCS 2.0.1, multipart wie oben): `coverageId=Aktuell_RGB&format=image/tiff&subset=x(153000,154000)&subset=y(255500,256500)` ergibt 5000×5000 px RGB uint8, ~79 MB, 35 s.
  Für Skripte: WCS 1.0.0 analog zu 1b mit `crs=EPSG:31254&resx=0.2&resy=0.2` (nicht separat getestet).
- WMS 1.3.0: `https://gis.tirol.gv.at/arcgis/services/Service_Public/orthofoto/MapServer/WMSServer`. Layer `Image_<Jahr>` / `Flugjahr_<Jahr>` (z. B. `Image_2016_2018`). Akzeptierte CRS u. a. EPSG:31254, 31255, 3857 (102100), 25832/25833.
- WMTS „Elektronische Grundkarte Tirol“: `https://wmts.kartetirol.at/wmts` (Capabilities). Tile-URL: `https://wmts.kartetirol.at/gdi_ortho/{z}/{x}/{y}.png` (GoogleMapsCompatible, EPSG:3857). Die Tiles sind tatsächlich JPEG und bis **z18** belegt (z19 liefert eine leere 5-Byte-Antwort). Weitere Layer: `gdi_winter`, `gdi_summer`, `gdi_base_winter`, `gdi_base_summer`, `gdi_nomenklatur`.
- Lizenz: OGD Tirol, CC BY 4.0, Attribution wie in Abschnitt 1. Laut Anleitung PDF https://gis.tirol.gv.at/statisch/AnleitungGeodatendienste.pdf werden Clients, die den Server zu stark belasten, gesperrt. Also drosseln.

### 2b. basemap.at Orthofoto (Alternative, Web-Mercator)
- Capabilities: `https://basemap.at/wmts/1.0.0/WMTSCapabilities.xml`, Layer `bmaporthofoto30cm`, Style `normal`, TileMatrixSet `google3857` (z0–20).
- Tile-URL (**Achtung: erst Row, dann Col**): `https://maps{1-4}.wien.gv.at/basemap/bmaporthofoto30cm/normal/google3857/{z}/{y}/{x}.jpeg`
  Getestet am Start: z18 `…/18/91746/140080.jpeg`, z19 `…/19/183493/280160.jpeg`, beide 200 mit Sommerbild. z20 liefert 404 für diesen Bereich.
- Lizenz: CC BY 4.0. Namensnennung: „Datenquelle: basemap.at“ (mit Link auf https://basemap.at).

**Hinweis:** Beide Orthofotos sind Sommeraufnahmen. Für das Spiel taugen sie als Farb-/Maskenquelle (Wald/Fels/Wiese), müssen aber für eine Schneedecke umgefärbt werden.

## 3. OpenStreetMap – Streif (Overpass)

`overpass-api.de` lieferte zeitweise 502 („at capacity“). Als funktionierender Mirror diente `https://maps.mail.ru/osm/tools/overpass/api/interpreter`. Skripte brauchen Retry mit Backoff. Lizenz: ODbL, „© OpenStreetMap contributors“.

**Route-Relation (am besten geeignet): `12870777`.** Tags: `type=route, route=piste, piste:type=downhill, name=Streif-Rennstrecke, piste:difficulty=expert, oneway=yes, wikidata=Q18091`. BBox 47.4263265,12.3671921 – 47.4443561,12.3875775.

```
[out:json][timeout:60];
relation(12870777)->.r;
way(r.r);out geom;      // geordnete Linienstücke
node(r.r);out;          // benannte Schlüsselstellen
```
```bash
curl -s -A "SkiGameResearch/0.1" --data-urlencode "data@query.overpassql" https://overpass-api.de/api/interpreter
```

Member-Ways in Fahrtrichtung (Knotenanzahl):
`1037424943`(5) → `229220048`(14) → `956695993`(5, name=Walde) → `229220044`(26) → `229220049`(16, „Streif Familienabfahrt“) → `183009202`(8) → `1472105874`(10) → `956695997`(24, „Familienabfahrt“) → `320430167`(22) → `547439924`(7). Zusammen 128 Punkte, ~3373 m. Das ist eine **grobe** Mittellinie mit durchschnittlich ~26 m Punktabstand, also glätten bzw. resamplen. Way-Tags: `piste:type=downhill`, `piste:difficulty=expert`, `piste:grooming=classic|backcountry`, `ref=21`.

Node-Members (`place=locality`, Schlüsselstellen): Mausefalle (47.4277954, 12.3702267), Kompression (47.428137, 12.3693997), Karussell (47.428187, 12.3677218), Steilhang (47.4289994, 12.3674644), Brückenschuss (47.4302615, 12.3684669), Gschöss (47.4327491, 12.3705249), Alte Schneise (47.4355221, 12.3708048), Seidlalmsprung (47.4373397, 12.371848), Lärchenschuss (47.439639, 12.3739168), Oberhausberg (47.4393535, 12.3777399), Hausbergkante (47.4397806, 12.3790278), Traverse (47.4398904, 12.3805973), Zielhang (47.441617, 12.3816507), Zielsprung (47.442485, 12.3833373).

Die Way-Suche `way["piste:type"="downhill"]["name"~"Streif",i](47.40,12.33,47.46,12.42)` findet 18 Ways. Neben den obigen kommen viele „Streif Familienabfahrt“-Ways hinzu (z. B. 229219552, 319921373, 319923954, 364619005, 956695996), dazu die „Mini Streif“ (474426155). Deshalb besser die Relation verwenden.

## 4. Terrain3D (TokisanGames/Terrain3D)

- Neueste Version: **v1.1.0-stable** (2026-10-30), unterstützt laut Release-Notes **Godot 4.5–4.8+**. `terrain.gdextension` hat `compatibility_minimum = 4.5`. Godot 4.7.2 wird damit abgedeckt. v1.0.2 unterstützt 4.4–4.7.
- Download: `https://github.com/TokisanGames/Terrain3D/releases/download/v1.1.0-stable/Terrain3D_v1.1.0-stable.zip`. Enthält `addons/terrain_3d/bin/libterrain.linux.{debug,release}.x86_64.so`, **Linux x86_64 ist also enthalten**. Entpacken nach `res://addons/terrain_3d/`. API-Änderungen gegenüber 1.0 sind in https://github.com/TokisanGames/Terrain3D/discussions/756 beschrieben.
- Heightmap-Import: Empfohlen sind **EXR** (float, echte Höhen in Metern, RGB, ohne Alpha) oder **R16/RAW** (normalisiert 0–65535, Min/Max separat merken). PNG geht nur mit 8 Bit und erzeugt Treppen, also nicht verwenden.
- Per GDScript zur Laufzeit möglich:
  ```gdscript
  var img := Image.load_from_file("res://data/streif_dgm.exr")  # FORMAT_RF
  terrain.region_size = Terrain3D.SIZE_1024
  terrain.vertex_spacing = 0.5
  terrain.data.import_images([img, null, null], Vector3(-1024, 0, -1024), 0.0, 1.0)
  # Signatur: import_images(images: Array[Image], global_position := Vector3.ZERO, offset := 0.0, scale := 1.0)
  # Höhen werden NICHT normalisiert; scale wird nach offset angewendet.
  ```
  Einzelwerte lassen sich mit `data.set_height(pos, h)` + `data.update_maps()` setzen. Für Massenänderungen `Terrain3DRegion.get_map()` verwenden.
- Regionen: `region_size` ∈ {64, 128, 256 (Default), 512, 1024, 2048} Vertices. Maximal 1024 Regionen (32×32), gültige Position ±16 Regionen um den Ursprung. Faustregel für den Import: `region_size > Bildbreite/32`.
- `vertex_spacing`: Default 1.0, bis 100, skaliert lateral. Mit 0,5 m (native DGM-Auflösung) und `SIZE_1024` umfasst die Fläche maximal 32×1024×0,5 = 16,4 km pro Seite, was für die Streif-BBox (~2,3×2,8 km, ~4500×5600 px) locker reicht.
- Bekannte Probleme mit Godot 4.7:
  - Issue #1066 (offen): Mit GodotPhysics in der Nähe von Terrain-Löchern gibt es eine Flut von Warnungen „Vector3 cannot be normalized“, die zu Ruckeln führt. Abhilfe: Jolt verwenden oder keine Löcher bauen.
  - Issue #1043 (geschlossen): Kollision fehlt bei `precision=double`-Builds. Das ist nur bei eigenen Builds relevant.
  - #993 („Update to accommodate Godot 4.7“) ist geschlossen.

## 5. GUT (bitwes/Gut)

- Für Godot 4.7.x: **GUT 9.7.1** (2026-07-10, Branch `godot_4_7`). Die Asset Library und `releases/latest` zeigen nur 9.6.1 (für 4.6), also manuell installieren:
  `https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip`, daraus `addons/gut` ins Projekt kopieren und das Plugin aktivieren.
- Breaking Change ab 9.7.0: Doubles geben typgerechte Defaults statt `null` zurück, wegen der strengeren Return-Type-Prüfung in Godot 4.7.
- Headless-Lauf (vorher einmal importieren, damit `class_name`-Cache und Imports existieren):
  ```bash
  godot --headless --path game --import
  godot --headless --path game -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=res://test_results.xml
  ```
  Exit-Code 0 bedeutet alle Tests grün, 1 bedeutet Fehler. Standardoptionen können in `res://.gutconfig.json` stehen (`-gconfig=` überschreibt, `-gprint_gutconfig_sample` zeigt ein Beispiel).

## 6. CC0-Assets (Lizenzen geprüft)

**Sky-HDRI (Poly Haven, CC0, Autor Grzegorz Wronkowski):**
- Passendorf Snow (Schnee, Wald, klarer Himmel): `https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/4k/passendorf_snow_4k.exr` (HEAD 200, 82 MB) bzw. `…/HDRIs/hdr/2k/passendorf_snow_2k.hdr`
- Horn-koppe Snow: `https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/4k/horn-koppe_snow_4k.exr`
- Alternativen: `pizzo_pernice` (Alpen, klar, Mittag), `kiara_5_noon`. API-Muster: `https://api.polyhaven.com/files/<id>`.

**Schnee-PBR:**
- Poly Haven `snow_02` (glatt, pulvrig): `https://dl.polyhaven.org/file/ph-assets/Textures/png/2k/snow_02/snow_02_{diff,nor_gl,rough,disp,ao}_2k.png`. Godot nutzt OpenGL-Normalen, also `nor_gl`. Weitere: `snow_01`, `snow_03`.
- ambientCG (CC0): `https://ambientcg.com/get?file=Snow006_2K-JPG.zip` (302-Redirect auf das CDN). Weitere IDs: Snow002, 004, 005, 007A–C, 008A–C, 009A–C, 010A–C, 011–015. Suche per API: `https://ambientcg.com/api/v2/full_json?q=snow&type=Material&include=downloadData`.

**Nadelbäume (Low-Poly, CC0):**
- Quaternius „Stylized Nature MegaKit“ (glTF/FBX/OBJ, Pine-Varianten): https://quaternius.com/packs/stylizednaturemegakit.html bzw. https://quaternius.itch.io/stylized-nature-megakit (der Standard-Zip ist gratis)
- Quaternius „Textured LowPoly Trees“ (Pines): https://quaternius.itch.io/textured-lowpoly-trees
- Kenney „Nature Kit“ (CC0): https://kenney.nl/assets/nature-kit
- Kenney und itch.io bieten keine stabile Direkt-URL (der Download läuft über Button bzw. Hash-URL). Diese Pakete daher einmalig manuell laden und in `data/`/`reference/` ablegen.

**Sounds (Freesound, jeweils auf der Seite als „Creative Commons 0“ geprüft):**

| Zweck | Sound | Seite | Vorschau (mp3, ohne Login) |
|---|---|---|---|
| Ski-Vorbeifahrt / Kanten | Ski passby (cribbler, 6 s) | https://freesound.org/people/cribbler/sounds/592379/ | https://cdn.freesound.org/previews/592/592379_3728489-hq.mp3 |
| Ski-POV-Fahrt | Alpine_ski_POV (Lydmakeren, 3:29) | https://freesound.org/people/Lydmakeren/sounds/567839/ | https://cdn.freesound.org/previews/567/567839_11157357-hq.mp3 |
| Wind (Alpen) | mountain wind heavy strong gusts Swiss Alps (kyles, 2:51) | https://freesound.org/people/kyles/sounds/454092/ | https://cdn.freesound.org/previews/454/454092_612689-hq.mp3 |
| Wind (synth., loopbar) | Wind Arctic Cold (Qvantor, 33 s) | https://freesound.org/people/Qvantor/sounds/877968/ | https://cdn.freesound.org/previews/877/877968_19512113-hq.mp3 |
| Publikum | crowd large cheer arena stadium (kyles, 24 s) | https://freesound.org/people/kyles/sounds/629884/ | https://cdn.freesound.org/previews/629/629884_612689-hq.mp3 |
| Publikum | Crowd Cheer (FoolBoyMedia, 20 s) | https://freesound.org/people/FoolBoyMedia/sounds/397434/ | https://cdn.freesound.org/previews/397/397434_4019029-hq.mp3 |

Originaldateien (WAV/FLAC) gibt es nur mit Login oder per API mit OAuth2. Die HQ-mp3-Previews sind ohne Login abrufbar. Suchfilter: `https://freesound.org/search/?q=ski&f=license:"Creative Commons 0"`. Freesound antwortet bei schnellen Anfragen mit 429, also drosseln. Bei Kenney gibt es keine passenden Ski- oder Windsounds (nur UI/Impact).

## 7. Python-Tooling (Python 3.14, Linux x86_64, ohne sudo)

Getestet in einem venv mit `pip install --only-binary=:all:`:
- ✅ `rasterio 1.5.2` (bringt eigenes GDAL mit), `pyproj 3.8.0`, `numpy 2.5.5`. Diese Wheels sind für cp314 vorhanden.
- ❌ `GDAL` (osgeo-Bindings) hat keine Wheels und bräuchte System-libgdal plus Build. ❌ `fiona` hat kein cp314-Wheel. CLI-Tools (`gdalinfo`, `gdal_translate`) sind nicht installiert.
- Empfehlung: Mit rasterio + pyproj + numpy auskommen (Mosaik per `rasterio.merge`, Reprojektion per `rasterio.warp`). Den OSM-Teil mit reinem `json` bzw. `urllib` erledigen. EXR für Godot schreiben: das `OpenEXR`-Wheel prüfen oder RAW/R16 bzw. float32 `.res` aus Godot heraus erzeugen (nicht getestet).

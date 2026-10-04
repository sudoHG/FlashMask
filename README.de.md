# Flash Mask

[![Release](https://img.shields.io/github/v/release/sudoHG/FlashMask?style=flat-square&label=release)](https://github.com/sudoHG/FlashMask/releases/latest) [![Stars](https://img.shields.io/github/stars/sudoHG/FlashMask?style=flat-square&label=stars)](https://github.com/sudoHG/FlashMask/stargazers) [![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)](https://apps.apple.com/de/app/flash-mask/id6803817818?mt=12) [![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-black?style=flat-square)](https://apps.apple.com/de/app/flash-mask/id6803817818?mt=12) [![README views](https://hits.sh/github.com/sudoHG/FlashMask.svg?style=flat-square&label=README%20views)](https://hits.sh/github.com/sudoHG/FlashMask/)

**Schnelle Bildmasken, die der KI genau zeigen, wo bearbeitet werden soll.**

<a href="https://apps.apple.com/de/app/flash-mask/id6803817818?mt=12"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/de-de?size=250x83" alt="Laden im Mac App Store" height="54"></a>

> „Nicht das – das daneben.“ Wie oft mussten Sie das schon einer KI sagen?  
> Sie möchten ein einzelnes Detail anpassen, und das Modell generiert das gesamte Bild neu. Bisher bedeutete die Behebung, einen schwerfälligen Bildeditor für mühsame Auswahlen und Exporte zu starten.  
> Flash Mask verkürzt diesen gesamten Prozess auf wenige Sekunden: Bild hineinziehen, den gewünschten Bereich umranden und strukturierte JSON-Koordinaten direkt an Ihre KI oder Ihren Agenten kopieren, damit genau bekannt ist, wo bearbeitet werden soll. Wenn Sie pixelgenaue Präzision benötigen, exportieren Sie mit einem Klick eine 1:1-Schwarz-Weiß-Maske.

![Flash Mask auf macOS: Umranden eines Bildbereichs und Kopieren von JSON-Koordinaten für einen KI-Agenten](assets/app-screenshot.png)

---

## Übersicht

Flash Mask ist eine schlanke, native macOS-Begleit-App für KI-Bildbearbeitung und visuelle Workflows. Bei der Zusammenarbeit mit KI-Modellen oder Coding-Agenten reichen reine Text-Prompts oft nicht aus, um exakte Grenzen zu definieren, was zu unbeabsichtigten Änderungen im gesamten Bild oder zu Bearbeitungen an der falschen Stelle führt.

Unter macOS gibt Flash Mask JSON 1.1 mit einer Anweisung für das gesamte Bild und optionalen Notizen für einzelne Regionen aus. Die Web-App auf der Website bleibt bei JSON 1.0.

### Mac-App

- Fügen Sie einen Screenshot direkt aus der Zwischenablage ein.
- Fügen Sie eine Anweisung für das gesamte Bild und optionale Notizen für einzelne Regionen hinzu.
- Nutzen Sie die Benutzeroberfläche in sieben Sprachen: Englisch, vereinfachtes Chinesisch, traditionelles Chinesisch, Japanisch, Deutsch, Französisch und Spanisch.
- Verwenden Sie ein eigenes Einstellungsfenster, um die Sprache zu wechseln, nach Updates zu suchen und die Website, Hilfe, den GitHub-Quellcode oder die Support-Seite zu öffnen.

Statt sich in komplexen Bildbearbeitungsprogrammen mit Lasso-Werkzeugen, Füllebenen und manuellen Exporten abzumühen, wandelt Flash Mask Ihre Auswahlen in Sekundenschnelle in agentengerechte Koordinaten um:

- **Strukturierte JSON-Koordinaten als Standard**: Kopieren Sie standardisiertes JSON mit Pixelkoordinaten, normalisierten Koordinaten, Abmessungen des Quellbilds, lokalen absoluten Dateipfaden und optionalen Bearbeitungsanweisungen (Prompts) mit einem Klick. Fügen Sie es direkt in Ihren KI-Chat oder Agenten-Workflow ein.
- **1:1-Schwarz-Weiß-PNG-Maske bei Bedarf**: Exportieren Sie für Inpainting-Modelle und traditionelle Pipelines, die pixelgenaue Masken erfordern, eine gestochen scharfe PNG-Maske in den Originalabmessungen des Bildes (rein weiße Auswahl, rein schwarzer Hintergrund, keine weichen Kanten oder Anti-Aliasing).
- **100 % lokal, offline und privat**: Bilddekodierung, Koordinatenberechnungen und Masken-Rendering laufen vollständig auf Ihrem Mac. Es werden niemals Bilder, Dateipfade, Koordinaten oder Prompts hochgeladen. Keine Accounts, keine Anmeldungen, keine Werbung und keine Tracking-SDKs.
- **Fokus auf räumliche Zielauswahl – kein integrierter KI-Lock-in**: Flash Mask konzentriert sich darauf, klar zu kommunizieren, *wo bearbeitet werden soll* und *was geändert werden soll*. Die eigentliche Bildgenerierung und -bearbeitung übernimmt Ihr bevorzugtes KI-Tool oder Ihr Agent – ohne Vendor-Lock-in oder Cloud-Abhängigkeiten.

## Anwendungsbereiche

- **Charakter-Art & Nachbearbeitung von KI-Generierungen**: Umranden Sie Hände, Gesichtszüge, Kleidung oder Accessoires, um gezieltes Inpainting zu steuern, während der Rest des Bildes unverändert bleibt.
- **Fotobereinigung & Entfernen von Objekten**: Rahmen Sie Personen im Hintergrund, störende Elemente, Wasserzeichen oder Makel schnell ein, damit Bildbearbeitungs-Agenten sie sauber entfernen und per Inpainting auffüllen können.
- **Bearbeitung von Postern & Marketing-Assets**: Markieren Sie spezifische Textlayouts, Produktmotive oder Grafikelemente, die in Postern, Bannern und E-Commerce-Assets ersetzt werden müssen.
- **UI-Bug-Hinweise für Coding-Agenten**: Lokalisieren Sie visuelle Fehler in UI-Screenshots – wie abgeschnittenen Text, überlappende Steuerelemente oder Fehlausrichtungen im Layout im iOS-Simulator, in macOS-Apps, Canvas, WebGL, Karten, Diagrammen oder Spiele-UIs – und übergeben Sie sowohl exakte Koordinaten als auch Korrekturanweisungen direkt an Ihren Coding-Agenten.

## Schnellstart

1. **Bild öffnen**: Ziehen Sie ein PNG-, JPEG/JPG- oder WebP-Bild per Drag-and-Drop in das Fenster, klicken Sie auf **Bild öffnen** oder fügen Sie einen Screenshot aus der Zwischenablage ein. Verschieben, zoomen und wechseln Sie zwischen den Ansichten **Anpassen** und **Originalgröße** (1:1-Pixel).
2. **Regionen umranden und verfeinern**:
   - Klicken und ziehen Sie auf dem Bild, um einen Freihandbereich zu umranden; lassen Sie die Maustaste los, um ihn hinzuzufügen. Zeichnen Sie bei Bedarf mehrere separate Regionen (werden automatisch als Vereinigung zusammengeführt).
   - Klicken Sie auf eine bestehende Region, um sie fein abzustimmen: Ziehen Sie die gesamte Auswahl, um sie neu zu positionieren, oder verschieben, ergänzen und löschen Sie einzelne Polygon-Eckpunkte.
   - Optional: Geben Sie im Feld **„Was soll Ihr Agent tun?“** eine Anweisung für das gesamte Bild ein und wählen Sie dann eine Region aus, um eine Notiz für diese Region hinzuzufügen.
3. **JSON kopieren oder Maske exportieren**:
   - Klicken Sie auf **JSON kopieren**: Kopiert strukturierte Daten – einschließlich des lokalen Dateipfads, der Bildabmessungen, Polygonkoordinaten und des Bearbeitungs-Prompts – in Ihre Zwischenablage, um sie direkt in Ihre KI oder Ihren Agenten einzufügen.
   - Klicken Sie auf **Masken-PNG exportieren**: Öffnet den macOS-Speichern-Dialog, um eine gestochen scharfe Schwarz-Weiß-PNG-Maske passend zu den Abmessungen des Quellbildes zu exportieren. Die Maske markiert die ausgewählten Bereiche; Notizen sind im JSON enthalten.

## JSON-Koordinatendatenformat

Flash Mask gibt versioniertes, selbsterklärendes JSON mit dualen Koordinatensystemen aus – absolute Pixelkoordinaten und normalisierte `[0.0, 1.0]`-Koordinaten (Ursprung oben links, X nach rechts ansteigend, Y nach unten ansteigend). Die Mac-App verwendet JSON 1.1; die Web-App der Website verwendet JSON 1.0:

```json
{
  "mask_spec_version": "1.1",
  "instruction": "This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. The top-level `prompt`, if present, applies to the whole image. Each region's `prompt`, if present, applies only to that region. Interpret these texts in the context of the current conversation. The combined geometry marks range only; it does not assign a processing order among regions.",
  "source_image": {
    "file_name": "example.jpg",
    "width": 1920,
    "height": 1080,
    "file_path": "/Users/username/Pictures/example.jpg"
  },
  "coordinate_system": {
    "origin": "top-left",
    "x_direction": "right",
    "y_direction": "down"
  },
  "prompt": "Keep the building",
  "regions": [
    {
      "id": 1,
      "shape": "polygon",
      "points_px": [[96, 108], [480, 108], [480, 432], [96, 432]],
      "points_normalized": [[0.05, 0.1], [0.25, 0.1], [0.25, 0.4], [0.05, 0.4]],
      "prompt": "Remove stray lines"
    },
    {
      "id": 3,
      "shape": "polygon",
      "points_px": [[600, 108], [900, 108], [900, 432], [600, 432]],
      "points_normalized": [[0.3125, 0.1], [0.46875, 0.1], [0.46875, 0.4], [0.3125, 0.4]],
      "prompt": "Use a light gray background"
    }
  ]
}
```

### Feldreferenz

- `mask_spec_version`: Spezifikationsversion. Die Mac-App gibt derzeit `"1.1"` aus; die Web-App der Website verbleibt bei `"1.0"`.
- `instruction`: Eingebettete, selbsterklärende Handlungsanweisung, die nachgelagerten KI-Modellen oder Agenten mitteilt, wie Polygone und die Absicht des Nutzers zu interpretieren sind.
- `source_image`: Name der Quelldatei, Pixelabmessungen (`width`, `height`) und der absolute lokale Mac-Dateipfad (`file_path` ist spezifisch für die macOS-App, damit lokale Agenten direkt auf die Datei zugreifen können).
- `coordinate_system`: Definition des Koordinatensystems (festgelegt auf Ursprung oben links, X nach rechts ansteigend, Y nach unten ansteigend).
- `prompt`: Optional. In Mac-JSON 1.1 gilt diese Anweisung für das gesamte Bild.
- `regions`: Liste der markierten Regionen. Jede Region enthält ganzzahlige Pixelkoordinaten (`points_px` als `[x, y]`) und dimensionslose normalisierte Koordinaten (`points_normalized` als `[x/width, y/height]`). Mac-JSON 1.1 kann einen optionalen `prompt` für eine bestimmte Region enthalten; Regions-IDs bleiben stabil, wenn eine andere Region gelöscht wird. Start- und Endpunkte schließen sich automatisch, und mehrere Regionen bilden eine gemeinsame Vereinigung.

Strikte JSON-1.0-Verbraucher müssen ihren Validator aktualisieren, bevor sie JSON 1.1 akzeptieren können. Flash Mask verwirft Regionsnotizen nicht stillschweigend.

## Funktionen

- **Breite Formatunterstützung**: Importieren Sie PNG-, JPEG/JPG- und WebP-Bilder.
- **Mehrfach-Regionsauswahl**: Zeichnen Sie mehrere unregelmäßige Auswahlen auf einem einzelnen Bild; Auswahlen werden beim Export automatisch zu einer einheitlichen Maske kombiniert.
- **Interaktive Eckpunktbearbeitung**: Ziehen Sie ganze Auswahlen, um sie neu zu positionieren, oder fügen Sie Polygon-Eckpunkte präzise hinzu, verschieben oder entfernen Sie sie.
- **Reibungslose Canvas-Navigation**: Nahtloses Verschieben und Zoomen mit schnellen Umschaltmöglichkeiten zwischen den Ansichten **Anpassen** und **Originalgröße** (1:1-Pixel).
- **Bild- und Regionsnotizen**: Fügen Sie in der Mac-App eine optionale Anweisung für das gesamte Bild und Notizen für einzelne Regionen hinzu.
- **Duale Koordinatensysteme**: Generiert sowohl absolute Pixelkoordinaten als auch auflösungsunabhängige normalisierte Koordinaten zur Unterstützung verschiedener Agenten- und Modell-Schemas.
- **Treue zur Originalauflösung**: Schwarz-Weiß-PNG-Masken entsprechen den Abmessungen des Quellbildes im Verhältnis 1:1, gerendert mit rein weißen Auswahlen, rein schwarzem Hintergrund und gestochen scharfen, ungeglätteten Kanten.
- **Direkte lokale Dateipfade**: Die macOS-App gibt verifizierte absolute Dateipfade im JSON aus, sodass lokale Automatisierungsskripte und Agenten Dateien sofort lokalisieren können.
- **Sieben Sprachen für die Benutzeroberfläche**: Englisch, vereinfachtes Chinesisch, traditionelles Chinesisch, Japanisch, Deutsch, Französisch und Spanisch. Die App folgt standardmäßig Ihrer Systemsprache; wechseln Sie jederzeit über das Sprachmenü in der oberen Leiste oder in den Einstellungen, ohne Ihr aktuelles Bild, Ihre Regionen oder Notizen zu verlieren.
- **Datenschutz & Offline-First**: Läuft zu 100 % lokal ohne erforderliche Anmeldung, ganz ohne Werbung und ohne Tracking- oder Analyse-SDKs.

## Flash Mask erhalten

- **Mac App Store**: Holen Sie sich die offizielle, vorkompilierte App im [Mac App Store](https://apps.apple.com/de/app/flash-mask/id6803817818?mt=12). Ein Einmalkauf mit lebenslangem Zugriff – keine Abonnements und keine In-App-Käufe.
- **Offizielle Website**: Besuchen Sie [flashmask.net](https://flashmask.net/) für Produkt-Updates und Details.
- **Quellcode-Releases**: Laden Sie Quellcode-Archive von [GitHub Releases](https://github.com/sudoHG/FlashMask/releases) herunter. *(Hinweis: Offizielle Binär-Builds werden ausschließlich über den Mac App Store vertrieben; GitHub Releases enthält keine vorkompilierten Binärdateien).*

## Open-Source-Umfang

Dieses Repository stellt den vollständigen Open-Source-Code für den macOS-Client von Flash Mask bereit, einschließlich:
- Nativer macOS-AppKit- / WKWebView-Host-Wrapper und Xcode-Projekt (`macos/`)
- Eingebetteter HTML- / JavaScript-Editor-Kern (`index.html`)
- Koordinatenvertrag-Protokoll-Parsing, Auswahl-Eckpunktbereinigung und Maskengenerierungslogik (`src/`)
- Validierungsschemas für die JSON-Koordinatenverträge von Flash Mask 1.0 und 1.1 (`schemas/`)
- Automatisierte Core-Vertrags- und Unit-Testsuite (`tests/`)

*Hinweis: Dieses Repository enthält die eigenständige macOS-Anwendung und ihren Bearbeitungskern. Es enthält keine eigenständigen Web-Deployment-Skripte oder kommerziellen Backend-Dienste (wie Marketing-Landingpages, Kontingent-/Werbesysteme, Analysen oder gehostete Infrastruktur). Unter der Apache-2.0-Lizenz können das Kernbearbeitungsmodul und die gemeinsamen Datenverträge frei portiert und angepasst werden.*

## Mitwirken

Details zu lokalen Prüfungen, CI-Abdeckung und Pull-Requests finden Sie im [Leitfaden für Beiträge](贡献指南.md).

## Kompilieren der Mac-App aus dem Quellcode

### Voraussetzungen

- Ein Mac mit einer vollständigen **Xcode**-Installation; die Host-macOS-Version muss von dieser Xcode-Version unterstützt werden
- Die App zielt auf **macOS 13.0 oder neuer** ab und wird als Universal Binary (`arm64` + `x86_64`) kompiliert
- Reiner Swift-, AppKit- und WebKit-Build – keinerlei externe Swift-Package-Abhängigkeiten

### Build-Befehl

Führen Sie den folgenden Befehl im Stammverzeichnis des Repositorys aus:

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Speicherort der Build-Ausgabe**: `.derivedData/local/Build/Products/Release/Flash Mask.app`

Dieser Befehl erstellt einen unsignierten lokalen Build, kompiliert den nativen Wrapper und bündelt `index.html` sowie die Anwendungsressourcen zu einer eigenständigen App. Die Release-Konfiguration zielt auf macOS 13.0 ab und erstellt sowohl `arm64`- als auch `x86_64`-Slices. Der offizielle App-Store-Build wird über den separaten Xcode-Archivierungs- und Distributions-Workflow erstellt, nicht über diesen lokalen Build-Befehl.

### Ein-Befehl-Build-Skript

Alternativ können Sie das mitgelieferte `build.sh`-Skript verwenden (führen Sie `./build.sh --help` für Details aus):

```sh
./build.sh
./build.sh --version 1.3.1 --build-number 9 --dmg
```

Das Skript verwendet standardmäßig die Version `1.3` und den Build `8`; `--version` und `--build-number` überschreiben diese Werte. Es überprüft die Version der erstellten App, die minimale macOS-Version und beide Architektur-Slices. `--dmg` packt diese unsignierte App für lokale Tests; die resultierende DMG-Datei ist nicht für die Gatekeeper-Verteilung geeignet.

Für den Vertrieb außerhalb des Mac App Store signieren Sie die App mit Ihrer eigenen **Developer ID Application**-Identität und einem sicheren Zeitstempel, überprüfen Sie deren Code-Signatur, reichen Sie sie zur Notarisierung ein und heften (staple) und validieren Sie das akzeptierte Ticket. Packen Sie anschließend genau diese App mit:

```sh
./build.sh --package-app "/path/to/stapled/Flash Mask.app"
```

`--package-app` überprüft die Developer-ID-Signatur, den sicheren Zeitstempel, das Notarisierungs-Ticket, das Minimum von macOS 13.0 sowie beide Architektur-Slices und erstellt anschließend eine versionierte DMG-Datei, ohne `xcodebuild` auszuführen oder erneut zu signieren. Die DMG-Datei selbst bleibt unsigniert; das Signieren, Notarisieren und Heften dieses äußeren Containers sind separate Schritte für den direkten Vertrieb. Das Hilfsskript signiert, notarisiert, archiviert oder erstellt keinen offiziellen App-Store-Build. Abgeleitete Builds müssen ihre eigene Bundle-ID, ihren eigenen App-Namen und ihre eigenen Marken-Assets verwenden.

## Ausführen der Core-Tests

Das Ausführen der Testsuite für Core-Protokolle und -Logik erfordert **Node.js 22** oder neuer. (*Node.js wird ausschließlich zum Testen von Verträgen und Algorithmen verwendet; das Kompilieren der macOS-App selbst erfordert kein Node.js*).

```sh
npm ci --ignore-scripts
npm test
```

Die Testsuite umfasst:
- Schema-Validierung des JSON-Koordinatenvertrags für macOS- und Web-Ziele
- Plattformspezifische Feldbeschränkungen und Auslassungsregeln
- Polygon-Geometrieberechnungen und Lasso-Eckpunktvereinfachung (Glättung und Entfernung von Redundanzen)
- Pixel-Rasterungsgenauigkeit für 1:1-Schwarz-Weiß-PNG-Masken
- Leistungsgrenzen und Sicherheitsvorkehrungen für Eckpunkt-Limits
- Lokalisierungsressourcen: identische Schlüssel, Platzhalter und gepaarte Bundle-Ressourcen in allen sieben Sprachen

Unter macOS kompiliert und führt `npm test` auch die nativen Swift-Tests aus (Lokalisierungsressourcen und Platzierung des Einstellungsfensters), die kurzzeitig Testfenster öffnen. Führen Sie die nativen Benutzeroberflächentests separat mit `node --test tests/mac-localization-ui.js` aus. Die CI führt die Core-Tests unter Linux sowie die nativen Tests und Oberflächentests auf Apple Silicon macOS 15, Intel und macOS 14 aus; siehe [Leitfaden für Beiträge](贡献指南.md).

## Verzeichnisstruktur

| Pfad | Beschreibung |
|---|---|
| `index.html` | Eingebettete Editor-Oberfläche, Canvas-Interaktionen und UI-Zustandsautomat |
| `src/` | Parsing des Koordinatenvertrags, Maskenrasterung und Algorithmen zur Bereinigung von Auswahl-Eckpunkten |
| `src/localizations/` | Oberflächentexte für alle sieben Sprachen, eine JSON-Datei pro Sprache |
| `scripts/` | Build-Skript, das die gepaarten Lokalisierungsressourcen validiert und paketiert |
| `schemas/` | Offizielle JSON-Schema-Definitionen für die Flash Mask 1.0 und 1.1 Koordinatenverträge |
| `macos/` | Nativer AppKit- / WKWebView-Host-Wrapper, sicherheitsbezogener Dateizugriff (Security-Scoped) und Xcode-Projekt |
| `tests/` | Unit-Tests, Vertragsvalidierungssuiten und Test-Fixtures |

## Lizenz & Hinweise

Der ursprüngliche Quellcode von Flash Mask ist unter der [Apache License 2.0](LICENSE) lizenziert. Vorbehaltlich der Lizenzbedingungen dürfen Sie diese Software frei verwenden, modifizieren und verbreiten, einschließlich in kommerziellen und proprietären abgeleiteten Werken.

- Urheberrechts- und Namensnennungshinweise sind in [NOTICE](NOTICE) dokumentiert.
- Drittanbieterkomponenten und -abhängigkeiten sind in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) aufgeführt.
- Marken-Assets – einschließlich des Namens „Flash Mask“, Logos und Anwendungssymbolen – sind unter separaten [Marken-Asset-Bedingungen](BRAND_ASSETS.md) geschützt und von der Apache-2.0-Lizenzgewährung ausgenommen.
- **Eigentum an Benutzerdaten**: Alle mit Flash Mask generierten JSON-Koordinatendaten, Bilder und PNG-Masken gehören vollständig dem Benutzer und unterliegen nicht der Apache-2.0-Lizenz.

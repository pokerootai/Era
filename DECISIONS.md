# Era - Entscheidungen (Spec 0: was nicht in der Spec steht, ist hier dokumentiert)

Build v27.0.0, Basis: v3.1 (commit e553ea4). Maltes Vorgaben: Apple Music komplett
weg, komplett offline/lokal (kein CloudKit, kein iCloud-Storage), alles andere aus
der Handoff-Spec rein. Versionsnummer Apple-orientiert: 27.0.0 (Major = kommendes Jahr).

## Vom Auftrag ueberschrieben
- **Kein MusicKit / Apple Music**: Spec-Schritt 8 entfaellt komplett. Kein Katalog,
  keine Katalog-Suche, kein Katalog-Artwork.
- **Kein CloudKit / Sync**: Spec-Schritt 9 entfaellt. Persistenz liegt trotzdem
  hinter Repository-Protokollen (`SongRepository`, `TagRepository`, `PackRepository`,
  `PlaylistRepository` in `Persistence.swift`) - ein Sync-Backend ist spaeter
  nachruestbar, ohne die App anzufassen.
- **Datei-Import per UIKit-`UIDocumentPickerViewController` (asCopy: true)** statt
  SwiftUI `.fileImporter`: `.fileImporter` schliesst auf echten iPhones den Picker
  nicht und feuert den Callback nie (bekannter iOS-Bug, in v3.1 live erlebt).
  `asCopy` braucht zusaetzlich keinen Security-Scoped-Zugriff.

## Selbst entschieden (Spec liess es offen)
- **Metadaten-Bearbeitung ist nicht-destruktiv**: Edits landen in der Era-Datenbank
  (Version-Overrides bzw. Song-Felder), die Audiodatei selbst wird nie veraendert.
  FLAC-Metadaten werden gelesen (eigener Vorbis-Comment-Parser, PICTURE-Block fuer
  Cover), aber nicht in die Datei zurueckgeschrieben.
- **Akzentfarbe**: System-Tint (kein eigener Farbverlauf wie in v3). Vorgabe war
  "keine eigene Design-Sprache".
- **Dark/Light Mode**: folgt dem System (v3 forcierte Dark Mode).
- **Deployment Target iOS 18.0**: alle iOS-26-APIs (Liquid Glass, Tab-Minimierung,
  Bottom-Accessory) hinter `#available`; iOS 18 bekommt klassische Materialien.
  Kompilierbarkeit fuer iOS 18 ist durch das Deployment Target abgesichert; ein
  iOS-18-Simulatorlauf entfaellt, weil der Runner nur die iOS-26-Runtime traegt
  (Download einer zweiten Runtime sprengt das CI-Zeitbudget).
- **String Catalog**: `Sources/Resources/Localizable.xcstrings`, Source-Language `de`.
  Deutsche Literale im Code sind die Source-Strings; der Catalog ist der
  Erweiterungspunkt fuer spaetere Sprachen.
- **Share Extension**: eigenes Target `EraShareExtension`. Unsigniert ohne
  App-Groups-Entitlement funktioniert der Datei-Handover nicht; die Extension faellt
  dann auf einen Hinweis-Dialog zurueck ("Era öffnen und dort importieren"). Mit
  signierter Installation + App Group `group.de.malte.era` landen Dateien in einer
  Inbox. (Spec 15.1: "Share Extension nur eingeschraenkt" unsigniert testbar.)
- **Dupe-Kriterium**: SHA-256 ueber dekodierte PCM-Frames plus Dauer (Toleranz 0,5 s).
  Exakter Hash-Match = "schon in der Bibliothek", keine zweite Version (Spec 4).
- **Automatische Verknuepfung**: nur Titel-Aehnlichkeit als Vorschlag im
  Massenimport ("Gehoert das zu X?"), nie automatisch (Spec 11.1).
- **Primäre Version**: erste importierte Version, manuell umstellbar im
  Song-Kontextmenue. Reihenfolge der Versionsliste: Jahr, dann Sort-Index.
- **Migration v3.1 -> v27**: die alte `library.json` wird beim ersten Start in das
  SwiftData-Modell uebernommen (Titel/Artist/Album/Favorit/PlayCount, Dateien
  bleiben liegen) und danach in `library-v3-migriert.json` umbenannt.
- **Monetarisierung**: alles frei, kein Feature-Flag noetig, solange es keine
  Bezahlfunktion gibt (Spec 16).

## Offen (bewusst nicht entschieden)
- iPad-/Mac-Optimierung (Spec: "spaeter"): Layout ist adaptiv (NavigationStack,
  Size Classes, keine fixen iPhone-Groessen), aber nicht iPad-verfeinert.

# Brahui Dictionary

Offline-first Flutter app for browsing the project’s Brahui–Urdu–English dictionary on Android and Web. The app bundles `assets/data/dictionary.built.json`; it makes no network requests for dictionary, search, favourites, history, or settings.

## Run

Install Flutter stable and Android Studio (for Android), then:

```sh
flutter pub get
flutter run -d <android-device>
flutter run -d chrome
```

To build the installable web app:

```sh
flutter build web --release
```

Serve the contents of `build/web` over HTTPS (or localhost). `web/service-worker.js` caches the shell and same-origin Flutter assets as the browser loads them; dictionary JSON and fonts are included as bundled Flutter assets. After the first successful online load, reload while offline to use the cached app. Keep the service worker and `manifest.json` at the web root when hosting under a subpath; set Flutter’s base href accordingly.

## Rebuild the dictionary

Keep the original source as `data.json` in the project root. Run:

```sh
dart run tool/build_dictionary.dart
# Or supply a different input JSON path:
dart run tool/build_dictionary.dart ./path/to/data.json
```

The script leaves `data.json` unchanged and writes `assets/data/dictionary.built.json` plus `build/data_report.txt`. The derived normalization fields are regenerated each time; populated editorial fields are retained. Output entries are serialized in stable id order for repeatable builds.

## Add editorial content

- **Audio:** put clips under `assets/audio/words/<entry-id>.mp3`, add each path to the entry’s `audio` field, and declare the folder under `flutter.assets` in `pubspec.yaml`. Use the permanent numeric id, never a word as the filename. The player handles missing files without crashing.
- **Parts of speech:** set `pos` to one of `noun`, `verb`, `adj`, `adv`, `pron`, `postp`, `conj`, `interj`, `num`, or `particle`. Add or update English and Urdu labels in `lib/config/dictionary_config.dart`.
- **Sentences:** add objects with `brahui`, `urdu`, `english`, and `audio` fields to `sentences`. Empty values are allowed; empty sections are hidden or display the examples placeholder.
- **Tags:** add category codes to `tags` and their labels to `DictionaryConfig.tagLabels` in the same config file. The filter is already available when no tags have been entered.
- **Other editorial fields:** `variants`, `roman`, `ipa`, `source`, `page`, and `parent_id` are retained when set. Keep `id` permanent. Run the build script again after editing the source data.

## Architecture

- `lib/data`: entry model, JSON repository, shared normalization, Urdu collation, Word of the Day, and pure Dart search/grouping.
- `lib/config`: design tokens, labels, UI strings, and category labels.
- `lib/storage`: SharedPreferences adapter for local saved ids, history, and settings.
- `lib/main.dart`: Flutter screens and navigation.
- `tool/build_dictionary.dart`: deterministic data migration and report generation.
- `test/core_test.dart`: normalization, collation, grouping, and data-backed search tests.

SharedPreferences stores saved ids, search history, theme, font size, and search mode locally (browser storage on Web). Riverpod is included for app state integration. Audio uses `just_audio`; sharing uses `share_plus` and its browser fallback. Search mode and query tiers operate on precomputed indexes after one startup parse.

## Fonts and design

The app bundles Noto Nastaliq Urdu Regular and Bold from the system Noto font package under the SIL Open Font License 1.1, plus Ubuntu Sans for UI text under the Ubuntu Font Licence 1.0. Notices are in `assets/fonts/OFL-NOTICE.txt` and `assets/fonts/UBUNTU-FONT-NOTICE.txt`. No font is fetched from the network. The supplied logo reference is cropped for the app and PWA icons; live content, labels, and counts come from this project and its data.

## Implementation choices

- Dark is the initial theme; light and system modes use the same named palette. Font-size scaling multiplies the system text scale.
- The Word of the Day uses a stable FNV-1a hash of local `yyyyMMdd`, then selects among entries with both meanings and no parent.
- The browser worker uses a same-origin cache-first fallback for previously loaded assets. Deploy over HTTPS for service-worker support.
- Additional editorial fields currently remain empty in the source data; the model, migration, search, and detail UI accept them without schema changes.

## Validation

The bundled dictionary and validation report are based on the included 3,204-entry `data.json`. `dart format` passed. The core data and migration sources also passed standalone analysis using a temporary local signature stub for `unorm_dart`; the actual package is declared in `pubspec.yaml` but could not be resolved here. Flutter `analyze` and `test` remain unverified: Flutter tooling could be started with a temporary writable cache, but dependency resolution cannot reach pub.dev in this environment. Run `flutter pub get`, `flutter analyze`, and `flutter test` on a connected machine before release.

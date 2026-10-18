# Fix changelog

- **1. P0 data source and migration:** Regenerated the bundled dictionary from the project `data.json` (4,367 entries), generated a count and content fingerprint, invalidated the web service worker cache when dictionary data changes, and clear saved entries/history when the bundled version changes. Debug startup asserts the bundled entry count.
- **2.1 Meaning labels:** Added the centralized Urdu and English meaning labels and inline labeled rows for dictionary cards, saved/history, Word of the Day, and entry senses. Empty values hide their rows; long card values are capped at two lines.
- **2.2 Alignment:** Aligned Brahui headwords and Urdu meanings to the right, English meanings to the left, and moved the bookmark control to the left edge.
- **2.3 Counts:** Browse tiles and list headers use grouped headword counts; home keeps separate total-entry and unique-headword counts.
- **2.4 Letter selectors:** Browse landing uses the grid; the selected letter list uses the scrollable alphabet jump selector.
- **2.5 Search header:** Kept the search header visually integrated with the page gradient and separated the scrolling results beneath it.
- **3.1 Text scale and contrast:** Increased Urdu and English meaning sizes and contrast; card text retains two-line truncation while details show full meanings.
- **3.2 Mode label:** Added bidi-isolated mode label segments.
- **3.3 Word of the Day:** Uses labeled meaning rows, hides unavailable audio controls, and gives the full-entry action a directional arrow.
- **3.4 Entry detail:** Enlarged letter and variants labels, retained copy/share/favourite actions and the examples placeholder, and uses a simple MEANING heading for a single sense.
- **3.5 Sort order:** Uses the Urdu collator for letter lists and saved words, with collation coverage in the core tests.
- **4.1 Search verification:** Added data-backed search coverage across the supported modes and glosses. The requested `ٹک خلنـگ` sample is absent from the user-updated source dataset; the dataset was left unchanged as requested.
- **4.2/4.3 Verification:** Verified the app startup in the local browser at phone width and confirmed the 4,367-entry statistic. Core automated tests cover the data/search behavior. The Flutter widget-test harness does not complete the asynchronous startup path, so verification used the running web app instead.

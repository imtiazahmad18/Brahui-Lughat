import 'package:flutter/material.dart';

class DictionaryConfig {
  static const posLabels = <String, Map<String, String>>{
    'noun': {'en': 'Noun', 'ur': 'اسم'},
    'verb': {'en': 'Verb', 'ur': 'فعل'},
    'adj': {'en': 'Adjective', 'ur': 'صفت'},
    'adv': {'en': 'Adverb', 'ur': 'متعلق فعل'},
    'pron': {'en': 'Pronoun', 'ur': 'ضمیر'},
    'postp': {'en': 'Postposition', 'ur': 'حرف جار'},
    'conj': {'en': 'Conjunction', 'ur': 'حرف عطف'},
    'interj': {'en': 'Interjection', 'ur': 'حرف ندا'},
    'num': {'en': 'Numeral', 'ur': 'عدد'},
    'particle': {'en': 'Particle', 'ur': 'حرف'},
  };
  static const tagLabels = <String, Map<String, String>>{
    'colour': {'en': 'Colour', 'ur': 'رنگ'},
    'utensil': {'en': 'Utensil', 'ur': 'برتن'},
    'animal': {'en': 'Animal', 'ur': 'جانور'},
    'body': {'en': 'Body', 'ur': 'جسم'},
  };
  static const strings = <String, String>{
    'title': 'Brahui Dictionary',
    'subtitle': 'BRAHUI · URDU · ENGLISH',
    'home': 'Home',
    'search': 'Search',
    'saved': 'Saved',
    'history': 'History',
    'clearAll': 'Clear all',
    'settings': 'Settings',
    'theme': 'Theme',
    'fontSize': 'Font size',
    'dark': 'Dark',
    'light': 'Light',
    'system': 'System',
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
    'extraLarge': 'Extra large',
    'clearHistory': 'Clear history',
    'clearFavourites': 'Clear favourites',
    'entry': 'Entry',
    'copy': 'Copy',
    'share': 'Share',
    'saveWord': 'Save word',
    'removeSaved': 'Remove from saved',
    'playAudio': 'Play audio',
    'copied': 'Copied to clipboard',
    'examples': 'EXAMPLES',
    'sense': 'Sense',
    'senses': 'senses',
    'meaning': 'MEANING',
    'definitionsSenses': 'DEFINITIONS & SENSES',
    'label_urdu_meaning': 'اردو معنی',
    'label_english_meaning': 'English meaning',
    'variants': 'متغیرات',
    'viewFullEntry': 'View full entry',
    'recentSearchesEmpty': 'Recent searches will appear here.',
    'typeTwoCharacters': 'Type at least two characters to search.',
    'noResults': 'No results found.',
    'totalEntries': 'Total entries',
    'headwords': 'Unique headwords',
    'headwordUnit': 'headwords',
    'lettersWithEntries': 'Letters with entries',
    'exampleSentences': 'Example sentences',
    'audioRecordings': 'Audio recordings',
    'favourites': 'Favourites',
    'versionData': 'Version 1.0.0 · Data: {count} entries',
    'searchBrahui': 'براہوی لفظ تلاش کریں…',
    'searchEnglish': 'Search an English word…',
    'searchUrdu': 'اردو لفظ تلاش کریں…',
    'modeBrahuiTitle': 'براہوی → اردو / English',
    'modeBrahuiHint': 'Type a Brahui word, see its Urdu and English meaning',
    'modeEnglishTitle': 'English → براہوی',
    'modeEnglishHint': 'Type an English word, find the Brahui word',
    'modeUrduTitle': 'اردو → براہوی',
    'modeUrduHint': 'Type an Urdu word, find the Brahui word',
    'switchToUrdu': 'This looks like Urdu. Switch to Urdu → Brahui?',
    'switchToEnglish': 'This looks like English. Switch to English → Brahui?',
    'noResultsFor': 'No results for “{query}”',
    'partialMatches': 'Partial matches',
    'wordOfDay': 'WORD OF THE DAY',
    'quickSearch': 'QUICK SEARCH',
    'statistics': 'DICTIONARY STATISTICS',
    'browse': 'Browse by letter',
    'categories': 'Categories',
    'noCategories': 'No categories yet',
    'noHistory': 'Your recent searches will appear here.',
    'noSaved': 'Your saved words will appear here.',
    'similar': 'Similar words',
    'meanings': 'In meanings',
    'noExamples': 'No examples yet',
  };
  static const searchModes = [
    'براہوی → اردو / English',
    'English → براہوی',
    'اردو → براہوی',
  ];
}

class AppTokens {
  static const bgTop = Color(0xff2a1b5c),
      bgBottom = Color(0xff0a0b1a),
      card = Color(0xff12131f);
  static const accent = Color(0xff8b5cf6),
      accentSoft = Color(0xffa78bfa),
      phonetic = accentSoft;
  static const primary = Colors.white,
      secondary = Color(0xffb9b6d0),
      muted = Color(0xff88859b);
  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accentSoft,
      onSecondary: Colors.white,
      surface: card,
      onSurface: primary,
      surfaceTint: Colors.transparent,
      error: Color(0xffff6b7a),
      onError: Colors.white,
    );
    return base.copyWith(
      brightness: Brightness.dark,
      textTheme: base.textTheme.apply(fontFamily: 'UbuntuSans'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'UbuntuSans'),
      scaffoldBackgroundColor: bgBottom,
      colorScheme: scheme,
      cardColor: card,
      canvasColor: card,
      popupMenuTheme: const PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: primary),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgBottom,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: primary,
        iconTheme: IconThemeData(color: secondary),
        titleTextStyle: TextStyle(
          color: primary,
          fontFamily: 'UbuntuSans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xff0d0e1c),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: accent.withValues(alpha: .18),
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accentSoft
                : secondary,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? accentSoft
                : secondary,
            fontFamily: 'UbuntuSans',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: .08),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: primary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    const lightSurface = Color(0xfffaf8ff);
    const lightText = Color(0xff211a35);
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: lightSurface,
    ).copyWith(surfaceTint: Colors.transparent, onSurface: lightText);
    return base.copyWith(
      brightness: Brightness.light,
      textTheme: base.textTheme.apply(
        fontFamily: 'UbuntuSans',
        bodyColor: lightText,
        displayColor: lightText,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'UbuntuSans'),
      scaffoldBackgroundColor: const Color(0xfff6f3ff),
      colorScheme: scheme,
      canvasColor: lightSurface,
      cardColor: lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff6f3ff),
        foregroundColor: lightText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xffeee9f8),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Color(0x338b5cf6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        modalBackgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

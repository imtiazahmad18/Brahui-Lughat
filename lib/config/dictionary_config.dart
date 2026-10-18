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
      phonetic = Color(0xff22d3ee);
  static const primary = Colors.white,
      secondary = Color(0xffb9b6d0),
      muted = Color(0xff88859b);
  static ThemeData dark() => ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'UbuntuSans'),
    primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
      fontFamily: 'UbuntuSans',
    ),
    scaffoldBackgroundColor: bgBottom,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: phonetic,
      surface: card,
    ),
    cardColor: card,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
  static ThemeData light() => ThemeData.light().copyWith(
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'UbuntuSans'),
    primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
      fontFamily: 'UbuntuSans',
    ),
    scaffoldBackgroundColor: const Color(0xfff6f3ff),
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ),
  );
}

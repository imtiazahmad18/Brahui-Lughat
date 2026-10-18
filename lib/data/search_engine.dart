import 'dictionary_entry.dart';
import 'normalization.dart';
import 'urdu_collator.dart';

enum SearchMode { brahui, english, urdu }

SearchMode? suggestedModeForScript(
  String text,
  SearchMode mode, {
  required bool hasResults,
}) {
  var latin = 0;
  var arabic = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x0041 && rune <= 0x005a) ||
        (rune >= 0x0061 && rune <= 0x007a)) {
      latin++;
    } else if ((rune >= 0x0600 && rune <= 0x06ff) ||
        (rune >= 0x0750 && rune <= 0x077f)) {
      arabic++;
    }
  }
  if (mode == SearchMode.english && arabic > latin) return SearchMode.urdu;
  if (mode == SearchMode.urdu && latin > arabic) return SearchMode.english;
  if (mode == SearchMode.brahui && !hasResults && latin > arabic) {
    return SearchMode.english;
  }
  return null;
}

class DictionarySearch {
  DictionarySearch(List<DictionaryEntry> entries) : entries = entries {
    final map = <String, List<DictionaryEntry>>{};
    for (final e in entries) {
      (map[e.wordNorm.isEmpty ? e.word : e.wordNorm] ??= []).add(e);
    }
    groups = map.values.map(Headword.new).toList();
  }

  final List<DictionaryEntry> entries;
  late final List<Headword> groups;

  List<SearchHit> search(String input, SearchMode mode) =>
      mode == SearchMode.brahui
      ? _searchBrahui(input)
      : _searchReverse(input, mode);

  List<SearchHit> _searchBrahui(String input) {
    final q = DictionaryNormalization.normalize(input);
    if (q.isEmpty) return const [];
    final loose = DictionaryNormalization.normalize(input, loose: true);
    final hits = <SearchHit>[];
    for (final group in groups) {
      var best = 99;
      for (final e in group.entries) {
        final forms = [e.wordNorm, ...e.variantsNorm];
        if (forms.contains(q)) {
          best = _min(best, 1);
        } else if (forms.any((s) => s.startsWith(q))) {
          best = _min(best, 2);
        } else if (forms.any(
          (s) => s.contains(q) || s.split(' ').contains(q),
        )) {
          best = _min(best, 3);
        } else if ([
          e.wordLoose,
          ...e.variantsLoose,
        ].any((s) => s == loose || s.startsWith(loose) || s.contains(loose))) {
          best = _min(best, 4);
        } else if (_fuzzyEligible(q) &&
            forms.any((s) => _distance(q, s) <= _limit(q))) {
          best = _min(best, 5);
        } else if (e.urduNorm.contains(q) || e.englishNorm.contains(q)) {
          best = _min(best, 6);
        }
      }
      if (best < 99) hits.add(SearchHit(group, best));
    }
    final sorted = _sort(hits, reverse: false);
    final kept = sorted.where((hit) => hit.tier != 5).toList();
    kept.addAll(sorted.where((hit) => hit.tier == 5).take(20));
    return kept;
  }

  List<SearchHit> _searchReverse(String input, SearchMode mode) {
    final english = mode == SearchMode.english;
    final normalized = english
        ? DictionaryNormalization.normalizeEnglishQuery(input)
        : DictionaryNormalization.normalize(input);
    if (normalized.runes.length < 2) return const [];
    var queryWords = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (queryWords.length >= 2) {
      final stop = english ? _englishStopWords : _urduStopWords;
      queryWords = queryWords.where((word) => !stop.contains(word)).toList();
    }
    if (queryWords.isEmpty) return const [];
    final matchWords = english
        ? queryWords.map(DictionaryNormalization.englishStem).toList()
        : queryWords;
    final hits = <SearchHit>[];

    for (final group in groups) {
      SearchHit? best;
      final tokensAcrossSenses = <String>[];
      for (final entry in group.entries) {
        final glosses = english ? entry.englishGlosses : entry.urduGlosses;
        final tokenLists = _tokensFor(entry, english, glosses);
        tokensAcrossSenses.addAll(tokenLists.expand((tokens) => tokens));
        for (var i = 0; i < glosses.length; i++) {
          final gloss = glosses[i];
          final tokens = i < tokenLists.length
              ? tokenLists[i]
              : const <String>[];
          final tier = _tierForGloss(
            normalized,
            matchWords,
            gloss,
            tokens,
            english,
          );
          if (tier == null) continue;
          final rawGloss = _rawGloss(entry, english, i, gloss);
          final candidate = SearchHit(
            group,
            tier.tier,
            matchedGloss: rawGloss,
            glossLanguage: english
                ? SearchGlossLanguage.english
                : SearchGlossLanguage.urdu,
            glossIndex: i,
            subrank: tier.subrank,
            matchedEntry: entry,
          );
          if (best == null || _compare(candidate, best, reverse: true) < 0) {
            best = candidate;
          }
        }
        // Tiers 4 and 5 can span the whole meaning field, rather than one gloss.
        final allGlossText = glosses.join(' ');
        final tier5 =
            matchWords.length == 1 && allGlossText.contains(normalized);
        if (tier5) {
          final candidate = SearchHit(
            group,
            5,
            matchedGloss: _rawGloss(
              entry,
              english,
              0,
              glosses.firstOrNull ?? '',
            ),
            glossLanguage: english
                ? SearchGlossLanguage.english
                : SearchGlossLanguage.urdu,
            glossIndex: 0,
          );
          if (best == null || _compare(candidate, best, reverse: true) < 0) {
            best = candidate;
          }
        }
      }
      if (matchWords.length > 1) {
        final matching = matchWords.where(tokensAcrossSenses.contains).length;
        if (matchWords.every(tokensAcrossSenses.contains)) {
          final candidate = SearchHit(group, 4);
          if (best == null || _compare(candidate, best, reverse: true) < 0) {
            best = candidate;
          }
        } else if (matching * 2 >= matchWords.length) {
          final candidate = SearchHit(group, 7, subrank: -matching);
          if (best == null || _compare(candidate, best, reverse: true) < 0) {
            best = candidate;
          }
        }
      }
      if (best != null) hits.add(best);
    }

    final sorted = _sort(hits, reverse: true);
    final regular = sorted.where((hit) => hit.tier < 6).toList();
    final similar = sorted.where((hit) => hit.tier == 6).take(20).toList();
    final partial = sorted.where((hit) => hit.tier == 7).take(20).toList();
    return [...regular, ...similar, ...partial];
  }

  List<List<String>> _tokensFor(
    DictionaryEntry entry,
    bool english,
    List<String> glosses,
  ) {
    if (english) {
      final stems = entry.englishGlossStems;
      return stems.length == glosses.length
          ? stems
          : glosses.map(DictionaryNormalization.englishStems).toList();
    }
    final tokens = entry.urduGlossTokens;
    return tokens.length == glosses.length
        ? tokens
        : glosses
              .map(
                (gloss) => gloss
                    .split(' ')
                    .where((token) => token.isNotEmpty)
                    .toList(),
              )
              .toList();
  }

  _GlossTier? _tierForGloss(
    String normalizedQuery,
    List<String> queryWords,
    String gloss,
    List<String> glossTokens,
    bool english,
  ) {
    final exact = english
        ? DictionaryNormalization.normalizeEnglishQuery(gloss)
        : DictionaryNormalization.normalize(gloss);
    if (exact == normalizedQuery) return const _GlossTier(1);
    if (exact.startsWith('$normalizedQuery ')) return const _GlossTier(2);
    if (queryWords.length == 1) {
      if (glossTokens.contains(queryWords.single)) return const _GlossTier(3);
    } else {
      final positions = <int>[];
      for (final word in queryWords) {
        positions.add(glossTokens.indexOf(word));
      }
      if (positions.every((position) => position >= 0) &&
          _strictlyIncreasing(positions)) {
        return const _GlossTier(3, subrank: 0);
      }
      if (queryWords.every(glossTokens.contains)) {
        return const _GlossTier(3, subrank: 1);
      }
    }
    if (queryWords.length == 1 && exact.contains(normalizedQuery)) {
      return const _GlossTier(5);
    }
    if (queryWords.length == 1 && _fuzzyEligible(queryWords.single)) {
      final distanceWords = glossTokens;
      if (distanceWords.any(
        (word) =>
            _distance(queryWords.single, word) <= _limit(queryWords.single),
      )) {
        return const _GlossTier(6);
      }
    }
    return null;
  }

  String _rawGloss(
    DictionaryEntry entry,
    bool english,
    int index,
    String fallback,
  ) {
    final raw = english ? entry.english : entry.urdu;
    final values = raw
        .split(RegExp(r'[۔،؛;,/\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return index < values.length ? values[index] : fallback;
  }

  List<SearchHit> _sort(List<SearchHit> hits, {required bool reverse}) {
    hits.sort((a, b) => _compare(a, b, reverse: reverse));
    return hits;
  }

  int _compare(SearchHit a, SearchHit b, {required bool reverse}) {
    var comparison = a.tier.compareTo(b.tier);
    if (comparison != 0) return comparison;
    if (reverse) {
      comparison = a.glossIndex.compareTo(b.glossIndex);
      if (comparison != 0) return comparison;
      comparison = a.subrank.compareTo(b.subrank);
      if (comparison != 0) return comparison;
      comparison = a.matchedGloss
          .split(' ')
          .length
          .compareTo(b.matchedGloss.split(' ').length);
      if (comparison != 0) return comparison;
    }
    comparison = a.headword.word.runes.length.compareTo(
      b.headword.word.runes.length,
    );
    return comparison != 0
        ? comparison
        : UrduCollator.compare(a.headword.word, b.headword.word);
  }

  static bool _strictlyIncreasing(List<int> values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i] <= values[i - 1]) return false;
    }
    return true;
  }

  static int _min(int a, int b) => a < b ? a : b;
  static const _englishStopWords = {
    'a',
    'an',
    'the',
    'to',
    'of',
    'in',
    'on',
    'and',
    'or',
    'with',
    'for',
    'by',
    'is',
    'are',
    'be',
    'as',
    'at',
    'from',
    'that',
    'this',
    'it',
    'its',
  };
  static final _urduStopWords = {
    'کا',
    'کی',
    'کے',
    'کو',
    'میں',
    'سے',
    'پر',
    'اور',
    'ہے',
    'ہیں',
    'تھا',
    'تھی',
    'ہو',
    'ہوا',
    'ہوئی',
    'کہ',
    'یہ',
    'وہ',
    'نہ',
    'بھی',
    'ایک',
  }.map(DictionaryNormalization.normalize).toSet();
  static int _limit(String q) => q.runes.length <= 3
      ? 0
      : q.runes.length <= 5
      ? 1
      : 2;
  static bool _fuzzyEligible(String q) => q.runes.length >= 4;
  static int _distance(String a, String b) {
    final x = a.runes.toList(), y = b.runes.toList(), max = _limit(a);
    if ((x.length - y.length).abs() > max) return max + 1;
    var previous = List<int>.generate(y.length + 1, (i) => i);
    var current = List<int>.filled(y.length + 1, 0);
    for (var i = 1; i <= x.length; i++) {
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= y.length; j++) {
        current[j] = _min(
          _min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1),
        );
        if (current[j] < rowMin) rowMin = current[j];
      }
      if (rowMin > max) return max + 1;
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[y.length];
  }
}

class _GlossTier {
  const _GlossTier(this.tier, {this.subrank = 0});
  final int tier;
  final int subrank;
}

enum SearchGlossLanguage { english, urdu }

class SearchHit {
  const SearchHit(
    this.headword,
    this.tier, {
    this.matchedGloss = '',
    this.glossLanguage,
    this.glossIndex = 999,
    this.subrank = 0,
    this.matchedEntry,
  });
  final Headword headword;
  final int tier;
  final String matchedGloss;
  final SearchGlossLanguage? glossLanguage;
  final int glossIndex;
  final int subrank;
  final DictionaryEntry? matchedEntry;
}

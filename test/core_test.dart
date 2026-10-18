import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:brahui_dictionary/data/dictionary_entry.dart';
import 'package:brahui_dictionary/data/normalization.dart';
import 'package:brahui_dictionary/data/search_engine.dart';
import 'package:brahui_dictionary/data/urdu_collator.dart';
import 'package:brahui_dictionary/data/word_of_the_day.dart';

DictionaryEntry fixture(
  int id,
  String word, {
  String urdu = '',
  String english = '',
  String letter = 'ا',
  List<String>? variants,
}) {
  final wn = DictionaryNormalization.normalize(word),
      forms = variants ?? word.split('/').map((e) => e.trim()).toList();
  return DictionaryEntry({
    'id': id,
    'letter': letter,
    'word': word,
    'urdu_meaning': urdu,
    'english_translation': english,
    'variants': forms,
    'word_norm': wn,
    'word_loose': DictionaryNormalization.normalize(word, loose: true),
    'variants_norm': forms.map(DictionaryNormalization.normalize).toList(),
    'variants_loose': forms
        .map((e) => DictionaryNormalization.normalize(e, loose: true))
        .toList(),
    'urdu_norm': DictionaryNormalization.normalize(urdu),
    'english_norm': DictionaryNormalization.normalize(english),
    'urdu_glosses_norm': DictionaryNormalization.glosses(urdu),
    'english_glosses_norm': DictionaryNormalization.glosses(
      english,
      english: true,
    ),
  });
}

void main() {
  group('normalization', () {
    test('removes marks, tatweel, letter variants and Persian digits', () {
      expect(
        DictionaryNormalization.normalize('رُوفہ ۱۲ / كِتابـ'),
        'روفه 12 کتاب',
      );
    });
    test('loose mapping is opt-in', () {
      expect(
        DictionaryNormalization.normalize('ٹک'),
        isNot(DictionaryNormalization.normalize('تک')),
      );
      expect(
        DictionaryNormalization.normalize('ٹک', loose: true),
        DictionaryNormalization.normalize('تک', loose: true),
      );
    });
  });
  test('Urdu collation follows alphabet table', () {
    const chars = [
      'ا',
      'ب',
      'پ',
      'ت',
      'ٹ',
      'ث',
      'ج',
      'چ',
      'ح',
      'خ',
      'د',
      'ڈ',
      'ذ',
      'ر',
      'ڑ',
      'ز',
      'ژ',
      'س',
      'ش',
      'ص',
      'ض',
      'ط',
      'ظ',
      'ع',
      'غ',
      'ف',
      'ق',
      'ک',
      'گ',
      'ل',
      'م',
      'ن',
      'و',
      'ہ',
      'ھ',
      'ی',
      'ے',
    ];
    for (var i = 0; i < chars.length - 1; i++)
      expect(UrduCollator.compare(chars[i], chars[i + 1]), lessThan(0));
    expect(UrduCollator.compare('بچہ', 'پھول'), lessThan(0));
  });
  test('variants match once and identical senses are merged', () {
    final engine = DictionarySearch([
      fixture(1, 'ثغس / سغس', urdu: 'Meaning', english: 'Gloss'),
      fixture(2, 'ثغس / سغس', urdu: 'Meaning', english: 'Gloss'),
      fixture(3, 'ثغس / سغس', urdu: 'Other', english: 'Second'),
    ]);
    final hits = engine.search('سغس', SearchMode.brahui);
    expect(hits.length, 1);
    expect(hits.single.headword.senses.length, 2);
  });
  test('reverse gloss exact search', () {
    final engine = DictionarySearch([
      fixture(1, 'روش گژدان', urdu: 'سورج مکھی', english: 'Sunflower; flower'),
    ]);
    expect(engine.search('sunflower', SearchMode.english).single.tier, 1);
    expect(engine.search('سورج مکھی', SearchMode.urdu).single.tier, 1);
  });
  test('loose matches rank below exact matches', () {
    final engine = DictionarySearch([fixture(1, 'ٹک'), fixture(2, 'تک')]);
    final hits = engine.search('ٹک', SearchMode.brahui);
    expect(hits.first.headword.word, 'ٹک');
    expect(hits.first.tier, 1);
    expect(hits.last.tier, 4);
  });
  test('fuzzy search is available for four-character queries', () {
    final engine = DictionarySearch([fixture(1, 'رُوفہ')]);
    expect(engine.search('روفا', SearchMode.brahui).single.tier, 5);
  });
  test('diacritics, tatweel and Urdu letter variants search Brahui forms', () {
    final engine = DictionarySearch([
      fixture(1, 'ٹک خلنـگ'),
      fixture(2, 'رول هلنگ'),
      fixture(3, 'رُوفہ گننگ / روفنگ'),
    ]);
    expect(
      engine.search('خلنگ', SearchMode.brahui).single.headword.word,
      'ٹک خلنـگ',
    );
    for (final query in ['هلنگ', 'ہلنگ', 'ھلنگ']) {
      expect(
        engine.search(query, SearchMode.brahui).single.headword.word,
        'رول هلنگ',
      );
    }
    expect(engine.search('روفہ', SearchMode.brahui), hasLength(1));
    expect(engine.search('رُوفہ', SearchMode.brahui), hasLength(1));
  });
  test('empty optional fields remain valid in the entry model', () {
    final empty = fixture(1, 'word');
    expect(empty.raw['pos'], isNull);
    expect(empty.raw['audio'], isNull);
    expect(empty.raw['tags'], isNull);
    expect(Headword([empty]).senses.single['urdu'], '');
  });
  test('word of the day is stable and excludes incomplete entries', () {
    final good = fixture(1, 'word', urdu: 'meaning', english: 'meaning');
    final empty = fixture(2, 'empty');
    final entries = [empty, good];
    final date = DateTime(2026, 10, 17);
    expect(WordOfTheDay.pick(entries, date)?.id, good.id);
    expect(
      WordOfTheDay.pick(entries, date)?.id,
      WordOfTheDay.pick(entries, date)?.id,
    );
  });
  test('real dictionary is available for data-backed search', () {
    final rows =
        (jsonDecode(
                  File('assets/data/dictionary.built.json').readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final engine = DictionarySearch(rows.map(DictionaryEntry.new).toList());
    expect(engine.entries.length, greaterThan(3000));
    expect(engine.search('روش گژدان', SearchMode.brahui), isNotEmpty);
    expect(
      engine.search('sunflower', SearchMode.english).first.headword.word,
      startsWith('روش گژدان / روز گژدان'),
    );
    expect(engine.search('سورج مکھی', SearchMode.urdu).first.tier, 1);
    expect(
      engine
          .search('سغس', SearchMode.brahui)
          .where((hit) => hit.headword.word.startsWith('ثغس / سغس'))
          .length,
      1,
    );
  });

  test('browse counts use the same unique headwords as letter lists', () {
    final rows =
        (jsonDecode(
                  File('assets/data/dictionary.built.json').readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final search = DictionarySearch(rows.map(DictionaryEntry.new).toList());
    expect(rows.length, 4367);
    expect(rows.map((row) => row['letter']).toSet().length, 32);
    final letters = rows.map((row) => row['letter'] as String).toSet();
    for (final letter in letters) {
      final tileCount = search.groups
          .where(
            (group) => group.entries.any((entry) => entry.letter == letter),
          )
          .length;
      final tileCountFromRows = rows
          .where((row) => row['letter'] == letter)
          .map((row) => row['word_norm'] ?? row['word'])
          .toSet()
          .length;
      final listLength = search.groups
          .where(
            (group) => group.entries.any((entry) => entry.letter == letter),
          )
          .toList()
          .length;
      expect(tileCount, listLength, reason: 'letter $letter');
      expect(
        tileCount,
        tileCountFromRows,
        reason: 'tile headword count $letter',
      );
    }
  });

  test('requested searches find the intended real dictionary entries', () {
    final rows =
        (jsonDecode(
                  File('assets/data/dictionary.built.json').readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final search = DictionarySearch(rows.map(DictionaryEntry.new).toList());
    bool containsWord(String query, SearchMode mode, String prefix) => search
        .search(query, mode)
        .any((hit) => hit.headword.word.startsWith(prefix));

    for (final query in ['روفہ', 'رُوفہ']) {
      expect(
        containsWord(query, SearchMode.brahui, 'رُوفہ گننگ / روفنگ'),
        isTrue,
      );
    }
    expect(search.search('خلنگ', SearchMode.brahui), isNotEmpty);
    for (final query in ['هلنگ', 'ہلنگ', 'ھلنگ']) {
      expect(containsWord(query, SearchMode.brahui, 'رول هلنگ'), isTrue);
    }
    expect(
      search
          .search('سغس', SearchMode.brahui)
          .where((hit) => hit.headword.word.startsWith('ثغس / سغس'))
          .length,
      1,
    );
    expect(containsWord('روتھڑا', SearchMode.brahui, 'رُوٹھڑا'), isTrue);
    expect(containsWord('sunflower', SearchMode.english, 'روش گژدان'), isTrue);
    expect(containsWord('sweep', SearchMode.english, 'رُوفہ گننگ'), isTrue);
    expect(containsWord('سورج مکھی', SearchMode.urdu, 'روش گژدان'), isTrue);
    expect(containsWord('جھاڑو', SearchMode.urdu, 'رُوفہ گننگ'), isTrue);
    final meaningSearch = search.search('sunflower', SearchMode.brahui);
    expect(meaningSearch, isNotEmpty);
    expect(meaningSearch.first.tier, 6);
  });
}

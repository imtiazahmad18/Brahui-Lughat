import 'dart:async';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';

import 'config/dictionary_config.dart';
import 'config/dictionary_data_version.dart';
import 'data/dictionary_entry.dart';
import 'data/dictionary_repository.dart';
import 'data/search_engine.dart';
import 'data/urdu_collator.dart';
import 'data/word_of_the_day.dart';
import 'ui/web_share_stub.dart'
    if (dart.library.html) 'ui/web_share_web.dart'
    as web_share;
import 'storage/local_dictionary_storage.dart';

final _dictionaryProvider = Provider<List<DictionaryEntry>>((ref) => const []);
void main() => runApp(const ProviderScope(child: BrahuiApp()));

class BrahuiApp extends StatefulWidget {
  const BrahuiApp({super.key});
  @override
  State<BrahuiApp> createState() => _BrahuiAppState();
}

class _BrahuiAppState extends State<BrahuiApp> {
  List<DictionaryEntry> entries = [];
  late DictionarySearch search;
  LocalDictionaryStorage? storage;
  int tab = 0;
  SearchMode mode = SearchMode.brahui;
  ThemeMode themeMode = ThemeMode.dark;
  double fontScale = 1;
  Timer? debounce;
  final FocusNode searchPageFocus = FocusNode();
  Set<int> saved = {};
  List<Map<String, dynamic>> history = [];
  bool loading = true;
  String? loadError;
  String query = '';
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
    controller.addListener(() => _onQueryChanged());
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    searchPageFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    debounce?.cancel();
    if (controller.text.trim().length < 2) {
      setState(() => query = controller.text);
      return;
    }
    debounce = Timer(
      const Duration(milliseconds: 150),
      () => setState(() => query = controller.text),
    );
  }

  Future<void> _load() async {
    try {
    storage = await LocalDictionaryStorage.open();
    final encoded = await rootBundle.loadString(
      'assets/data/dictionary.built.json',
    );
    final data = kIsWeb
        ? _decodeRows(encoded)
        : await compute(_decodeRows, encoded);
    final dataVersion = _dictionaryVersion(encoded, data.length);
    assert(dataVersion == DictionaryDataVersion.value);
    await storage!.migrateData(dataVersion);
    entries = data
        .map((e) => DictionaryEntry(Map<String, dynamic>.from(e)))
        .toList();
    assert(entries.length == DictionaryDataVersion.entryCount);
    search = DictionarySearch(entries);
    saved = storage!.loadSavedIds();
    history = storage!.loadHistory();
    mode = SearchMode.values[storage!.modeIndex];
    final tm = storage!.theme;
    themeMode = tm == 'system'
        ? ThemeMode.system
        : tm == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    fontScale = <double>[.88, 1.0, 1.12, 1.25][storage!.fontSizeIndex];
    setState(() => loading = false);
    } catch (error, stackTrace) {
      debugPrint('Dictionary startup failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          loadError = error.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _savePrefs() async {
    await storage?.saveCollections(saved, history);
  }

  void _toggleSave(int id) {
    setState(() => saved.contains(id) ? saved.remove(id) : saved.add(id));
    _savePrefs();
  }

  void _runSearch(String q) {
    if (q.trim().isEmpty) return;
    query = q;
    controller.text = q;
    history.removeWhere((h) => h['q'] == q && h['mode'] == mode.index);
    history.insert(0, {
      'q': q,
      'mode': mode.index,
      'at': DateTime.now().toIso8601String(),
    });
    if (history.length > 50) history = history.take(50).toList();
    _savePrefs();
    setState(() => tab = 1);
  }

  Future<void> _selectMode(SearchMode m) async {
    setState(() => mode = m);
    await storage?.saveMode(m.index);
  }

  Future<void> _repeatHistory(Map<String, dynamic> item) async {
    final rawMode = item['mode'];
    if (rawMode is int && rawMode >= 0 && rawMode < SearchMode.values.length) {
      await _selectMode(SearchMode.values[rawMode]);
    }
    _runSearch('${item['q'] ?? ''}');
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [_dictionaryProvider.overrideWithValue(entries)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: DictionaryConfig.strings['title']!,
      theme: AppTokens.light(),
      darkTheme: AppTokens.dark(),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.of(context).textScaler.scale(fontScale),
          ),
        ),
        child: child!,
      ),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : loadError != null
          ? Scaffold(body: Center(child: Text('Could not load dictionary: $loadError')))
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    themeMode == ThemeMode.light ||
                        (themeMode == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.light)
                    ? const LinearGradient(
                        colors: [Color(0xfff6f3ff), Color(0xffe9e4f7)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTokens.bgTop, AppTokens.bgBottom],
                        stops: [0, .42],
                      ),
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: IndexedStack(
                    index: tab,
                    children: [
                      _home(),
                      _searchPage(),
                      _savedPage(),
                      _historyPage(),
                    ],
                  ),
                ),
                bottomNavigationBar: _nav(),
              ),
            ),
    ),
  );
  Widget _nav() => NavigationBar(
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? const Color(0xffe7e0f6)
        : AppTokens.card,
    selectedIndex: tab,
    onDestinationSelected: (i) => setState(() => tab = i),
    destinations: [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: DictionaryConfig.strings['home']!,
      ),
      NavigationDestination(
        icon: Icon(Icons.search),
        label: DictionaryConfig.strings['search']!,
      ),
      NavigationDestination(
        icon: Icon(Icons.favorite_border),
        selectedIcon: Icon(Icons.favorite),
        label: DictionaryConfig.strings['saved']!,
      ),
      NavigationDestination(
        icon: Icon(Icons.history),
        label: DictionaryConfig.strings['history']!,
      ),
    ],
  );
  Widget _home() => _column(
    ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DictionaryConfig.strings['title']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _label(DictionaryConfig.strings['subtitle']!),
                ],
              ),
            ),
            _modePill(),
            const SizedBox(width: 8),
            _icon(
              Icons.settings_outlined,
              DictionaryConfig.strings['settings']!,
              () => _settings(),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _searchField(home: true),
        const SizedBox(height: 24),
        _label(DictionaryConfig.strings['wordOfDay']!),
        const SizedBox(height: 10),
        _wotdCard(),
        const SizedBox(height: 25),
        _label(DictionaryConfig.strings['quickSearch']!),
        const SizedBox(height: 10),
        _quickSearch(),
        const SizedBox(height: 25),
        _label(DictionaryConfig.strings['statistics']!),
        const SizedBox(height: 10),
        _stats(),
      ],
    ),
  );
  Widget _searchPage() => _column(
    Column(
      children: [
        _searchHeader(),
        Expanded(
          child: query.trim().isNotEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  children: _results(),
                )
              : browseLetter == null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    _label(DictionaryConfig.strings['browse']!),
                    const SizedBox(height: 12),
                    _letters(),
                    const SizedBox(height: 24),
                    _label(DictionaryConfig.strings['categories']!),
                    const SizedBox(height: 10),
                    _categoryChips(),
                  ],
                )
              : _letterList(),
        ),
      ],
    ),
  );
  String? browseLetter;

  Widget _searchHeader() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: Theme.of(context).brightness == Brightness.light
          ? const LinearGradient(colors: [Color(0xfff6f3ff), Color(0xffe9e4f7)])
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTokens.bgTop, AppTokens.bgBottom],
            ),
      boxShadow: [
        BoxShadow(
          color: AppTokens.bgBottom.withValues(alpha: .18),
          blurRadius: 8,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              if (browseLetter != null)
                IconButton(
                  tooltip: DictionaryConfig.strings['browse']!,
                  onPressed: () => setState(() => browseLetter = null),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  DictionaryConfig.strings['search']!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _modePill(),
            ],
          ),
          const SizedBox(height: 12),
          _searchField(),
          if (query.isEmpty && browseLetter != null) ...[
            const SizedBox(height: 8),
            _letterJumpBar(),
          ],
        ],
      ),
    ),
  );

  List<Headword> _headwordsForLetter(String letter) =>
      search.groups
          .where(
            (group) => group.entries.any((entry) => entry.letter == letter),
          )
          .toList()
        ..sort((a, b) => UrduCollator.compare(a.word, b.word));

  Widget _letterList() {
    final words = _headwordsForLetter(browseLetter!);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: words.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${browseLetter!} · ${words.length} ${DictionaryConfig.strings['headwordUnit']}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTokens.secondary),
            ),
          );
        }
        return _resultCard(words[index - 1]);
      },
    );
  }

  Widget _letterJumpBar() {
    final present = entries.map((entry) => entry.letter).toSet();
    final ordered = UrduCollator.alphabet.split(' ');
    return SizedBox(
      height: 48,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, .06, .94, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ordered.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final letter = ordered[index];
            final selected = letter == browseLetter;
            final enabled = present.contains(letter);
            return ActionChip(
              label: Text(
                letter,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 17,
                  color: selected
                      ? Colors.white
                      : AppTokens.secondary.withValues(
                          alpha: enabled ? 1 : .45,
                        ),
                ),
              ),
              backgroundColor: selected
                  ? AppTokens.accent
                  : AppTokens.card.withValues(alpha: enabled ? 1 : .45),
              onPressed: enabled
                  ? () => setState(() => browseLetter = letter)
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _savedPage() {
    final list =
        search.groups
            .where((g) => g.entries.any((e) => saved.contains(e.id)))
            .toList()
          ..sort((a, b) => UrduCollator.compare(a.word, b.word));
    return _column(
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            DictionaryConfig.strings['saved']!,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            _empty(DictionaryConfig.strings['noSaved']!)
          else
            ...list.map(_resultCard),
        ],
      ),
    );
  }

  Widget _historyPage() => _column(
    ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DictionaryConfig.strings['history']!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                history.clear();
                _savePrefs();
              }),
              child: Text(DictionaryConfig.strings['clearAll']!),
            ),
          ],
        ),
        if (history.isEmpty)
          _empty(DictionaryConfig.strings['noHistory']!)
        else
          ...history.map(_historyCard),
      ],
    ),
  );

  Widget _historyCard(Map<String, dynamic> item) {
    final q = '${item['q'] ?? ''}';
    final rawMode = item['mode'];
    final savedMode =
        rawMode is int && rawMode >= 0 && rawMode < SearchMode.values.length
        ? SearchMode.values[rawMode]
        : mode;
    final hits = search.search(q, savedMode);
    if (hits.isNotEmpty) {
      return _resultCard(
        hits.first.headword,
        subtitle: _time(item['at']),
        onTap: () => _repeatHistory(item),
      );
    }
    return Card(
      color: AppTokens.card,
      child: ListTile(
        leading: const Icon(Icons.history, color: AppTokens.accentSoft),
        title: Text(q),
        subtitle: Text(_time(item['at'])),
        onTap: () => _repeatHistory(item),
      ),
    );
  }

  Widget _column(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
  Widget _label(String s) => Text(
    s,
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.45,
      color: AppTokens.muted,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _icon(IconData icon, String label, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    tooltip: label,
    icon: Icon(icon, color: AppTokens.secondary),
    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
  );
  Widget _modePill() => InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: _chooseMode,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeLabel(mode, small: true),
          const SizedBox(width: 5),
          const Icon(Icons.swap_horiz, size: 16, color: AppTokens.accentSoft),
        ],
      ),
    ),
  );
  Future<void> _chooseMode() async {
    final m = await showModalBottomSheet<SearchMode>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xfff6f3ff)
          : AppTokens.card,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SearchMode.values
              .map(
                (m) => ListTile(
                  title: _modeLabel(m),
                  trailing: m == mode
                      ? const Icon(Icons.check, color: AppTokens.accent)
                      : null,
                  onTap: () => Navigator.pop(c, m),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (m != null) _selectMode(m);
  }

  Widget _modeLabel(SearchMode value, {bool small = false}) {
    final style = TextStyle(
      fontSize: small ? 11 : 16,
      color: small ? AppTokens.primary : null,
    );
    if (value == SearchMode.brahui) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u2067براہوی → اردو\u2069', style: style),
            Text(' / ', style: style),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('English', style: style),
            ),
          ],
        ),
      );
    }
    if (value == SearchMode.english) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Text('English → براہوی', style: style),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text('اردو → براہوی', style: style),
    );
  }

  Widget _searchField({bool home = false}) => TextField(
    focusNode: home ? null : searchPageFocus,
    controller: controller,
    textDirection: mode == SearchMode.english
        ? TextDirection.ltr
        : TextDirection.rtl,
    style: TextStyle(
      fontFamily: mode == SearchMode.english ? null : 'NotoNastaliqUrdu',
      fontSize: 18,
      height: 2,
      color: AppTokens.primary,
    ),
    onTap: () {
      if (home) {
        setState(() => tab = 1);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => searchPageFocus.requestFocus(),
        );
      }
    },
    onSubmitted: _runSearch,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search, color: AppTokens.accentSoft),
      hintText: DictionaryConfig
          .strings[['searchBrahui', 'searchEnglish', 'searchUrdu'][mode.index]],
      hintStyle: TextStyle(
        fontSize: 15,
        color: AppTokens.muted,
        fontFamily: mode == SearchMode.english ? null : 'NotoNastaliqUrdu',
        height: 2,
      ),
      suffixIcon: query.isNotEmpty
          ? IconButton(
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.close),
            )
          : null,
      filled: true,
      fillColor: AppTokens.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTokens.accent),
      ),
    ),
  );
  Widget _wotdCard() {
    final e = WordOfTheDay.pick(entries, DateTime.now());
    if (e == null) return const SizedBox.shrink();
    final audioPath = e.raw['audio']?.toString() ?? '';
    final examples = List<Map<String, dynamic>>.from(
      (e.raw['sentences'] ?? const []).map((x) => Map<String, dynamic>.from(x)),
    );
    final firstExample = examples.cast<Map<String, dynamic>?>().firstWhere(
      (s) => '${s?['brahui'] ?? ''}'.isNotEmpty,
      orElse: () => null,
    );
    return InkWell(
      onTap: () => _detail(e),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xff2b2070), Color(0xff0e2a4a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTokens.accent.withValues(alpha: .24),
              blurRadius: 22,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.ltr,
              children: [
                if (audioPath.isNotEmpty)
                  IconButton(
                    onPressed: () => _play(audioPath),
                    icon: const Icon(
                      Icons.volume_up,
                      color: AppTokens.accentSoft,
                    ),
                    tooltip: DictionaryConfig.strings['playAudio'],
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                  ),
                Expanded(
                  child: Text(
                    e.word,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 31,
                      height: 2.15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if ('${e.raw['roman'] ?? ''}${e.raw['ipa'] ?? ''}'.isNotEmpty)
              Text(
                '${e.raw['roman'] ?? ''}  ${e.raw['ipa'] ?? ''}',
                style: const TextStyle(color: AppTokens.phonetic),
              ),
            if ((e.raw['pos'] ?? '') != '') _pos(e.raw['pos']),
            _meaningRow(
              label: DictionaryConfig.strings['label_urdu_meaning']!,
              value: e.urdu,
              direction: TextDirection.rtl,
              card: true,
            ),
            _meaningRow(
              label: DictionaryConfig.strings['label_english_meaning']!,
              value: e.english,
              direction: TextDirection.ltr,
              card: true,
            ),
            if (firstExample != null)
              Text(
                '“${firstExample['brahui']}”',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  height: 2,
                  color: AppTokens.accentSoft,
                ),
              ),
            Align(
              alignment: mode == SearchMode.english
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Directionality(
                textDirection: mode == SearchMode.english
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: TextButton.icon(
                  onPressed: () => _detail(e),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(DictionaryConfig.strings['viewFullEntry']!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickSearch() {
    if (history.isEmpty)
      return Text(
        DictionaryConfig.strings['recentSearchesEmpty']!,
        style: const TextStyle(color: AppTokens.muted),
      );
    final recent = history.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
        childAspectRatio: 3.3,
      ),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final h = recent[index];
        return ActionChip(
          label: Text(
            '${h['q']}',
            style: const TextStyle(color: AppTokens.primary),
          ),
          avatar: const Icon(Icons.arrow_forward, size: 15),
          onPressed: () => _repeatHistory(h),
          backgroundColor: AppTokens.card,
        );
      },
    );
  }

  Widget _stats() => Consumer(
    builder: (context, ref, child) {
      final dictionary = ref.watch(_dictionaryProvider);
      final heads = search.groups.length;
      final letters = dictionary.map((e) => e.letter).toSet().length;
      final sentences = dictionary
          .where(
            (e) => (e.raw['sentences'] as List? ?? []).any(
              (s) =>
                  s is Map &&
                  [
                    'brahui',
                    'urdu',
                    'english',
                    'audio',
                  ].any((key) => '${s[key] ?? ''}'.trim().isNotEmpty),
            ),
          )
          .length;
      final audio = dictionary
          .where((e) => '${e.raw['audio'] ?? ''}'.isNotEmpty)
          .length;
      return Container(
        decoration: _box(),
        child: Column(
          children: [
            _stat(DictionaryConfig.strings['totalEntries']!, dictionary.length),
            _stat(DictionaryConfig.strings['headwords']!, heads),
            _stat(DictionaryConfig.strings['lettersWithEntries']!, letters),
            _stat(DictionaryConfig.strings['exampleSentences']!, sentences),
            _stat(DictionaryConfig.strings['audioRecordings']!, audio),
            _stat(DictionaryConfig.strings['favourites']!, saved.length),
          ],
        ),
      );
    },
  );

  Widget _stat(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTokens.secondary),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: AppTokens.accentSoft,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  BoxDecoration _box() => BoxDecoration(
    color: AppTokens.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: .07)),
  );
  Widget _letters() {
    final present = entries.map((e) => e.letter).toSet().toList()
      ..sort(UrduCollator.compare);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: present.map((l) {
        final count = _headwordsForLetter(l).length;
        return ActionChip(
          label: Text(
            '$l  $count ${DictionaryConfig.strings['headwordUnit']}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppTokens.card,
          onPressed: () => _browseLetter(l),
        );
      }).toList(),
    );
  }

  void _browseLetter(String letter) {
    setState(() => browseLetter = letter);
  }

  Widget _categoryChips() {
    final tags = <String>{
      for (final e in entries) ...List<String>.from(e.raw['tags'] ?? const []),
    };
    if (tags.isEmpty)
      return Text(
        DictionaryConfig.strings['noCategories']!,
        style: const TextStyle(color: AppTokens.muted),
      );
    return Wrap(
      spacing: 8,
      children: tags
          .map(
            (t) => FilterChip(
              label: Text(
                DictionaryConfig.tagLabels[t]?['en'] ?? t,
                style: const TextStyle(color: AppTokens.primary),
              ),
              selected: false,
              onSelected: (_) => _filterTag(t),
            ),
          )
          .toList(),
    );
  }

  void _filterTag(String tag) {
    final matches = search.groups
        .where(
          (g) => g.entries.any(
            (e) => List<String>.from(e.raw['tags'] ?? const []).contains(tag),
          ),
        )
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.bgBottom,
      builder: (c) => ListView(
        padding: const EdgeInsets.all(18),
        children: matches.map(_resultCard).toList(),
      ),
    );
  }

  List<Widget> _results() {
    if (query.trim().length < 2)
      return [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            DictionaryConfig.strings['typeTwoCharacters']!,
            style: const TextStyle(color: AppTokens.muted),
          ),
        ),
      ];
    final hits = search.search(query, mode);
    if (hits.isEmpty) return [_empty(DictionaryConfig.strings['noResults']!)];
    final widgets = <Widget>[];
    for (final tier in [1, 2, 3, 4, 5, 6]) {
      final group = hits.where((h) => h.tier == tier).toList();
      if (group.isEmpty) continue;
      if (tier == 5 || tier == 6) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: _label(
              tier == 5
                  ? DictionaryConfig.strings['similar']!
                  : DictionaryConfig.strings['meanings']!,
            ),
          ),
        );
      }
      widgets.addAll(group.map((h) => _resultCard(h.headword)));
    }
    return widgets;
  }

  Widget _resultCard(
    Headword headword, {
    String? subtitle,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap ?? () => _detail(headword.primary),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            IconButton(
              onPressed: () => _toggleSave(headword.primary.id),
              tooltip: saved.contains(headword.primary.id)
                  ? DictionaryConfig.strings['removeSaved']
                  : DictionaryConfig.strings['saveWord'],
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              icon: Icon(
                saved.contains(headword.primary.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: saved.contains(headword.primary.id)
                    ? AppTokens.accent
                    : AppTokens.muted,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    headword.word,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 20,
                      height: 2.0,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (headword.senses.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${headword.senses.length} ${DictionaryConfig.strings['senses']}',
                        style: const TextStyle(
                          color: AppTokens.accentSoft,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _meaningRow(
                    label: DictionaryConfig.strings['label_urdu_meaning']!,
                    value: headword.senses.first['urdu'] ?? '',
                    direction: TextDirection.rtl,
                    card: true,
                  ),
                  _meaningRow(
                    label: DictionaryConfig.strings['label_english_meaning']!,
                    value: headword.senses.first['english'] ?? '',
                    direction: TextDirection.ltr,
                    card: true,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTokens.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _pos(String code) {
    final label = DictionaryConfig.posLabels[code]?['en'] ?? code;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTokens.accent.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppTokens.accentSoft, fontSize: 12),
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTokens.muted),
      ),
    ),
  );
  String _time(dynamic raw) {
    final dt = DateTime.tryParse('$raw')?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _detail(DictionaryEntry e) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EntryDetail(
        entry: e,
        allEntries: entries,
        saved: saved.contains(e.id),
        onSave: () => _toggleSave(e.id),
      ),
    ),
  );
  Future<void> _play(String path) async {
    if (path.isEmpty) return;
    final player = AudioPlayer();
    try {
      await player.setAsset(path);
      await player.play();
    } catch (_) {
    } finally {
      player.dispose();
    }
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xfff6f3ff)
          : AppTokens.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DictionaryConfig.strings['settings']!,
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 14),
                  Text(DictionaryConfig.strings['theme']!),
                  Wrap(
                    children: [
                      for (final item in [
                        (DictionaryConfig.strings['dark']!, ThemeMode.dark),
                        (DictionaryConfig.strings['light']!, ThemeMode.light),
                        (DictionaryConfig.strings['system']!, ThemeMode.system),
                      ])
                        ChoiceChip(
                          label: Text(item.$1),
                          selected: themeMode == item.$2,
                          onSelected: (_) {
                            setState(() => themeMode = item.$2);
                            refreshSheet(() {});
                            storage?.saveTheme(item.$1.toLowerCase());
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(DictionaryConfig.strings['fontSize']!),
                  Wrap(
                    children: [
                      for (var i = 0; i < 4; i++)
                        ChoiceChip(
                          label: Text(
                            [
                              DictionaryConfig.strings['small']!,
                              DictionaryConfig.strings['medium']!,
                              DictionaryConfig.strings['large']!,
                              DictionaryConfig.strings['extraLarge']!,
                            ][i],
                          ),
                          selected: fontScale == [.88, 1, 1.12, 1.25][i],
                          onSelected: (_) {
                            setState(
                              () =>
                                  fontScale = <double>[.88, 1.0, 1.12, 1.25][i],
                            );
                            refreshSheet(() {});
                            storage?.saveFontSize(i);
                          },
                        ),
                    ],
                  ),
                  ListTile(
                    title: Text(DictionaryConfig.strings['clearHistory']!),
                    onTap: () {
                      setState(() => history.clear());
                      _savePrefs();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    title: Text(DictionaryConfig.strings['clearFavourites']!),
                    onTap: () {
                      setState(() => saved.clear());
                      _savePrefs();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  Text(
                    DictionaryConfig.strings['versionData']!.replaceFirst(
                      '{count}',
                      '${entries.length}',
                    ),
                    style: const TextStyle(color: AppTokens.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Map<String, dynamic>> _decodeRows(String encoded) =>
    DictionaryRepository.decodeRows(encoded);

Widget _meaningRow({
  required String label,
  required String value,
  required TextDirection direction,
  required bool card,
}) {
  if (value.trim().isEmpty) return const SizedBox.shrink();
  final size = card ? 18.0 : 20.0;
  final valueStyle = TextStyle(
    fontFamily: direction == TextDirection.rtl ? 'NotoNastaliqUrdu' : null,
    fontSize: direction == TextDirection.rtl ? size : (card ? 14 : 16),
    height: direction == TextDirection.rtl ? 2.0 : 1.5,
    color: AppTokens.secondary,
  );
  final labelStyle = TextStyle(
    fontFamily: direction == TextDirection.rtl ? 'NotoNastaliqUrdu' : null,
    fontSize: card ? 11 : 12,
    height: direction == TextDirection.rtl ? 2.0 : 1.5,
    color: AppTokens.accentSoft,
    fontWeight: FontWeight.w600,
  );
  return Directionality(
    textDirection: direction,
    child: RichText(
      textDirection: direction,
      textAlign: direction == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
      maxLines: card ? 2 : null,
      overflow: card ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
    ),
  );
}

String _dictionaryVersion(String encoded, int entryCount) {
  var hash = 0x811c9dc5;
  for (final unit in encoded.codeUnits) {
    final value = hash ^ unit;
    // Shift/add keeps the multiplication exact on Flutter Web's JS numbers.
    hash = (value + (value << 1) + (value << 4) + (value << 7) +
            (value << 8) + (value << 24)) &
        0xffffffff;
  }
  return '$entryCount-${hash.toRadixString(16).padLeft(8, '0')}';
}

class EntryDetail extends StatefulWidget {
  const EntryDetail({
    super.key,
    required this.entry,
    required this.allEntries,
    required this.saved,
    required this.onSave,
  });
  final DictionaryEntry entry;
  final List<DictionaryEntry> allEntries;
  final bool saved;
  final VoidCallback onSave;

  @override
  State<EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<EntryDetail> {
  late bool saved;
  @override
  void initState() {
    super.initState();
    saved = widget.saved;
  }

  DictionaryEntry get entry => widget.entry;
  List<DictionaryEntry> get allEntries => widget.allEntries;
  VoidCallback get onSave => widget.onSave;

  Future<void> _shareEntry(BuildContext context) async {
    final text =
        '${entry.word}\n${entry.urdu}\n${entry.english}\n${DictionaryConfig.strings['title']}';
    if (await web_share.shareText(text)) return;
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DictionaryConfig.strings['copied']!)),
        );
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final group = DictionarySearch(
      allEntries,
    ).groups.firstWhere((g) => g.norm == entry.wordNorm);
    final variants = List<String>.from(entry.raw['variants'] ?? const []);
    final sentences =
        List<Map<String, dynamic>>.from(
              (entry.raw['sentences'] ?? const []).map(
                (x) => Map<String, dynamic>.from(x),
              ),
            )
            .where(
              (s) => [
                'brahui',
                'urdu',
                'english',
                'audio',
              ].any((key) => '${s[key] ?? ''}'.trim().isNotEmpty),
            )
            .toList();
    return Scaffold(
      backgroundColor: AppTokens.bgBottom,
      appBar: AppBar(
        title: Text(DictionaryConfig.strings['entry']!),
        actions: [
          IconButton(
            tooltip: DictionaryConfig.strings['copy'],
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text: '${entry.word}\n${entry.urdu}\n${entry.english}',
              ),
            ),
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: DictionaryConfig.strings['share'],
            onPressed: () => _shareEntry(context),
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: DictionaryConfig.strings['saveWord'],
            onPressed: () {
              setState(() => saved = !saved);
              onSave();
            },
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              Text(
                entry.word,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 34,
                  height: 2.1,
                  fontWeight: FontWeight.bold,
                  color: AppTokens.primary,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LETTER',
                        style: TextStyle(
                          color: AppTokens.secondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        entry.letter,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 22,
                          height: 1.5,
                          color: AppTokens.accentSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (variants.length > 1)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: RichText(
                    textAlign: TextAlign.right,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${DictionaryConfig.strings['variants']}: ',
                          style: const TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 14,
                            height: 2,
                            color: AppTokens.secondary,
                          ),
                        ),
                        TextSpan(
                          text: variants.skip(1).join(' / '),
                          style: const TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 18,
                            height: 2,
                            color: AppTokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if ('${entry.raw['roman'] ?? ''}${entry.raw['ipa'] ?? ''}'
                  .isNotEmpty)
                Text(
                  '${entry.raw['roman'] ?? ''}  ${entry.raw['ipa'] ?? ''}',
                  style: const TextStyle(
                    color: AppTokens.phonetic,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 4),
              if ('${entry.raw['pos'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DictionaryConfig.posLabels[entry.raw['pos']]?['en'] ??
                        '${entry.raw['pos']}',
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                group.senses.length == 1
                    ? DictionaryConfig.strings['meaning']!
                    : DictionaryConfig.strings['definitionsSenses']!,
                style: const TextStyle(
                  color: AppTokens.muted,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              ...group.senses.asMap().entries.map(
                (s) => _sense(
                  s.key + 1,
                  s.value,
                  showNumber: group.senses.length > 1,
                ),
              ),
              if (sentences.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  DictionaryConfig.strings['examples']!,
                  style: const TextStyle(
                    color: AppTokens.muted,
                    letterSpacing: 1.4,
                  ),
                ),
                ...sentences.map(_sentence),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    DictionaryConfig.strings['noExamples']!,
                    style: const TextStyle(color: AppTokens.muted),
                  ),
                ),
              if ('${entry.raw['audio'] ?? ''}'.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.play_circle,
                    color: AppTokens.accent,
                  ),
                  title: Text(
                    DictionaryConfig.strings['playAudio']!,
                    style: const TextStyle(color: AppTokens.primary),
                  ),
                  onTap: () => _playDetail(context, '${entry.raw['audio']}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sense(int i, Map<String, String> s, {required bool showNumber}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showNumber)
              Text(
                '${DictionaryConfig.strings['sense']} $i',
                style: const TextStyle(
                  color: AppTokens.accentSoft,
                  fontSize: 12,
                ),
              ),
            _meaningRow(
              label: DictionaryConfig.strings['label_urdu_meaning']!,
              value: s['urdu'] ?? '',
              direction: TextDirection.rtl,
              card: false,
            ),
            _meaningRow(
              label: DictionaryConfig.strings['label_english_meaning']!,
              value: s['english'] ?? '',
              direction: TextDirection.ltr,
              card: false,
            ),
          ],
        ),
      );
  Widget _sentence(Map<String, dynamic> s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ('${s['brahui'] ?? ''}'.isNotEmpty)
          Text(
            '“${s['brahui']}”',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              height: 2.1,
              fontSize: 17,
              color: AppTokens.primary,
            ),
          ),
        if ('${s['urdu'] ?? ''}'.isNotEmpty)
          Text(
            '${s['urdu']}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              height: 2.1,
              color: AppTokens.secondary,
              fontSize: 15,
            ),
          ),
        if ('${s['english'] ?? ''}'.isNotEmpty)
          Text(
            '${s['english']}',
            style: const TextStyle(color: AppTokens.secondary, fontSize: 15),
          ),
      ],
    ),
  );
  Future<void> _playDetail(BuildContext context, String path) async {
    final p = AudioPlayer();
    try {
      await p.setAsset(path);
      await p.play();
    } catch (_) {
    } finally {
      p.dispose();
    }
  }
}

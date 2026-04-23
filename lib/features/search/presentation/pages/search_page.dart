import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/skeleton_widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../core/widgets/flowy_song_card.dart';
import '../../../../domain/entities/interest_entity.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';

import '../providers/search_history_provider.dart';
import '../../../home/presentation/widgets/song_tile.dart';
import '../widgets/interest_card.dart';
import '../widgets/trending_music_grid.dart';
import '../../../../core/theme/app_theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final MusicRepository _repo = sl<MusicRepository>();
  final FocusNode _focusNode = FocusNode();

  List<String> _suggestions = [];
  SearchResultEntity? _results;
  bool _isSearching = false;
  AudioCategory _selectedCategory = AudioCategory.music;
  String _lastQuery = '';
  InterestEntity? _activeInterest;
  List<SongEntity> _trendingSongs = [];
  bool _loadingTrending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _loadingTrending = true);
    final result = await _repo.getRecommendations();
    result.fold(
      (_) => setState(() => _loadingTrending = false),
      (songs) => setState(() {
        _trendingSongs = songs;
        _loadingTrending = false;
      }),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _results = null;
        _isSearching = false;
        _activeInterest = null;
      });
      return;
    }

    _fetchSuggestions(query);
  }

  Future<void> _fetchSuggestions(String query) async {
    final result = await _repo.getSearchSuggestions(query);
    if (!mounted) return;

    result.fold(
      (_) => {},
      (suggestions) {
        if (mounted && _results == null) {
          setState(() {
            _suggestions = suggestions.take(AppConstants.maxSearchSuggestions).toList();
          });
        }
      },
    );
  }

  Future<void> _search(String query, {InterestEntity? fromInterest}) async {
    final baseQuery = query.trim();
    if (baseQuery.isEmpty) return;
    _focusNode.unfocus();

    String finalQuery = baseQuery;
    if (fromInterest != null) {
      finalQuery = fromInterest.searchQuerySuffix;
    } else {
      if (_selectedCategory == AudioCategory.audiobooks) {
        finalQuery = '$baseQuery completo audiolibro español';
      } else if (_selectedCategory == AudioCategory.podcasts) {
        finalQuery = '$baseQuery podcast español';
      }
    }

    context.read<SearchHistoryProvider>().addQuery(fromInterest?.title ?? baseQuery);

    setState(() {
      _isSearching = true;
      _suggestions = [];
      _results = null;
      _activeInterest = fromInterest;
    });

    final result = await _repo.search(finalQuery);
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSearching = false);
        context.read<PlayerProvider>().reportManualError('Error: ${failure.message}');
      },
      (results) {
        List<SongEntity> filtered = results.songs;
        if (_selectedCategory != AudioCategory.music) {
          filtered.sort((a, b) => b.duration.compareTo(a.duration));
        }

        setState(() {
          _results = SearchResultEntity(query: finalQuery, songs: filtered);
          _isSearching = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(scheme, theme, isDesktop),
            const SizedBox(height: 16),
            _buildCategoryFilter(scheme),
            const SizedBox(height: 24),
            Expanded(
              child: _buildContent(theme, scheme, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(ColorScheme scheme, ThemeData theme, bool isDesktop) {
    return Container(
      padding: EdgeInsets.only(
        top: isDesktop ? 24 : 12,
        bottom: 8,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
        child: Hero(
          tag: 'search_bar',
          child: Material(
            color: Colors.transparent,
            child: SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              hintText: '  Búsqueda Universal Flowy...',
              hintStyle: WidgetStatePropertyAll(
                TextStyle(color: scheme.onSurface.withOpacity(0.4), fontSize: 14),
              ),
              leading: Icon(Icons.search_rounded, color: scheme.primary),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _suggestions = [];
                        _results = null;
                        _activeInterest = null;
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
              onSubmitted: (val) => _search(val),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withOpacity(0.5),
              ),
              elevation: const WidgetStatePropertyAll(0),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: scheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ColorScheme scheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: AudioCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          final label = switch (cat) {
            AudioCategory.music => 'Música',
            AudioCategory.audiobooks => 'Audiolibros',
            AudioCategory.podcasts => 'Podcasts',
          };
          final icon = switch (cat) {
            AudioCategory.music => Icons.music_note_rounded,
            AudioCategory.audiobooks => Icons.menu_book_rounded,
            AudioCategory.podcasts => Icons.podcasts_rounded,
          };

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(icon, size: 18, color: isSelected ? Colors.black : scheme.onSurface.withOpacity(0.6)),
              label: Text(label),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedCategory = cat;
                    _results = null;
                    _activeInterest = null;
                    _controller.clear();
                    _suggestions = [];
                  });
                }
              },
              side: BorderSide(color: isSelected ? scheme.primary : scheme.outline.withOpacity(0.2)),
              selectedColor: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.3),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : scheme.onSurface,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme scheme, bool isDesktop) {
    if (_isSearching) return const SongListSkeleton(count: 10);

    if (_results != null) {
      if (_activeInterest != null) {
        return Column(
          children: [
            _buildActiveInterestHeader(_activeInterest!, _results!, scheme, isDesktop),
            Expanded(child: _buildSearchResults(_results!, theme, scheme, isDesktop)),
          ],
        );
      }
      return _buildSearchResults(_results!, theme, scheme, isDesktop);
    }

    if (_controller.text.isNotEmpty && _suggestions.isNotEmpty) {
      return _buildSuggestionsGrid(scheme);
    }

    return _buildDiscoveryView(theme, scheme, isDesktop);
  }

  Widget _buildSuggestionsGrid(ColorScheme scheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final s = _suggestions[index];
        return ListTile(
          leading: const Icon(Icons.history_rounded, size: 20),
          title: Text(s),
          onTap: () {
            _controller.text = s;
            _search(s);
          },
        );
      },
    );
  }

  Widget _buildActiveInterestHeader(InterestEntity interest, SearchResultEntity results, ColorScheme scheme, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Hero(
        tag: 'interest_${interest.id}',
        child: Container(
          padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 28, isDesktop ? 48 : 32, 28, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: interest.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: interest.gradientColors.first.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(interest.icon, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      interest.title,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${results.songs.length} resultados encontrados',
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _suggestions = [];
                    _results = null;
                    _activeInterest = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchResultEntity results, ThemeData theme, ColorScheme scheme, bool isDesktop) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (results.songs.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 80, color: scheme.primary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('No encontramos nada para tu búsqueda', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          )
        else if (_activeInterest != null && _activeInterest!.subThemes.isNotEmpty && _selectedCategory == AudioCategory.audiobooks)
          ..._buildGroupedResults(results.songs, _activeInterest!.subThemes, theme, scheme, isDesktop)
        else if (isDesktop)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: results.songs.length > 6 ? 6 : 4,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = results.songs[index];
                  return FlowySongCard(
                    song: song,
                    onTap: () {
                      context.read<PlayerProvider>().playSong(song, queue: results.songs);
                      context.read<LibraryProvider>().addToHistory(song);
                    },
                  );
                },
                childCount: results.songs.length,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = results.songs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: SongTile(
                    song: song,
                    index: index,
                    onTap: () {
                      context.read<PlayerProvider>().playSong(song, queue: results.songs);
                      context.read<LibraryProvider>().addToHistory(song);
                    },
                  ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.05),
                );
              },
              childCount: results.songs.length,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildGroupedResults(List<SongEntity> songs, List<String> subThemes, ThemeData theme, ColorScheme scheme, bool isDesktop) {
    final Map<String, List<SongEntity>> groups = {};
    for (final themeLabel in subThemes) {
      final filtered = songs.where((s) => s.title.toLowerCase().contains(themeLabel.toLowerCase()) || s.artist.toLowerCase().contains(themeLabel.toLowerCase())).toList();
      if (filtered.isNotEmpty) groups[themeLabel] = filtered;
    }
    final allGroupedSongs = groups.values.expand((element) => element).toSet();
    final remaining = songs.where((s) => !allGroupedSongs.contains(s)).toList();
    if (remaining.isNotEmpty) groups['Más resultados'] = remaining;

    final List<Widget> slivers = [];
    for (final entry in groups.entries) {
      if (entry.key == 'Más resultados' && entry.value.length > 8) {
        slivers.add(SliverToBoxAdapter(child: _buildGroupHeader(entry.key, entry.value.length, scheme)));
        slivers.add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: entry.value.length > 6 ? 6 : 4,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = entry.value[index];
                return FlowySongCard(song: song, onTap: () {
                  context.read<PlayerProvider>().playSong(song, queue: entry.value);
                  context.read<LibraryProvider>().addToHistory(song);
                });
              },
              childCount: entry.value.length,
            ),
          ),
        ));
      } else {
        slivers.add(_HorizontalGroupSection(title: entry.key, songs: entry.value, theme: theme, scheme: scheme));
      }
    }
    return slivers;
  }

  Widget _buildGroupHeader(String title, int count, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 16),
      child: Row(
        children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white.withOpacity(0.9))),
          const SizedBox(width: 8),
          Text('($count)', style: const TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDiscoveryView(ThemeData theme, ColorScheme scheme, bool isDesktop) {
    final predefinedInterests = CategoryData.getInterestsForCategory(_selectedCategory);
    final historyProvider = context.watch<SearchHistoryProvider>();
    final customInterestsRaw = historyProvider.customInterests.where((c) => c['category'] == _selectedCategory.name).toList();
    final customInterests = customInterestsRaw.map((rawData) {
      final title = rawData['title'] ?? 'Custom';
      final hash = title.hashCode.abs();
      final hue1 = (hash % 360).toDouble();
      final hue2 = ((hash ~/ 360) % 360).toDouble();
      final c1 = HSLColor.fromAHSL(1.0, hue1, 0.7, 0.5).toColor();
      final c2 = HSLColor.fromAHSL(1.0, hue2, 0.7, 0.4).toColor();
      return InterestEntity(id: rawData['id'] ?? '', title: title, icon: Icons.bookmark_rounded, gradientColors: [c1, c2], category: _selectedCategory, searchQuerySuffix: title);
    }).toList();
    final allInterests = [...predefinedInterests, ...customInterests];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isDesktop ? 32 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentSection(historyProvider.history, theme, scheme),
          if (_trendingSongs.isNotEmpty) ...[
            TrendingMusicGrid(songs: _trendingSongs, onTap: (song) {
              context.read<PlayerProvider>().playSong(song, queue: _trendingSongs);
              context.read<LibraryProvider>().addToHistory(song);
            }),
            const SizedBox(height: 32),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text('Explorar por Interés', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allInterests.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isDesktop ? 8 : 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
              itemBuilder: (context, index) {
                if (index == allInterests.length) return _buildAddCustomCard(theme, scheme, historyProvider);
                final interest = allInterests[index];
                return InterestCard(id: interest.id, index: index, title: interest.title, icon: interest.icon, gradientColors: interest.gradientColors, onTap: () {
                  _controller.text = interest.title;
                  _search(interest.title, fromInterest: interest);
                }, onLongPress: interest.id.startsWith('custom_') ? () => _showDeleteCustomInterestDialog(context, interest, historyProvider) : null);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCustomCard(ThemeData theme, ColorScheme scheme, SearchHistoryProvider provider) {
    return GestureDetector(
      onTap: () => _showAddCustomInterestDialog(context, provider),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: scheme.surfaceContainerHighest.withOpacity(0.3), border: Border.all(color: scheme.outline.withOpacity(0.2), width: 2)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surfaceContainerHighest), child: Icon(Icons.add_rounded, color: scheme.onSurface, size: 28)),
              const SizedBox(height: 12),
              Text('Nueva Tarjeta', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCustomInterestDialog(BuildContext context, SearchHistoryProvider provider) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text('Crear Tarjeta Personalizada', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: 'Ej: Música Romántica Clásica', hintStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) { provider.addCustomInterest(controller.text, _selectedCategory.name); Navigator.pop(context); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Crear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteCustomInterestDialog(BuildContext context, InterestEntity interest, SearchHistoryProvider provider) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text('Eliminar Tarjeta', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('¿Deseas eliminar la tarjeta "${interest.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { provider.removeCustomInterest(interest.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(List<String> history, ThemeData theme, ColorScheme scheme) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recientes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              TextButton(onPressed: () => context.read<SearchHistoryProvider>().clearHistory(), child: Text('Limpiar', style: TextStyle(color: scheme.primary, fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ActionChip(
              label: Text(history[index]),
              onPressed: () { _controller.text = history[index]; _search(history[index]); },
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              side: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _HorizontalGroupSection extends StatelessWidget {
  final String title;
  final List<SongEntity> songs;
  final ThemeData theme;
  final ColorScheme scheme;

  const _HorizontalGroupSection({required this.title, required this.songs, required this.theme, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(title, songs.length, scheme),
          SizedBox(
            height: 240,
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 20),
                    child: FlowySongCard(song: song, onTap: () {
                      context.read<PlayerProvider>().playSong(song, queue: songs);
                      context.read<LibraryProvider>().addToHistory(song);
                    }),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, int count, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 16),
      child: Row(
        children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white.withOpacity(0.9))),
          const SizedBox(width: 8),
          Text('($count)', style: const TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }
}

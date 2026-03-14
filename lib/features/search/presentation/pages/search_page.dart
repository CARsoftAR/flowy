import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/skeleton_widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/entities/interest_entity.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../providers/search_history_provider.dart';
import '../../../home/presentation/widgets/song_tile.dart';
import '../widgets/interest_card.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
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

    // 1. Build Smart Query
    String finalQuery = baseQuery;
    if (fromInterest != null) {
      finalQuery = fromInterest.searchQuerySuffix;
    } else {
      // General category suffixes
      if (_selectedCategory == AudioCategory.audiobooks) {
        finalQuery = '$baseQuery completo audiolibro español';
      } else if (_selectedCategory == AudioCategory.podcasts) {
        finalQuery = '$baseQuery podcast español';
      } else if (_selectedCategory == AudioCategory.movies) {
        finalQuery = '$baseQuery pelicula completa español';
      }
    }

    // 2. Save to history
    context.read<SearchHistoryProvider>().addQuery(fromInterest?.title ?? baseQuery);

    setState(() {
      _isSearching = true;
      _suggestions = [];
      _results = null;
      _activeInterest = fromInterest;
    });

    // 3. Execute Search
    final result = await _repo.search(finalQuery);
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSearching = false);
        // Reportar el error a través del PlayerProvider para que se muestre en el snackbar/UI
        context.read<PlayerProvider>().reportManualError(
          'Error de búsqueda: ${failure.message}'
        );
      },
      (results) {
        // Filter specifically for long-form content if it's Podcasts/Audiobooks
        List<SongEntity> filtered = results.songs;
        if (_selectedCategory != AudioCategory.music) {
          filtered.sort((a, b) => b.duration.compareTo(a.duration));
        }

        bool forceVideo = _selectedCategory == AudioCategory.movies || (_activeInterest?.category == AudioCategory.movies);
        if (forceVideo) {
          filtered = filtered.map((s) => s.copyWith(isVideo: true)).toList();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(scheme, theme),
            Expanded(
              child: _buildContent(theme, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(ColorScheme scheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Hero(
              tag: 'search_bar',
              child: Material(
                color: Colors.transparent,
                child: SearchBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: '  Búsqueda Universal Flowy...',
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
                    scheme.surfaceContainerHighest.withOpacity(0.8),
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: scheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryFilter(scheme),
        ],
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
            AudioCategory.movies => 'Películas',
          };
          final icon = switch (cat) {
            AudioCategory.music => Icons.music_note_rounded,
            AudioCategory.audiobooks => Icons.menu_book_rounded,
            AudioCategory.podcasts => Icons.podcasts_rounded,
            AudioCategory.movies => Icons.movie_rounded,
          };

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(icon, 
                size: 18, 
                color: isSelected ? Colors.black : scheme.onSurface.withOpacity(0.6)
              ),
              label: Text(label),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedCategory = cat;
                    _results = null;
                    _activeInterest = null;
                  });
                }
              },
              side: BorderSide(
                color: isSelected ? scheme.primary : scheme.outline.withOpacity(0.2)
              ),
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

  Widget _buildContent(ThemeData theme, ColorScheme scheme) {
    if (_suggestions.isNotEmpty && _results == null) {
      return _buildSuggestionsGrid(scheme);
    }

    if (_isSearching) {
      return const SongListSkeleton(count: 10);
    }

    if (_results != null) {
      return _buildSearchResults(_results!, theme, scheme);
    }

    return _buildDiscoveryView(theme, scheme);
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

  Widget _buildSearchResults(SearchResultEntity results, ThemeData theme, ColorScheme scheme) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (_activeInterest != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Hero(
                tag: 'interest_${_activeInterest!.id}',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _activeInterest!.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(_activeInterest!.icon, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeInterest!.title,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 24, 
                                fontWeight: FontWeight.w900
                              ),
                            ),
                            Text(
                              '${results.songs.length} resultados encontrados',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
            ),
          ),
        
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
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = results.songs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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

  Widget _buildDiscoveryView(ThemeData theme, ColorScheme scheme) {
    final predefinedInterests = CategoryData.getInterestsForCategory(_selectedCategory);
    final historyProvider = context.watch<SearchHistoryProvider>();
    
    final customInterestsRaw = historyProvider.customInterests
        .where((c) => c['category'] == _selectedCategory.name)
        .toList();

    final customInterests = customInterestsRaw.map((rawData) {
      final title = rawData['title'] ?? 'Custom';
      final hash = title.hashCode.abs();
      // Generate pleasing random UI colors based on string hash
      final hue1 = (hash % 360).toDouble();
      final hue2 = ((hash ~/ 360) % 360).toDouble();
      final c1 = HSLColor.fromAHSL(1.0, hue1, 0.7, 0.5).toColor();
      final c2 = HSLColor.fromAHSL(1.0, hue2, 0.7, 0.4).toColor();
      
      return InterestEntity(
        id: rawData['id'] ?? '',
        title: title,
        icon: Icons.bookmark_rounded,
        gradientColors: [c1, c2],
        category: _selectedCategory,
        searchQuerySuffix: title, // Appended to searches
      );
    }).toList();

    final allInterests = [...predefinedInterests, ...customInterests];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentSection(historyProvider.history, theme, scheme),
          
          Text(
            'Explorar por Interés', 
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1
            )
          ),
          const SizedBox(height: 20),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allInterests.length + 1, // +1 for the "Add" card
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index == allInterests.length) {
                return _buildAddCustomCard(theme, scheme, historyProvider);
              }

              final interest = allInterests[index];
              return InterestCard(
                id: interest.id,
                index: index,
                title: interest.title,
                icon: interest.icon,
                gradientColors: interest.gradientColors,
                onTap: () {
                  _controller.text = interest.title;
                  _search(interest.title, fromInterest: interest);
                },
                onLongPress: interest.id.startsWith('custom_') 
                  ? () => _showDeleteCustomInterestDialog(context, interest, historyProvider)
                  : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddCustomCard(ThemeData theme, ColorScheme scheme, SearchHistoryProvider provider) {
    return GestureDetector(
      onTap: () => _showAddCustomInterestDialog(context, provider),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.surfaceContainerHighest.withOpacity(0.3),
          border: Border.all(color: scheme.outline.withOpacity(0.2), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                ),
                child: Icon(Icons.add_rounded, color: scheme.onSurface, size: 28),
              ),
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
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ej: Música Romántica Clásica',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addCustomInterest(controller.text, _selectedCategory.name);
                Navigator.pop(context);
              }
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
            onPressed: () {
              provider.removeCustomInterest(interest.id);
              Navigator.pop(context);
            },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recientes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            TextButton(
              onPressed: () => context.read<SearchHistoryProvider>().clearHistory(),
              child: Text('Limpiar', style: TextStyle(color: scheme.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ActionChip(
              label: Text(history[index]),
              onPressed: () {
                _controller.text = history[index];
                _search(history[index]);
              },
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

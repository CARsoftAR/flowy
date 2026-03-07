import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/skeleton_widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../home/presentation/widgets/song_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchPage — Instant search with suggestions and results
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _loadingSuggestions = false;
  String _lastQuery = '';

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
      });
      return;
    }

    _fetchSuggestions(query);
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _loadingSuggestions = true);

    await Future.delayed(
        Duration(milliseconds: AppConstants.searchDebounceMs));
    if (query != _controller.text.trim()) return; // Stale query

    final result = await _repo.getSearchSuggestions(query);
    if (!mounted) return;

    result.fold(
      (_) => {},
      (suggestions) {
        if (mounted) {
          setState(() {
            _suggestions =
                suggestions.take(AppConstants.maxSearchSuggestions).toList();
            _loadingSuggestions = false;
          });
        }
      },
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();

    setState(() {
      _isSearching = true;
      _suggestions = [];
      _results = null;
    });

    final result = await _repo.search(query.trim());
    if (!mounted) return;

    result.fold(
      (failure) => setState(() => _isSearching = false),
      (results) => setState(() {
        _results = results;
        _isSearching = false;
      }),
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
            // ── Search Bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Hero(
                tag: 'search_bar',
                child: Material(
                  color: Colors.transparent,
                  child: SearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    hintText: 'Canciones, artistas, álbumes...',
                    leading: Icon(Icons.search_rounded,
                        color: scheme.onSurface.withOpacity(0.5)),
                    trailing: [
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _suggestions = [];
                              _results = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    onSubmitted: _search,
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

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: _buildContent(theme, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme scheme) {
    // Suggestions dropdown
    if (_suggestions.isNotEmpty && _results == null) {
      return ListView.separated(
        padding: const EdgeInsets.only(top: 12),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final s = _suggestions[index];
          return ListTile(
            leading: Icon(Icons.search_rounded,
                color: scheme.onSurface.withOpacity(0.4), size: 20),
            title: Text(s),
            trailing: Icon(Icons.north_west_rounded,
                color: scheme.primary.withOpacity(0.6), size: 16),
            onTap: () {
              _controller.text = s;
              _search(s);
            },
          )
              .animate(delay: Duration(milliseconds: index * 40))
              .fadeIn()
              .slideX(begin: 0.04);
        },
      );
    }

    // Loading
    if (_isSearching) {
      return const SongListSkeleton(count: 10);
    }

    // Search results
    if (_results != null) {
      return _buildSearchResults(_results!, theme, scheme);
    }

    // Empty state
    return _buildEmptyState(theme, scheme);
  }

  Widget _buildSearchResults(
      SearchResultEntity results, ThemeData theme, ColorScheme scheme) {
    if (results.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'No hay resultados para "${results.query}"',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: results.songs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '${results.songs.length} resultados para "${results.query}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.45),
              ),
            ),
          );
        }

        final song = results.songs[index - 1];
        return SongTile(
          song: song,
          index: index - 1,
          onTap: () {
            final player = context.read<PlayerProvider>();
            final library = context.read<LibraryProvider>();
            player.playSong(song, queue: results.songs);
            library.addToHistory(song);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme) {
    final genres = [
      ('🎸', 'Rock'),
      ('🎵', 'Pop'),
      ('🎻', 'Classical'),
      ('🎷', 'Jazz'),
      ('🔊', 'Hip Hop'),
      ('🎹', 'Electronic'),
      ('🌍', 'World'),
      ('🎤', 'R&B'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Explorar géneros', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: genres.asMap().entries.map((entry) {
              final i = entry.key;
              final genre = entry.value;
              final colors = [
                [const Color(0xFF7C4DFF), const Color(0xFF448AFF)],
                [const Color(0xFFFF4081), const Color(0xFFFF6D00)],
                [const Color(0xFF00BCD4), const Color(0xFF1DE9B6)],
                [const Color(0xFF76FF03), const Color(0xFF00E5FF)],
                [const Color(0xFFFF6D00), const Color(0xFFFFD600)],
                [const Color(0xFFE040FB), const Color(0xFF7C4DFF)],
                [const Color(0xFF1DE9B6), const Color(0xFF448AFF)],
                [const Color(0xFFFF80AB), const Color(0xFFEA80FC)],
              ];
              final c = colors[i % colors.length];

              return GestureDetector(
                onTap: () => _search(genre.$2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: c, begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(genre.$1,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          genre.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate(delay: Duration(milliseconds: i * 60))
                  .fadeIn()
                  .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

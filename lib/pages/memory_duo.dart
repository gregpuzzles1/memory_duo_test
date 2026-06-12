import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage>
    with WidgetsBindingObserver {
  static const List<String> _allEmojis = <String>[
    '🇺🇸',
    '🌭',
    '🥧',
    '🎆',
    '⚾',
    '🦆',
    '🪐',
    '🤖',
    '⭐',
    '💖',
    '💡',
    '🐝',
    '🐜',
    '🚀',
    '🍔',
    '🎈',
    '☀️',
    '🌙',
  ];

  static const List<int> _levels = <int>[10, 18, 24];
  static const double _cardScaleFactor = 1;
  static const double _cubeGap = 10;
  static const double _boardMaxWidth = 870;

  double _tileSizeCapForRows(int totalRows) {
    if (totalRows >= 6) {
      return 64;
    }
    if (totalRows == 5) {
      return 72;
    }
    return 96;
  }

  final Random _random = Random();
  late final ConfettiController _confettiController;
  late final AudioPlayer _audioPlayer;
  int _layoutVersion = 0;

  List<MemoryCard> _cards = <MemoryCard>[];
  int _currentLevel = _levels.first;
  int _attempts = 0;
  int _invalidGuesses = 0;
  int _pairsFound = 0;
  int? _firstSelectedCard;
  bool _isResolvingTurn = false;
  DateTime? _startTime;
  final List<GameResult> _completedResults = <GameResult>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _audioPlayer = AudioPlayer();
    _setupLevel(_currentLevel);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) {
      return;
    }

    // Force a fresh board subtree after rotate/resize to avoid stale canvas
    // artifacts seen on iOS web during orientation transitions.
    setState(() {
      _layoutVersion++;
    });
  }

  Future<void> _playVictoryChime() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/victory_chime.wav'));
    } catch (error) {
      debugPrint('Victory chime failed to play: $error');
    }
  }

  Future<void> _playRestartChime() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/restart_chime.wav'));
    } catch (error) {
      debugPrint('Restart chime failed to play: $error');
    }
  }

  void _setupLevel(int level) {
    final int pairCount = level ~/ 2;
    final List<String> chosen = List<String>.from(_allEmojis)..shuffle(_random);
    final List<String> deck = _buildNonAdjacentDeck(level, chosen.take(pairCount).toList());

    setState(() {
      _currentLevel = level;
      _cards = deck
          .asMap()
          .entries
          .map(
            (MapEntry<int, String> entry) => MemoryCard(
              id: entry.key,
              emoji: entry.value,
            ),
          )
          .toList();
      _attempts = 0;
      _invalidGuesses = 0;
      _pairsFound = 0;
      _firstSelectedCard = null;
      _isResolvingTurn = false;
      _startTime = DateTime.now();
    });
  }

  List<String> _buildNonAdjacentDeck(int level, List<String> selectedEmojis) {
    final List<String> baseDeck = <String>[...selectedEmojis, ...selectedEmojis];
    final List<int> rowSizes = _rowSizesForLevel(level);

    List<String> bestAttempt = List<String>.from(baseDeck)..shuffle(_random);
    int bestAdjacencyCount = _adjacentMatchCount(bestAttempt, rowSizes);

    if (bestAdjacencyCount == 0) {
      return bestAttempt;
    }

    for (int i = 0; i < 1200; i++) {
      final List<String> candidate = List<String>.from(baseDeck)..shuffle(_random);
      final int adjacencyCount = _adjacentMatchCount(candidate, rowSizes);

      if (adjacencyCount == 0) {
        return candidate;
      }

      if (adjacencyCount < bestAdjacencyCount) {
        bestAdjacencyCount = adjacencyCount;
        bestAttempt = candidate;
      }
    }

    return bestAttempt;
  }

  List<int> _rowSizesForLevel(int level) {
    if (level == 10) {
      return <int>[4, 4, 2];
    }
    if (level == 18) {
      return <int>[4, 4, 4, 4, 2];
    }
    return <int>[4, 4, 4, 4, 4, 4];
  }

  int _adjacentMatchCount(List<String> deck, List<int> rowSizes) {
    final Map<String, int> positionByKey = <String, int>{};
    int flatIndex = 0;

    for (int row = 0; row < rowSizes.length; row++) {
      for (int col = 0; col < rowSizes[row]; col++) {
        positionByKey['$row:$col'] = flatIndex;
        flatIndex++;
      }
    }

    int adjacentMatches = 0;

    for (int row = 0; row < rowSizes.length; row++) {
      for (int col = 0; col < rowSizes[row]; col++) {
        final int currentIndex = positionByKey['$row:$col']!;
        final String currentEmoji = deck[currentIndex];

        final String rightKey = '$row:${col + 1}';
        final int? rightIndex = positionByKey[rightKey];
        if (rightIndex != null && deck[rightIndex] == currentEmoji) {
          adjacentMatches++;
        }

        final String downKey = '${row + 1}:$col';
        final int? downIndex = positionByKey[downKey];
        if (downIndex != null && deck[downIndex] == currentEmoji) {
          adjacentMatches++;
        }
      }
    }

    return adjacentMatches;
  }

  Future<void> _handleCardTap(int index) async {
    if (_isResolvingTurn) {
      return;
    }

    final MemoryCard tappedCard = _cards[index];
    if (tappedCard.isMatched || tappedCard.isRevealed) {
      return;
    }

    setState(() {
      _cards[index] = tappedCard.copyWith(isRevealed: true);
    });

    if (_firstSelectedCard == null) {
      setState(() {
        _firstSelectedCard = index;
      });
      return;
    }

    final int firstIndex = _firstSelectedCard!;
    final MemoryCard firstCard = _cards[firstIndex];
    final MemoryCard secondCard = _cards[index];

    setState(() {
      _attempts += 1;
      _firstSelectedCard = null;
    });

    if (firstCard.emoji == secondCard.emoji) {
      setState(() {
        _cards[firstIndex] = _cards[firstIndex].copyWith(isMatched: true);
        _cards[index] = _cards[index].copyWith(isMatched: true);
        _pairsFound += 1;
      });

      if (_pairsFound == _currentLevel ~/ 2) {
        _onLevelCompleted();
      }
      return;
    }

    setState(() {
      _invalidGuesses += 1;
      _isResolvingTurn = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) {
      return;
    }

    setState(() {
      _cards[firstIndex] = _cards[firstIndex].copyWith(isRevealed: false);
      _cards[index] = _cards[index].copyWith(isRevealed: false);
      _isResolvingTurn = false;
    });
  }

  Future<void> _onLevelCompleted() async {
    final Duration elapsed = DateTime.now().difference(_startTime ?? DateTime.now());
    final GameResult result = GameResult(
      level: _currentLevel,
      attempts: _attempts,
      invalidGuesses: _invalidGuesses,
      elapsed: elapsed,
      finishedAt: DateTime.now(),
    );

    _completedResults.add(result);
    _playVictoryChime();
    _confettiController.play();

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) {
      return;
    }

    await _showCompletionModal(result);
  }

  Future<void> _showCompletionModal(GameResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Congratulations!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Level: ${result.level} cubes'),
              Text('Attempts: ${result.attempts}'),
              Text('Invalid guesses: ${result.invalidGuesses}'),
              Text('Time to complete: ${_formatDuration(result.elapsed)}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _playRestartChime();
                _setupLevel(_currentLevel);
              },
              child: const Text('Play Again'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('View Results'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResultsModal() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final List<GameResult> sorted = List<GameResult>.from(_completedResults)
          ..sort((GameResult a, GameResult b) => b.finishedAt.compareTo(a.finishedAt));

        return AlertDialog(
          title: const Text('Results History'),
          content: SizedBox(
            width: 340,
            child: sorted.isEmpty
                ? const Text('No results yet. Complete a level to see stats.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sorted
                          .map(
                            (GameResult result) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Level ${result.level}: Attempts ${result.attempts}, '
                                'Invalid ${result.invalidGuesses}, '
                                'Time ${_formatDuration(result.elapsed)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCardTile(MemoryCard card, int index) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool showFace = card.isRevealed || card.isMatched;
    final Color dayModeHiddenCubeColor =
        ColorScheme.fromSeed(seedColor: Colors.orange).tertiaryContainer;
    final Color revealedColor = isDarkMode
        ? dayModeHiddenCubeColor
        : colorScheme.primaryContainer;

    return Center(
      child: FractionallySizedBox(
        widthFactor: _cardScaleFactor,
        heightFactor: _cardScaleFactor,
        child: InkWell(
          onTap: () => _handleCardTap(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: showFace ? revealedColor : colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: card.isMatched ? colorScheme.primary : colorScheme.outlineVariant,
                width: card.isMatched ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  card.emoji,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: showFace ? colorScheme.onPrimaryContainer : Colors.transparent,
                    fontFamilyFallback: const <String>[
                      'Segoe UI Emoji',
                      'Apple Color Emoji',
                      'Noto Color Emoji',
                    ],
                  ),
                ),
                Text(
                  '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: showFace ? Colors.transparent : colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowLayoutBoard(
    List<int> rowSizes, {
    bool centerLastShortRowInMiddle = false,
  }) {
    int cursor = 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = _cubeGap;
        const int columns = 4;
        final int totalRows = rowSizes.length;
        final Size screenSize = MediaQuery.of(context).size;
        final double availableWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : screenSize.width;

        final double safeWidth = max(availableWidth, (columns * spacing) + 1);
        final double tileSizeByWidth =
            (safeWidth - ((columns - 1) * spacing)) / columns;
        final double tileSizeCap = _tileSizeCapForRows(totalRows);
        final double tileSize = max(
          36,
          min(tileSizeByWidth, tileSizeCap),
        );
        final List<Widget> boardRows = <Widget>[];

        for (int rowIndex = 0; rowIndex < rowSizes.length; rowIndex++) {
          final int rowSize = rowSizes[rowIndex];
          final bool isLastShortRow = rowIndex == rowSizes.length - 1 && rowSize < columns;
          final bool placeInMiddle = centerLastShortRowInMiddle && isLastShortRow;

          final List<Widget> rowChildren = <Widget>[];

          if (placeInMiddle) {
            rowChildren.add(SizedBox(width: tileSize, height: tileSize));
            rowChildren.add(const SizedBox(width: spacing));
          }

          for (int i = 0; i < rowSize; i++) {
            final int cardIndex = cursor;
            final MemoryCard card = _cards[cardIndex];
            rowChildren.add(
              SizedBox(
                width: tileSize,
                height: tileSize,
                child: _buildCardTile(card, cardIndex),
              ),
            );
            cursor++;

            if (i < rowSize - 1) {
              rowChildren.add(const SizedBox(width: spacing));
            }
          }

          if (placeInMiddle) {
            rowChildren.add(const SizedBox(width: spacing));
            rowChildren.add(SizedBox(width: tileSize, height: tileSize));
          }

          boardRows.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: rowChildren,
            ),
          );

          if (rowIndex < rowSizes.length - 1) {
            boardRows.add(const SizedBox(height: spacing));
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: boardRows,
          ),
        );
      },
    );
  }

  Widget _buildTenCubeBoard() {
    return _buildRowLayoutBoard(const <int>[4, 4, 2]);
  }

  Widget _buildEighteenCubeBoard() {
    return _buildRowLayoutBoard(
      const <int>[4, 4, 4, 4, 2],
      centerLastShortRowInMiddle: true,
    );
  }

  Widget _buildTwentyFourCubeBoard() {
    return _buildRowLayoutBoard(const <int>[4, 4, 4, 4, 4, 4]);
  }

  Widget _buildBoard() {
    if (_currentLevel == 10) {
      return _buildTenCubeBoard();
    }

    if (_currentLevel == 18) {
      return _buildEighteenCubeBoard();
    }

    return _buildTwentyFourCubeBoard();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Orientation orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Emoji Memory Game'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Memory Duo Home',
            onPressed: () => Navigator.of(context).pushNamed('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: 'About',
            onPressed: () => Navigator.of(context).pushNamed('/about'),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to Day Mode' : 'Switch to Night Mode',
            onPressed: widget.onThemeToggle,
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      for (final int level in _levels)
                        ChoiceChip(
                          label: Text('$level cubes'),
                          selected: _currentLevel == level,
                          onSelected: (bool selected) {
                            if (selected) {
                              _setupLevel(level);
                            }
                          },
                        ),
                      FilledButton.icon(
                        onPressed: () {
                          _playRestartChime();
                          _setupLevel(_currentLevel);
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Restart Game'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showResultsModal,
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('View Results'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        Center(
                          child: Text('Current level: $_currentLevel cubes'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 18,
                          runSpacing: 8,
                          children: <Widget>[
                            Text('Pairs found: $_pairsFound/${_currentLevel ~/ 2}'),
                            Text('Attempts: $_attempts'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _boardMaxWidth),
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          'board-${orientation.name}-$_currentLevel-${_cards.length}-$_layoutVersion',
                        ),
                        child: _buildBoard(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 25,
                emissionFrequency: 0.05,
                gravity: 0.2,
                shouldLoop: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryCard {
  const MemoryCard({
    required this.id,
    required this.emoji,
    this.isRevealed = false,
    this.isMatched = false,
  });

  final int id;
  final String emoji;
  final bool isRevealed;
  final bool isMatched;

  MemoryCard copyWith({
    bool? isRevealed,
    bool? isMatched,
  }) {
    return MemoryCard(
      id: id,
      emoji: emoji,
      isRevealed: isRevealed ?? this.isRevealed,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}

class GameResult {
  const GameResult({
    required this.level,
    required this.attempts,
    required this.invalidGuesses,
    required this.elapsed,
    required this.finishedAt,
  });

  final int level;
  final int attempts;
  final int invalidGuesses;
  final Duration elapsed;
  final DateTime finishedAt;
}

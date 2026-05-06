import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final WebSocketService _wsService = WebSocketService();
  Map<String, dynamic>? _gameState;
  bool _cancelled = false;
  bool _wsConnected = false;
  String? _wsError;
  Timer? _statusTimer;

  // Powerup name map
  static const _powerupNames = {
    1: '🎲 Remove Random Opponent Card',
    2: '✂️ Remove Opponent\'s Last Card',
    3: '🗑️ Remove My Last Card',
    4: '💨 Remove My Last 2 Cards',
    5: '🎯 Target Override',
  };

  @override
  void initState() {
    super.initState();
    final gs = Provider.of<GameState>(context, listen: false);
    final matchId = gs.matchId!;
    final username = gs.username!;

    _wsService.onStateUpdated = (state) {
      setState(() { _gameState = state; });
    };
    _wsService.onMatchCancelled = () {
      setState(() { _cancelled = true; });
    };
    _wsService.onConnected = () {
      setState(() { _wsConnected = true; _wsError = null; });
    };
    _wsService.onError = (err) {
      setState(() { _wsError = err.toString(); });
    };
    // When opponent joins (or we join an already-waiting match), auto-start.
    _wsService.onPlayerJoined = () {
      _wsService.sendAction('start_game', username);
    };
    _wsService.connect(matchId, username);
    
    _startStatusPolling(matchId, username);
  }

  void _startStatusPolling(String matchId, String username) {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_gameState != null || _cancelled) {
        timer.cancel();
        return;
      }
      try {
        final res = await ApiService.getMatchStatus(matchId);
        if (res['status'] == 'in_progress') {
           // Someone joined! Try to start game.
           // This helps if the WebSocket 'player_joined' signal was missed due to worker isolation.
           _wsService.sendAction('start_game', username);
        }
      } catch (e) {
        // Silently ignore polling errors
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  void _startGame() async {
    final gs = Provider.of<GameState>(context, listen: false);
    final username = gs.username!;
    final matchId = gs.matchId!;

    try {
      final res = await ApiService.getMatchStatus(matchId);
      if (res['status'] != 'in_progress') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot start yet: Waiting for an opponent to join Match #$matchId!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    } catch (e) {
      // Ignore network errors and try anyway
    }

    _wsService.sendAction('start_game', username);
  }

  void _drawCard() {
    final username = Provider.of<GameState>(context, listen: false).username!;
    _wsService.sendAction('draw_card', username);
  }

  void _stand() {
    final username = Provider.of<GameState>(context, listen: false).username!;
    _wsService.sendAction('stand', username);
  }

  void _usePowerup(int powerupId) {
    if (powerupId == 5) {
      _showTargetOverrideDialog();
    } else {
      final username = Provider.of<GameState>(context, listen: false).username!;
      _wsService.sendAction('use_powerup', username, powerupId);
    }
  }

  void _showTargetOverrideDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎯 Target Override'),
        content: const Text('Choose a new target number for both players:'),
        actions: [
          _targetButton(19, Colors.greenAccent),
          _targetButton(21, Colors.blueAccent),
          _targetButton(28, Colors.redAccent),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _targetButton(int value, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: () {
        Navigator.pop(context);
        final username = Provider.of<GameState>(context, listen: false).username!;
        _wsService.sendActionWithTarget('use_powerup', username, 5, value);
      },
      child: Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'ranked': return const Color(0xFFD97706);
      case 'casual': return const Color(0xFF059669);
      default: return Colors.purple;
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'ranked': return '🥇 RANKED';
      case 'casual': return '🎮 CASUAL';
      default: return '🏠 PRIVATE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<GameState>(context);
    final username = gs.username!;
    final mode = gs.matchMode;

    if (_cancelled) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Match Cancelled', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Opponent disconnected.', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gameState == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Game Room'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(_modeLabel(mode), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: _modeColor(mode).withValues(alpha: 0.25),
                side: BorderSide(color: _modeColor(mode)),
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text('Match ID: ${gs.matchId}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Waiting for both players...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                _wsConnected ? 'Connected to Server ✅' : 'Connecting...',
                style: TextStyle(color: _wsConnected ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
              ),
              if (_wsError != null) ...[
                const SizedBox(height: 8),
                Text('Error: $_wsError', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 48),
              if (_wsConnected)
                ElevatedButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Match Manually'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final state = _gameState!;
    final players = state['players'] as Map<String, dynamic>?;
    
    if (state.isEmpty || players == null || players[username] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game Room')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Initializing Game State...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: _startGame, child: const Text('Force Start')),
            ],
          ),
        ),
      );
    }
    
    final me = players[username] as Map<String, dynamic>;
    final p1 = state['p1'] as String?;
    final p2 = state['p2'] as String?;
    
    if (p1 == null || p2 == null) {
       return const Scaffold(body: Center(child: Text('Error: Player data missing')));
    }

    final opponentUsername = p1 == username ? p2 : p1;
    final opponent = players[opponentUsername] as Map<String, dynamic>?;
    
    if (opponent == null) {
       return const Scaffold(body: Center(child: Text('Waiting for opponent to connect...')));
    }

    final isMyTurn = state['current_turn'] == username;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${state['round']} · Target ${state['target_number']}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(_modeLabel(mode), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: _modeColor(mode).withValues(alpha: 0.25),
              side: BorderSide(color: _modeColor(mode)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Turn banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: isMyTurn
                ? const Color(0xFF059669).withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.2),
            child: Text(
              isMyTurn ? '⚡ Your Turn!' : '⏳ Opponent\'s Turn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMyTurn ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Opponent Area
                  _PlayerPanel(
                    label: 'Opponent · $opponentUsername',
                    lives: (opponent['lives'] as int?) ?? 0,
                    visibleCards: List<int>.from(opponent['visible_cards'] ?? []),
                    hiddenCount: (opponent['hidden_cards'] as List?)?.length ?? 0,
                    hasStood: (opponent['has_stood'] as bool?) ?? false,
                    isOpponent: true,
                    color: Colors.redAccent,
                  ),

                  const SizedBox(height: 8),

                  // Central info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoChip(label: 'Target', value: '${state['target_number'] ?? 21}', color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      _InfoChip(label: 'Status', value: state['status'] ?? 'Active', color: Colors.white54),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // My Area
                  _PlayerPanel(
                    label: 'You · $username',
                    lives: (me['lives'] as int?) ?? 0,
                    visibleCards: List<int>.from(me['visible_cards'] ?? []),
                    hiddenCards: List<int>.from(me['hidden_cards'] ?? []),
                    hasStood: (me['has_stood'] as bool?) ?? false,
                    isOpponent: false,
                    color: Colors.blueAccent,
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  if (isMyTurn && !(me['has_stood'] as bool))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _drawCard,
                          icon: const Icon(Icons.add_card),
                          label: const Text('Draw'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _stand,
                          icon: const Icon(Icons.back_hand),
                          label: const Text('Stand'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),

                  // Power-ups
                  if (isMyTurn && !((me['has_stood'] as bool?) ?? false) && (me['powerups'] as List? ?? []).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Power-ups:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: (me['powerups'] as List? ?? []).map<Widget>((p) {
                        final id = (p as int?) ?? 0;
                        return OutlinedButton(
                          onPressed: () => _usePowerup(id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            _powerupNames[id] ?? 'Power-up $id',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (state['status'] == 'finished') ...[
                    const SizedBox(height: 16),
                    const Text('🏁 Match Over!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Lobby'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Widgets
// ---------------------------------------------------------------------------

class _PlayerPanel extends StatelessWidget {
  final String label;
  final int lives;
  final List<int> visibleCards;
  final List<int>? hiddenCards;
  final int? hiddenCount;
  final bool hasStood;
  final bool isOpponent;
  final Color color;

  const _PlayerPanel({
    required this.label,
    required this.lives,
    required this.visibleCards,
    this.hiddenCards,
    this.hiddenCount,
    required this.hasStood,
    required this.isOpponent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final total = visibleCards.fold<int>(0, (a, b) => a + b) +
        (hiddenCards?.fold<int>(0, (a, b) => a + b) ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              // Lives as hearts
              Row(
                children: List.generate(3, (i) => Icon(
                  i < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                  size: 18,
                )),
              ),
              if (hasStood) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('STOOD', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Visible cards
              ...visibleCards.map((c) => _CardBadge(value: c, hidden: false)),
              // Hidden cards
              if (isOpponent)
                ...List.generate(
                  hiddenCount ?? 0,
                  (_) => const _CardBadge(value: 0, hidden: true),
                )
              else
                ...(hiddenCards ?? []).map((c) => _CardBadge(value: c, hidden: false)),
              const Spacer(),
              Text(
                'Total: ${isOpponent ? "??" : total}',
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final int value;
  final bool hidden;
  const _CardBadge({required this.value, required this.hidden});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 36,
      height: 48,
      decoration: BoxDecoration(
        color: hidden ? Colors.grey.shade800 : const Color(0xFF1E1B4B),
        border: Border.all(color: hidden ? Colors.grey : Colors.purpleAccent, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        hidden ? '?' : '$value',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: hidden ? Colors.grey : Colors.white,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            TextSpan(text: value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}




import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';

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
  Timer? _turnTimer;
  int _turnSecondsLeft = 10;

  @override
  void initState() {
    super.initState();
    final gs = Provider.of<GameState>(context, listen: false);
    final matchId = gs.matchId!;
    final username = gs.username!;

    _wsService.onStateUpdated = (state) {
      if (!mounted) return;
      final gs = Provider.of<GameState>(context, listen: false);
      final username = gs.username!;
      final isMyTurn = state['current_turn'] == username;
      final wasMyTurn = _gameState != null && _gameState!['current_turn'] == username;
      setState(() { _gameState = state; });
      // Start/reset turn timer only when it becomes my turn
      if (isMyTurn && !wasMyTurn) {
        _startTurnTimer(username);
      } else if (!isMyTurn) {
        _cancelTurnTimer();
      }
    };
    _wsService.onMatchCancelled = () {
      if (!mounted) return;
      setState(() { _cancelled = true; });
    };
    _wsService.onConnected = () {
      if (!mounted) return;
      setState(() { _wsConnected = true; _wsError = null; });
    };
    _wsService.onError = (err) {
      if (!mounted) return;
      setState(() { _wsError = err.toString(); });
    };
    _wsService.onDisconnected = () {
      if (!mounted) return;
      setState(() { _wsConnected = false; });
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
    _turnTimer?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  void _startTurnTimer(String username) {
    _cancelTurnTimer();
    setState(() { _turnSecondsLeft = 10; });
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _turnSecondsLeft--; });
      if (_turnSecondsLeft <= 0) {
        timer.cancel();
        // Auto-stand when time runs out
        _wsService.sendAction('stand', username);
      }
    });
  }

  void _cancelTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    if (mounted) setState(() { _turnSecondsLeft = 10; });
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
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Unable to verify match status. Trying anyway...';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
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

  void _showGameMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: Colors.white70),
            SizedBox(width: 8),
            Text('Game Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to surrender and exit to the lobby? This will count as a loss.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Surrender & Exit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              _wsService.disconnect();
              _statusTimer?.cancel();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
          ),
        ],
      ),
    );
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
    final target = state['target_number']?.toString() ?? '21';
    final myPowerups = List<int>.from(me['powerups'] ?? []);
    final myTotal = List<int>.from(me['visible_cards'] ?? []).fold<int>(0, (a, b) => a + b) +
        List<int>.from(me['hidden_cards'] ?? []).fold<int>(0, (a, b) => a + b);
    final opponentVisibleTotal = List<int>.from(opponent['visible_cards'] ?? []).fold<int>(0, (a, b) => a + b);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF10131D), Color(0xFF08090F), Color(0xFF07070B)],
            center: Alignment(0, -0.2),
            radius: 1.12,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0x33212433),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0x335D6590)),
                        ),
                      ),
                      onPressed: () {
                        _wsService.disconnect();
                        _statusTimer?.cancel();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LobbyScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(_modeLabel(mode), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: _modeColor(mode).withValues(alpha: 0.2),
                      side: BorderSide(color: _modeColor(mode).withValues(alpha: 0.6)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      tooltip: 'Menu',
                      onPressed: () => _showGameMenu(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PlayerArea(
                  label: 'Opponent',
                  username: opponentUsername,
                  lives: (opponent['lives'] as int?) ?? 0,
                  visibleCards: List<int>.from(opponent['visible_cards'] ?? []),
                  hiddenCount: (opponent['hidden_cards'] as List?)?.length ?? 0,
                  hasStood: (opponent['has_stood'] as bool?) ?? false,
                  isOpponent: true,
                  color: const Color(0xFFA15AFB),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xAA141723),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x554F5AC0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x663D2A82), blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.adjust, color: Color(0xFF9D5DFF), size: 16),
                          const SizedBox(height: 4),
                          const Text('TARGET', style: TextStyle(color: Color(0xFF9EA5B9), fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 3),
                          Text(
                            target,
                            style: const TextStyle(
                              color: Color(0xFFA965FF),
                              fontSize: 44,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              shadows: [Shadow(color: Color(0x882A0E66), blurRadius: 20)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 210,
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xAA171822),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x334E577A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACTION LOG', style: TextStyle(color: Color(0xFFAA8CFF), fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 5),
                          Text('• ${state['status'] ?? 'Game active'}', style: const TextStyle(color: Color(0xFFBFC5D8), fontSize: 11)),
                          Text(
                            '• ${isMyTurn ? "Your turn ($_turnSecondsLeft)" : "Opponent turn"}',
                            style: const TextStyle(color: Color(0xFFBFC5D8), fontSize: 11),
                          ),
                          Text(
                            '• Visible total: $opponentVisibleTotal',
                            style: const TextStyle(color: Color(0xFFBFC5D8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _PlayerArea(
                    label: 'Player',
                    username: username,
                    lives: (me['lives'] as int?) ?? 0,
                    visibleCards: List<int>.from(me['visible_cards'] ?? []),
                    hiddenCards: List<int>.from(me['hidden_cards'] ?? []),
                    hasStood: (me['has_stood'] as bool?) ?? false,
                    isOpponent: false,
                    color: const Color(0xFF53D5FF),
                    bottomChild: Column(
                      children: [
                        if (isMyTurn && !(me['has_stood'] as bool) && state['status'] != 'finished')
                          Row(
                            children: [
                              Expanded(
                                child: _BattleButton(
                                  label: '+ DRAW',
                                  filled: true,
                                  onPressed: _drawCard,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _BattleButton(
                                  label: '— STAND',
                                  filled: false,
                                  onPressed: _stand,
                                ),
                              ),
                            ],
                          ),
                        if (myPowerups.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: Row(
                              children: myPowerups.map((id) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: OutlinedButton(
                                      onPressed: () => _usePowerup(id),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: const Color(0xCC0A0C13),
                                        side: const BorderSide(color: Color(0x335AD7FF)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(_powerupIcon(id), color: const Color(0xFF57D9FF), size: 14),
                                          const SizedBox(height: 3),
                                          Text(
                                            _powerupShortName(id),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Color(0xFF95DEFF), fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        if (state['status'] == 'finished') ...[
                          const SizedBox(height: 10),
                          const Text(
                            'MATCH OVER',
                            style: TextStyle(color: Color(0xFFD0D6E9), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _BattleButton(
                            label: 'BACK TO LOBBY',
                            filled: true,
                            onPressed: () {
                              _wsService.disconnect();
                              _statusTimer?.cancel();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LobbyScreen()),
                              );
                            },
                          ),
                        ],
                        if (!isMyTurn && state['status'] != 'finished')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Opponent turn... ${_wsConnected ? "" : "(reconnecting)"}',
                              style: const TextStyle(color: Color(0xFF9EA5B9), fontSize: 11),
                            ),
                          ),
                        if (_wsError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _wsError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: $myTotal',
                          style: const TextStyle(color: Color(0xFF53D5FF), fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _powerupIcon(int id) {
    switch (id) {
      case 1:
        return Icons.casino_outlined;
      case 2:
        return Icons.content_cut;
      case 3:
        return Icons.delete_outline;
      case 4:
        return Icons.layers_clear_outlined;
      case 5:
        return Icons.gps_fixed;
      default:
        return Icons.auto_awesome;
    }
  }

  String _powerupShortName(int id) {
    switch (id) {
      case 1:
        return 'Remove rand';
      case 2:
        return 'Swap card';
      case 3:
        return 'Remove own';
      case 4:
        return 'Double remove';
      case 5:
        return 'Override';
      default:
        return 'Power-up';
    }
  }
}

// ---------------------------------------------------------------------------
// Reusable Widgets
// ---------------------------------------------------------------------------

class _PlayerArea extends StatelessWidget {
  final String label;
  final String username;
  final int lives;
  final List<int> visibleCards;
  final List<int>? hiddenCards;
  final int? hiddenCount;
  final bool hasStood;
  final bool isOpponent;
  final Color color;
  final Widget? bottomChild;

  const _PlayerArea({
    required this.label,
    required this.username,
    required this.lives,
    required this.visibleCards,
    this.hiddenCards,
    this.hiddenCount,
    required this.hasStood,
    required this.isOpponent,
    required this.color,
    this.bottomChild,
  });

  @override
  Widget build(BuildContext context) {
    final cardCount = visibleCards.length + (isOpponent ? (hiddenCount ?? 0) : (hiddenCards?.length ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xB3131620),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$label ',
                style: const TextStyle(color: Color(0xFFF2F4FF), fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                username,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              ...List.generate(
                3,
                (i) => Icon(
                  i < lives ? Icons.favorite : Icons.favorite_border,
                  color: i < lives ? Colors.redAccent : const Color(0xFF646B82),
                  size: 13,
                ),
              ),
              const Spacer(),
              Text(
                'Cards: $cardCount',
                style: const TextStyle(color: Color(0xFF9EA5B8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              ...visibleCards.map((c) => _PlayingCard(value: c, hidden: false, color: color)),
              if (isOpponent)
                ...List.generate(
                  hiddenCount ?? 0,
                  (_) => const _PlayingCard(value: 0, hidden: true, color: Color(0xFFA15AFB)),
                )
              else
                ...(hiddenCards ?? []).map((c) => _PlayingCard(value: c, hidden: false, color: Color(0xFF53D5FF))),
            ],
          ),
          if (isOpponent) ...[
            const SizedBox(height: 6),
            Text(
              'Visible Total: ${visibleCards.fold<int>(0, (a, b) => a + b)}',
              style: const TextStyle(color: Color(0xFF8F96AD), fontSize: 10),
            ),
          ],
          if (hasStood) ...[
            const SizedBox(height: 6),
            const Text('STOOD', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
          if (!isOpponent && bottomChild != null) ...[
            const SizedBox(height: 10),
            bottomChild!,
          ],
        ],
      ),
    );
  }
}

class _PlayingCard extends StatelessWidget {
  final int value;
  final bool hidden;
  final Color color;
  const _PlayingCard({required this.value, required this.hidden, required this.color});

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return Container(
        width: 38,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [const Color(0xFF22253A), color.withValues(alpha: 0.45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.question_mark, color: Color(0xFFB8BDD1), size: 18),
      );
    }

    return Container(
      width: 54,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(color: color.withValues(alpha: 0.45), blurRadius: 12)],
        ),
      ),
    );
  }
}

class _BattleButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  const _BattleButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled ? const Color(0xFFB04FFF) : const Color(0xBB0D0F16),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: filled ? const Color(0xFFB04FFF) : const Color(0x334E577A)),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ),
    );
  }
}




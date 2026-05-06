import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/websocket_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final WebSocketService _wsService = WebSocketService();
  Map<String, dynamic>? _gameState;

  @override
  void initState() {
    super.initState();
    final matchId = Provider.of<GameState>(context, listen: false).matchId!;
    _wsService.onStateUpdated = (state) {
      setState(() {
        _gameState = state;
      });
    };
    _wsService.connect(matchId);
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  void _startGame() {
    final username = Provider.of<GameState>(context, listen: false).username!;
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
    final username = Provider.of<GameState>(context, listen: false).username!;
    _wsService.sendAction('use_powerup', username, powerupId);
  }

  @override
  Widget build(BuildContext context) {
    final username = Provider.of<GameState>(context).username!;

    if (_gameState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game Room')),
        body: Center(
          child: ElevatedButton(
            onPressed: _startGame,
            child: const Text('Start Game / Waiting for players...'),
          ),
        ),
      );
    }

    final state = _gameState!;
    final me = state['players'][username];
    
    // Determine opponent username
    String opponentUsername = state['p1'] == username ? state['p2'] : state['p1'];
    final opponent = state['players'][opponentUsername];

    return Scaffold(
      appBar: AppBar(
        title: Text('Match: ${state['status']} | Round: ${state['round']}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Opponent Area
            Expanded(
              child: Container(
                color: Colors.red.withOpacity(0.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Opponent: $opponentUsername - Lives: ${opponent['lives']}'),
                    Text('Visible Cards: ${opponent['visible_cards']}'),
                    Text('Hidden Cards: [?] (${opponent['hidden_cards'].length})'),
                    if (opponent['has_stood']) const Text('STATUS: STOOD', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
            const Divider(),
            // Game Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Target: ${state['target_number']} | Turn: ${state['current_turn']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            // Player Area
            Expanded(
              child: Container(
                color: Colors.blue.withOpacity(0.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('You: $username - Lives: ${me['lives']}'),
                    Text('Visible Cards: ${me['visible_cards']}'),
                    Text('Hidden Cards: ${me['hidden_cards']}'),
                    if (me['has_stood']) const Text('STATUS: STOOD', style: TextStyle(color: Colors.blue)),
                    const SizedBox(height: 10),
                    if (state['current_turn'] == username && !me['has_stood'])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(onPressed: _drawCard, child: const Text('Draw')),
                          const SizedBox(width: 10),
                          ElevatedButton(onPressed: _stand, child: const Text('Stand')),
                        ],
                      ),
                    const SizedBox(height: 10),
                    if (state['current_turn'] == username && !me['has_stood'] && (me['powerups'] as List).isNotEmpty)
                      Wrap(
                        children: (me['powerups'] as List).map((p) {
                           return ElevatedButton(
                             onPressed: () => _usePowerup(p),
                             child: Text('Powerup $p'),
                           );
                        }).toList(),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

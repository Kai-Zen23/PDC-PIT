import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _joinController = TextEditingController();

  Future<void> _createMatch() async {
    final username = Provider.of<GameState>(context, listen: false).username!;
    try {
      final res = await ApiService.createMatch(username);
      if (res.containsKey('match_id')) {
        Provider.of<GameState>(context, listen: false).setMatch(res['match_id'].toString());
        _goToGame();
      }
    } catch (e) {
      print("Error creating match: \$e");
    }
  }

  Future<void> _joinMatch() async {
    final username = Provider.of<GameState>(context, listen: false).username!;
    final matchId = _joinController.text;
    try {
      final res = await ApiService.joinMatch(username, matchId);
      if (res.containsKey('match_id')) {
        Provider.of<GameState>(context, listen: false).setMatch(res['match_id'].toString());
        _goToGame();
      }
    } catch (e) {
      print("Error joining match: \$e");
    }
  }

  void _goToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = Provider.of<GameState>(context).username;
    
    return Scaffold(
      appBar: AppBar(title: Text('Lobby - $username')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _createMatch,
                child: const Text('Create New Match'),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _joinController,
                decoration: const InputDecoration(labelText: 'Match ID to Join'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _joinMatch,
                child: const Text('Join Match'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

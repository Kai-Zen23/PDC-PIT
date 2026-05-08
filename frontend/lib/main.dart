import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/lobby_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class GameState extends ChangeNotifier {
  String? username;
  String? matchId;
  String matchMode = 'casual'; // 'casual', 'ranked', 'private'
  int rating = 1200;
  String? joinCode; // for private lobbies

  void setUser(String user, {int elo = 1200}) {
    username = user;
    rating = elo;
    notifyListeners();
  }

  void setMatch(String match, {String mode = 'casual', String? code}) {
    matchId = match;
    matchMode = mode;
    joinCode = code;
    notifyListeners();
  }

  void updateRating(int newRating) {
    rating = newRating;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameState(),
      child: MaterialApp(
        title: 'Card Clash 21',
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.deepPurple,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C3AED),
            secondary: Color(0xFFD97706),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.login(text);
      if (res.containsKey('username')) {
        final int elo = res['rating'] ?? 1200;
        if (!mounted) return;
        Provider.of<GameState>(context, listen: false).setUser(res['username'], elo: elo);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LobbyScreen()),
        );
      } else {
        setState(() { _error = 'Login failed. Try again.'; });
      }
    } catch (e) {
      final message = e is ApiException ? e.message : 'Network error. Check connection.';
      setState(() { _error = message; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🃏 Card Clash 21',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Online Multiplayer Card Game',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Enter Game',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


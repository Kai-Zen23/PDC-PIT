import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/lobby_screen.dart';

void main() {
  runApp(const MyApp());
}

class GameState extends ChangeNotifier {
  String? username;
  String? matchId;

  void setUser(String user) {
    username = user;
    notifyListeners();
  }

  void setMatch(String match) {
    matchId = match;
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

  void _login() {
    if (_controller.text.isNotEmpty) {
      Provider.of<GameState>(context, listen: false).setUser(_controller.text);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Card Clash 21')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  void _showNotAvailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is handled in the lobby after login.'),
        backgroundColor: const Color(0xFF9C27B0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.08,
            colors: [
              Color(0xFF141822),
              Color(0xFF080A10),
              Color(0xFF0F0A1E),
              Color(0xFF091C25),
            ],
            stops: [0.0, 0.45, 0.80, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const _CardSilhouette(left: 40, top: 70, angle: -0.22, opacity: 0.14),
            const _CardSilhouette(right: 42, top: 170, angle: 0.26, opacity: 0.14),
            const _CardSilhouette(left: 56, bottom: 130, angle: 0.16, opacity: 0.12),
            const _CardSilhouette(right: 72, bottom: 80, angle: -0.2, opacity: 0.12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SparkleIcon(),
                          SizedBox(width: 12),
                          Text(
                            'CARD CLASH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.2,
                              shadows: [
                                Shadow(color: Color(0x66FFFFFF), blurRadius: 8),
                                Shadow(color: Color(0xE67629FF), blurRadius: 26),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          _SparkleIcon(),
                        ],
                      ),
                      const Text(
                        '21',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 62,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          shadows: [
                            Shadow(color: Color(0x66FFFFFF), blurRadius: 8),
                            Shadow(color: Color(0xD67629FF), blurRadius: 26),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'MASTER THE ODDS. DOMINATE THE TABLE.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFACB1C5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3.2,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFFE27BFF),
                        decoration: InputDecoration(
                          hintText: 'Enter username',
                          hintStyle: const TextStyle(color: Color(0xFF7B7F93)),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD7A5FF)),
                          filled: true,
                          fillColor: const Color(0x33121724),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(color: Color(0x8CC056FF), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(color: Color(0xFFE27BFF), width: 1.6),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: _MenuButton(
                          label: _loading ? 'CONNECTING...' : 'Join Now',
                          onTap: _loading ? null : _login,
                          primary: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _MenuButton(
                          label: 'CREATE ROOM',
                          onTap: _loading ? null : () => _showNotAvailable('Create Room'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _MenuButton(
                          label: 'JOIN ROOM',
                          onTap: _loading ? null : () => _showNotAvailable('Join Room'),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'A multiplayer strategy card game',
                        style: TextStyle(
                          color: Color(0xFF505463),
                          fontSize: 12,
                          letterSpacing: 0.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _MenuButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFFB93DFF), Color(0xFF8D35FF), Color(0xFF7020F5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isPrimary ? null : const Color(0x9312141C),
            border: isPrimary ? null : Border.all(color: const Color(0xE0C056FF), width: 1.2),
            boxShadow: [
              if (isPrimary)
                BoxShadow(
                  color: _hovered ? const Color(0xA8C96BFF) : const Color(0x7FC96BFF),
                  blurRadius: _hovered ? 26 : 18,
                  spreadRadius: _hovered ? 1 : 0,
                )
              else
                BoxShadow(
                  color: _hovered ? const Color(0x66C96BFF) : const Color(0x3FC96BFF),
                  blurRadius: _hovered ? 18 : 10,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkleIcon extends StatelessWidget {
  const _SparkleIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.auto_awesome,
      size: 17,
      color: Color(0xFFF3D8FF),
      shadows: [
        Shadow(color: Color(0xFFE66FFF), blurRadius: 16),
      ],
    );
  }
}

class _CardSilhouette extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double angle;
  final double opacity;

  const _CardSilhouette({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.angle,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: angle,
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
            child: Container(
              width: 86,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  colors: [Color(0x45C5C9DD), Color(0x117B86AA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0x40D0D8F2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


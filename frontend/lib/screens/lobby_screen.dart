import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _searching = false;
  String? _searchMode;
  final TextEditingController _codeController = TextEditingController();

  Future<void> _findMatch(String mode) async {
    final gs = Provider.of<GameState>(context, listen: false);
    setState(() { _searching = true; _searchMode = mode; });
    try {
      final res = await ApiService.findMatch(gs.username!, mode);
      if (res.containsKey('match_id')) {
        gs.setMatch(res['match_id'].toString(), mode: mode);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    } catch (e) {
      _showError('Network error. Please retry.');
    } finally {
      if (mounted) setState(() { _searching = false; _searchMode = null; });
    }
  }

  Future<void> _createLobby() async {
    final gs = Provider.of<GameState>(context, listen: false);
    try {
      final res = await ApiService.createLobby(gs.username!);
      if (res.containsKey('match_id') && res.containsKey('join_code')) {
        final code = res['join_code'] as String;
        gs.setMatch(res['match_id'].toString(), mode: 'private', code: code);
        if (!mounted) return;
        _showCodeDialog(code, res['match_id'].toString());
      }
    } catch (e) {
      _showError('Could not create lobby.');
    }
  }

  void _showCodeDialog(String code, String matchId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🏠 Private Lobby Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your friend:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Waiting for your friend to join...', style: TextStyle(color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GameScreen()),
              );
            },
            child: const Text('Go to Game Room'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinLobby() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError('Enter a valid 6-character code.');
      return;
    }
    final gs = Provider.of<GameState>(context, listen: false);
    try {
      final res = await ApiService.joinLobby(gs.username!, code);
      if (res.containsKey('match_id')) {
        gs.setMatch(res['match_id'].toString(), mode: 'private', code: code);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      } else {
        _showError(res['error'] ?? 'Invalid code.');
      }
    } catch (e) {
      _showError('Could not join lobby.');
    }
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔑 Join Private Lobby'),
        content: TextField(
          controller: _codeController,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Enter 6-char Code',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _joinLobby(); },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<GameState>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    const Text('🃏 Card Clash 21', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),

                    // Player badge
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(gs.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          const Icon(Icons.emoji_events, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text('${gs.rating}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Ranked
                    _ModeCard(
                      icon: '🥇',
                      title: 'Ranked Match',
                      subtitle: 'Skill-based matching · Elo rating changes · No early quit',
                      color: const Color(0xFFD97706),
                      loading: _searching && _searchMode == 'ranked',
                      onTap: _searching ? null : () => _findMatch('ranked'),
                    ),
                    const SizedBox(height: 16),

                    // Casual
                    _ModeCard(
                      icon: '🎮',
                      title: 'Casual Match',
                      subtitle: 'No rating impact · Relaxed rules · Great for learning',
                      color: const Color(0xFF059669),
                      loading: _searching && _searchMode == 'casual',
                      onTap: _searching ? null : () => _findMatch('casual'),
                    ),
                    const SizedBox(height: 32),

                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),

                    // Private lobby buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _searching ? null : _createLobby,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Lobby'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _searching ? null : _showJoinDialog,
                            icon: const Icon(Icons.login),
                            label: const Text('Join Lobby'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_searching) ...[
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text(
                            'Searching for ${_searchMode == 'ranked' ? 'ranked' : 'casual'} opponent...',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => setState(() { _searching = false; _searchMode = null; }),
                        child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (loading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: color, strokeWidth: 2))
            else
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}


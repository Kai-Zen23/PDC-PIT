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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

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
      _showError(e is ApiException ? e.message : 'Network error. Please retry.');
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
      _showError(e is ApiException ? e.message : 'Could not create lobby.');
    }
  }

  void _showCodeDialog(String code, String matchId) {
    final username = Provider.of<GameState>(context, listen: false).username ?? 'Player1';
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xCC05070C),
      builder: (_) => _NeonLobbyDialogFrame(
        onBack: () => Navigator.pop(context),
        child: _NeonLobbyPanel(
          title: 'GAME LOBBY',
          subtitle: 'Share the room code with your opponent',
          children: [
            const _NeonSectionLabel('ROOM CODE'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFF080A11),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xA35B2AD9)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x665B2AD9), blurRadius: 16),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Color(0xFFB667FF),
                        fontSize: 41,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 66,
                  width: 66,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF58D6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF0A2530)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _NeonSectionLabel('PLAYERS (1/2)', icon: Icons.groups_2_outlined),
            const SizedBox(height: 10),
            _NeonPlayerRow(
              username: username,
              ready: true,
              waiting: false,
            ),
            const SizedBox(height: 10),
            const _NeonPlayerRow(
              username: 'Waiting...',
              ready: false,
              waiting: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _NeonActionButton(
                    label: 'READY',
                    variant: _ActionButtonVariant.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 0,
                  child: SizedBox(
                    width: 130,
                    child: _NeonActionButton(
                      label: 'LEAVE',
                      variant: _ActionButtonVariant.red,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        _showError('Invalid lobby response. Please try again.');
      }
    } catch (e) {
      _showError(e is ApiException ? e.message : 'Could not join lobby.');
    }
  }

  void _showJoinDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      barrierColor: const Color(0xCC05070C),
      builder: (_) => _NeonLobbyDialogFrame(
        onBack: () => Navigator.pop(context),
        child: _NeonLobbyPanel(
          title: 'JOIN ROOM',
          subtitle: 'Enter the room code to join your opponent lobby',
          children: [
            const _NeonSectionLabel('ROOM CODE'),
            const SizedBox(height: 10),
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFF080A11),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xA35B2AD9)),
                boxShadow: const [
                  BoxShadow(color: Color(0x665B2AD9), blurRadius: 16),
                ],
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _codeController,
                maxLength: 6,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Color(0xFFB667FF),
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 6,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  hintText: 'ABC123',
                  hintStyle: TextStyle(color: Color(0x665C6377), letterSpacing: 4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _NeonActionButton(
                    label: 'JOIN ROOM',
                    variant: _ActionButtonVariant.green,
                    onTap: () {
                      Navigator.pop(context);
                      _joinLobby();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 0,
                  child: SizedBox(
                    width: 130,
                    child: _NeonActionButton(
                      label: 'LEAVE',
                      variant: _ActionButtonVariant.red,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

class _NeonLobbyDialogFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback onBack;

  const _NeonLobbyDialogFrame({
    required this.child,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x66171B24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                ),
              ),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _NeonLobbyPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _NeonLobbyPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: const Color(0xE7181B23),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xA55C2ADE)),
        boxShadow: const [
          BoxShadow(color: Color(0x804C1FAF), blurRadius: 32, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF0F1FF),
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9BA2B3), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NeonSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _NeonSectionLabel(this.label, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFFA34BFF), size: 18),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8BECF),
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _NeonPlayerRow extends StatelessWidget {
  final String username;
  final bool ready;
  final bool waiting;

  const _NeonPlayerRow({
    required this.username,
    required this.ready,
    this.waiting = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = ready ? const Color(0xCC0ED186) : const Color(0x664D3A92);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xD8070A11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 11,
            color: ready ? const Color(0xFF10DE8B) : const Color(0xFFA5A9B8),
          ),
          const SizedBox(width: 10),
          Text(
            username,
            style: const TextStyle(color: Color(0xFFE7EAF5), fontSize: 23, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (!waiting)
            Text(
              ready ? 'READY' : 'NOT READY',
              style: TextStyle(
                color: ready ? const Color(0xFF10DE8B) : const Color(0xFFD4A23E),
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }
}

enum _ActionButtonVariant { green, red }

class _NeonActionButton extends StatelessWidget {
  final String label;
  final _ActionButtonVariant variant;
  final VoidCallback onTap;

  const _NeonActionButton({
    required this.label,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGreen = variant == _ActionButtonVariant.green;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isGreen ? const Color(0xFF2FCF7B) : const Color(0x00101010),
          foregroundColor: isGreen ? const Color(0xFFEAFFF3) : const Color(0xFFDC3D43),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isGreen ? const Color(0xFF29BE71) : const Color(0xFF8F2025),
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}


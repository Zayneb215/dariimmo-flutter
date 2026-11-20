import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool manual = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        _poll?.cancel();
        await fresh.getIdToken(true); // met à jour le token (règles Firestore)
        if (!mounted) return;
        context.go('/explore');
      } else if (manual && mounted) {
        setState(
          () => _message =
              "Email pas encore vérifié. Ouvrez le lien reçu, puis réessayez.",
        );
      }
    } catch (_) {}
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cooldown > 0) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      FirebaseAuth.instance.setLanguageCode('fr');
      await user.sendEmailVerification();
      setState(() => _message = 'Email envoyé. Vérifiez aussi vos spams.');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      setState(
        () => _message = e.code == 'too-many-requests'
            ? 'Trop de demandes. Réessayez dans quelques minutes.'
            : "Envoi impossible (${e.code}).",
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _useOtherEmail() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/explore'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Vérifiez votre email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Nous avons envoyé un lien de confirmation à\n$email\n\nCliquez sur le lien, puis revenez ici.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.grey, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => _check(manual: true),
                child: const Text("J'ai vérifié mon email"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_sending || _cooldown > 0) ? null : _resend,
                child: Text(
                  _cooldown > 0
                      ? "Renvoyer l'email ($_cooldown s)"
                      : "Renvoyer l'email",
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _useOtherEmail,
                child: const Text(
                  'Utiliser un autre email',
                  style: TextStyle(color: AppTheme.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

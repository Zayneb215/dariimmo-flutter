import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isSignup = false;
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/explore');
  }

  Future<void> _createProfile(User user, String name) async {
    try {
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .set({
        'name': name,
        'email': user.email ?? '',
        'phone': '',
        'avatarUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));
    } catch (_) {
      // on ne bloque pas la connexion si le profil échoue
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

            if (_isSignup) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: email, password: pass);
        final name = _nameCtrl.text.trim();
        await cred.user!.updateDisplayName(name);
        await _createProfile(cred.user!, name);
        try {
          auth.setLanguageCode('fr');
          await cred.user!.sendEmailVerification();
        } catch (_) {
          // l'utilisateur pourra renvoyer l'email depuis l'écran suivant
        }
        if (!mounted) return;
        context.go('/verify-email');
        return;
      } else {
        final cred = await auth.signInWithEmailAndPassword(
            email: email, password: pass);
        if (!(cred.user?.emailVerified ?? false)) {
          if (!mounted) return;
          context.go('/verify-email');
          return;
        }
      }
      _goBack();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e.code));
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );
      final cred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (cred.additionalUserInfo?.isNewUser ?? false) {
        await _createProfile(cred.user!, cred.user!.displayName ?? '');
      }
      _goBack();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Connexion Google impossible.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e.code));
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

Future<void> _forgotPassword() async {
  final ctrl = TextEditingController(text: _emailCtrl.text.trim());
  final email = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mot de passe oublié'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Entrez votre email. Nous vous enverrons un lien pour créer un nouveau mot de passe.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'exemple@mail.com'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Envoyer')),
      ],
    ),
  );
  if (email == null || email.isEmpty) return;

  try {
    FirebaseAuth.instance.setLanguageCode('fr');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Si ce compte existe, un email a été envoyé. Vérifiez aussi vos spams.')),
    );
  } on FirebaseAuthException catch (e) {
    setState(() => _error = _message(e.code));
  }
}
  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      default:
        return 'Une erreur est survenue ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.home_rounded,
                    size: 56, color: AppTheme.primary),
                const SizedBox(height: 8),
                const Text('DariImmo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
                const SizedBox(height: 4),
                Text(_isSignup ? 'Créer un compte' : 'Se connecter',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.grey)),
                const SizedBox(height: 32),
                if (_isSignup) ...[
                  _label('Nom complet'),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(hintText: 'Ahmed Ben Ali'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Entrez votre nom'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                _label('Email'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration:
                      const InputDecoration(hintText: 'exemple@mail.com'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email invalide'
                      : null,
                ),
                const SizedBox(height: 16),
                _label('Mot de passe'),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? '6 caractères minimum'
                      : null,
                ),
                const SizedBox(height: 8),
                if (!_isSignup)
                  Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        activeColor: AppTheme.primary,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? true),
                      ),
                      const Text('Se souvenir de moi',
                          style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Mot de passe oublié ?',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isSignup ? "S'inscrire" : 'Se connecter'),
                ),
                const SizedBox(height: 20),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: AppTheme.grey)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _google,
                  icon: const Icon(Icons.g_mobiledata,
                      size: 28, color: AppTheme.dark),
                  label: const Text('Continuer avec Google',
                      style: TextStyle(
                          color: AppTheme.dark, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignup
                          ? 'Déjà un compte ? '
                          : 'Pas encore de compte ? ',
                      style: const TextStyle(color: AppTheme.grey),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isSignup = !_isSignup;
                        _error = null;
                      }),
                      child: Text(
                        _isSignup ? 'Se connecter' : "S'inscrire",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );
}
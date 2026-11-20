import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class GuestPrompt extends StatelessWidget {
  final String title;
  final String headline;
  final String subtitle;

  const GuestPrompt({
    super.key,
    required this.title,
    required this.headline,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w700)),
            const SizedBox(height: 40),
            Text(headline,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(fontSize: 15, color: AppTheme.grey)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('Connexion'),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../listings/data/listing.dart';
import '../../listings/presentation/listing_card.dart';
import '../../listings/providers/listings_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  Future<void> _delete(BuildContext context, Listing l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer l'annonce"),
        content: Text('Supprimer "${l.title}" définitivement ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFD64545)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(l.id)
          .delete();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes annonces'),
        backgroundColor: Colors.white,
      ),
      body: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_work_outlined,
                        size: 64, color: AppTheme.primary),
                    const SizedBox(height: 16),
                    const Text("Vous n'avez pas encore d'annonce.",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Vos annonces publiées apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/publish'),
                      child: const Text('Publier une annonce'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) => ListingCard(
              listing: items[i],
              onDelete: () => _delete(context, items[i]),
            ),
          );
        },
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/listing.dart';

int _byDateDesc(Listing a, Listing b) {
  final da = a.createdAt ?? DateTime.now();
  final db = b.createdAt ?? DateTime.now();
  return db.compareTo(da);
}

/// Toutes les annonces (Accueil)
final listingsProvider = StreamProvider<List<Listing>>((ref) {
  return FirebaseFirestore.instance.collection('listings').snapshots().map((
    snap,
  ) {
    final items = snap.docs.map((d) => Listing.fromDoc(d)).toList();
    items.sort(_byDateDesc);
    return items;
  });
});

/// Mes annonces (profil)
final myListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(<Listing>[]);
  return FirebaseFirestore.instance
      .collection('listings')
      .where('ownerId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) {
        final items = snap.docs.map((d) => Listing.fromDoc(d)).toList();
        items.sort(_byDateDesc);
        return items;
      });
});

/// Une annonce par id (page détail)
final listingProvider = StreamProvider.family<Listing?, String>((ref, id) {
  return FirebaseFirestore.instance
      .collection('listings')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Listing.fromDoc(s) : null);
});

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../data/listing.dart';

class ListingCard extends ConsumerWidget {
  final Listing listing;
  final VoidCallback? onDelete; // affiché seulement dans "Mes annonces"

  const ListingCard({super.key, required this.listing, this.onDelete});

  static const _venteColor = AppTheme.primary;
  static const _locationColor = Color(0xFF2F80ED);
  static const _heartColor = Color(0xFFE5484D);

  String get _price => listing.priceLabel.replaceAll('DT', 'TND');

  Future<void> _toggleFavorite(BuildContext context, bool isFav) async {
    if (FirebaseAuth.instance.currentUser == null) {
      context.push('/login');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FavoritesService.toggle(listing.id, currentlyFavorite: isFav);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              isFav ? 'Retiré des favoris.' : 'Ajouté aux favoris ❤️',
            ),
          ),
        );
    } catch (e) {
      debugPrint('FAVORITE ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Action impossible. Vérifiez votre connexion.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null;
    final isVente = listing.transaction == 'vente';
    final isFav =
        ref.watch(favoriteIdsProvider).value?.contains(listing.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => context.push('/listing/${listing.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Photo ----------
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.6,
                      child: image == null
                          ? Container(color: const Color(0xFFEFEFEF))
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(color: const Color(0xFFEFEFEF)),
                              errorBuilder: (_, error, __) {
                                debugPrint('IMAGE ERROR: $error');
                                return Container(
                                  color: const Color(0xFFEFEFEF),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                );
                              },
                            ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isVente ? _venteColor : _locationColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isVente ? 'Vente' : 'Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: onDelete != null
                          ? _circleButton(
                              Icons.delete_outline,
                              const Color(0xFFD64545),
                              onDelete!,
                            )
                          : _circleButton(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              _heartColor,
                              () => _toggleFavorite(context, isFav),
                            ),
                    ),
                  ],
                ),

                // ---------- Infos ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _price,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (listing.priceSuffix.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '/ mois',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (listing.city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppTheme.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (listing.surface > 0) ...[
                            _stat(
                              Icons.square_foot_outlined,
                              '${listing.surface} m²',
                            ),
                            const SizedBox(width: 22),
                          ],
                          _stat(Icons.bed_outlined, '${listing.rooms}'),
                          const SizedBox(width: 22),
                          _stat(Icons.bathtub_outlined, '${listing.bathrooms}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.dark),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.dark,
          ),
        ),
      ],
    );
  }
}

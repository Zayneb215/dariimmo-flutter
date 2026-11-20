import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_data.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../map/presentation/fullscreen_map_screen.dart';
import '../../map/presentation/map_widgets.dart';
import '../data/amenities.dart';
import '../data/listing.dart';
import '../providers/listings_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _descExpanded = false;
  bool _allAmenities = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _back() => context.canPop() ? context.pop() : context.go('/explore');

  /// true si connecté, sinon ouvre le login
  bool _requireLogin() {
    if (FirebaseAuth.instance.currentUser == null) {
      context.push('/login');
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- Favori
  Future<void> _favorite(bool isFav) async {
    if (!_requireLogin()) return;
    try {
      await FavoritesService.toggle(widget.id, currentlyFavorite: isFav);
      if (mounted) {
        _snack(isFav ? 'Retiré des favoris.' : 'Ajouté aux favoris ❤️');
      }
    } catch (_) {
      if (mounted) _snack('Action impossible. Vérifiez votre connexion.');
    }
  }

  // ---------------------------------------------------------------- Appeler
  Future<void> _call(Listing l) async {
    if (!_requireLogin()) return;

    final raw = l.ownerPhone.trim();
    final phone = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      _snack(
        "Le propriétaire n'a pas renseigné de numéro. Envoyez-lui un message.",
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Numéro du propriétaire',
                style: TextStyle(fontSize: 16, color: AppTheme.grey),
              ),
              const SizedBox(height: 4),
              if (l.ownerName.isNotEmpty)
                Text(
                  l.ownerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 12),
              SelectableText(
                raw,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  var ok = false;
                  try {
                    ok = await launchUrl(Uri(scheme: 'tel', path: phone));
                  } catch (_) {}
                  if (!ok && mounted) {
                    _snack(
                      "L'appel n'est pas possible sur cet appareil. Copiez le numéro.",
                    );
                  }
                },
                icon: const Icon(Icons.call),
                label: const Text('Appeler'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: raw));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _snack('Numéro copié.');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Copier le numéro'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Message
  Future<void> _message(Listing l) async {
    if (!_requireLogin()) return;
    if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
      context.push('/verify-email');
      return;
    }
    try {
      final id = await ChatService.openConversation(l);
      if (!mounted) return;
      context.push('/chat/$id');
    } catch (e) {
      debugPrint('CHAT ERROR: $e');
      if (mounted) _snack("Impossible d'ouvrir la conversation : $e");
    }
  }

  // ---------------------------------------------------------------- Build
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingProvider(widget.id));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur : $e')),
      ),
      data: (l) {
        if (l == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Cette annonce n'existe plus.")),
          );
        }
        return _content(l);
      },
    );
  }

  Widget _content(Listing l) {
    final me = FirebaseAuth.instance.currentUser;
    final isMine = me != null && me.uid == l.ownerId;
    final isFav = ref.watch(favoriteIdsProvider).value?.contains(l.id) ?? false;

    final all = l.amenities.map(amenityByKey).whereType<Amenity>().toList();
    final visible = _allAmenities ? all : all.take(6).toList();
    final longDesc = l.description.length > 160;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gallery(l),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l.priceLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (l.priceSuffix.isNotEmpty)
                                Text(
                                  l.priceSuffix,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (l.fullAddress.isNotEmpty)
                        Text(
                          l.fullAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.grey,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l.detailsLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppTheme.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.publishedAgo,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                      _divider(),

                      // ---------- À propos ----------
                      _sectionTitle('À propos du logement'),
                      Text(
                        l.description,
                        maxLines: _descExpanded ? null : 4,
                        overflow: _descExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                      if (longDesc)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _descExpanded = !_descExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _descExpanded
                                  ? 'Afficher moins'
                                  : 'Afficher plus',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),

                      // ---------- Équipements ----------
                      if (all.isNotEmpty) ...[
                        _divider(),
                        _sectionTitle('Ce que ce logement offre'),
                        for (final a in visible)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(a.icon, size: 26),
                                const SizedBox(width: 16),
                                Text(
                                  a.label,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        if (all.length > 6)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: () => setState(
                                () => _allAmenities = !_allAmenities,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: AppTheme.dark,
                                side: const BorderSide(color: AppTheme.dark),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _allAmenities
                                    ? 'Réduire'
                                    : 'Afficher les ${all.length} équipements',
                              ),
                            ),
                          ),
                      ],

                      // ---------- Carte ----------
                      _divider(),
                      _sectionTitle('Où vous serez'),
                      if (l.hasLocation)
                        _miniMap(l)
                      else
                        Text(
                          l.city.isEmpty
                              ? 'Position non renseignée.'
                              : 'Position exacte non renseignée (${l.city}).',
                          style: const TextStyle(color: AppTheme.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // boutons flottants sur la photo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _roundBtn(Icons.arrow_back, _back),
                    _roundBtn(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      () => _favorite(isFav),
                      color: isFav ? const Color(0xFFE5484D) : AppTheme.dark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(l, isMine),
    );
  }

  // ---------------------------------------------------------------- Galerie
  Widget _gallery(Listing l) {
    final urls = l.imageUrls;
    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          if (urls.isEmpty)
            Container(color: const Color(0xFFEFEFEF))
          else
            PageView.builder(
              controller: _pageCtrl,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Image.network(
                urls[i],
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(color: const Color(0xFFEFEFEF)),
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEFEFEF),
                  child: const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          if (urls.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Mini carte
  Widget _miniMap(Listing l) {
    final point = LatLng(l.lat!, l.lng!);
    void open() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenMapScreen(point: point, title: l.title),
      ),
    );

    return GestureDetector(
      onTap: open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 260,
          child: Stack(
            children: [
              AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: osmTileUrl,
                      userAgentPackageName: osmUserAgent,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 64,
                          height: 64,
                          child: const HouseMarker(),
                        ),
                      ],
                    ),
                    osmAttribution(),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.open_in_full, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Barre du bas
  Widget _bottomBar(Listing l, bool isMine) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE8EEF8),
                child: Icon(Icons.person, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.ownerName.isNotEmpty ? l.ownerName : 'Propriétaire',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isMine)
                const Text(
                  'Votre annonce',
                  style: TextStyle(color: AppTheme.grey),
                )
              else ...[
                ElevatedButton(
                  onPressed: () => _call(l),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.call),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _message(l),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(130, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Helpers UI
  Widget _roundBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = AppTheme.dark,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icon, color: color),
    ),
  );

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(height: 1, color: Color(0xFFEDEDED)),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      t,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

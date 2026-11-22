import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/listings_provider.dart';
import 'listing_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  String _filter = 'all'; // all | vente | location
  String _query = '';
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // met à jour "Bonjour / Bonsoir" automatiquement (vérifie chaque minute)
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Bonjour de 5h à 18h, Bonsoir de 18h à 5h
  String _greeting() {
    final h = DateTime.now().hour;
    return (h >= 18 || h < 5) ? 'Bonsoir' : 'Bonjour';
  }

  // minuscules + sans accents, pour que "marsa" trouve "La Marsa"
  String _norm(String s) {
    const from = 'àâäéèêëîïôöùûüç';
    const to = 'aaaeeeeiioouuuc';
    var r = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  void _reset() {
    _search.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _filter = 'all';
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(listingsProvider);
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(profileProvider).value;

    final fullName = (profile?.name.isNotEmpty == true)
        ? profile!.name
        : (user?.displayName ?? '');
    final first = fullName.trim().split(' ').first;

    return ColoredBox(
      color: const Color(0xFFF6F8FC),
      child: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _header(first, user != null, profile)),
            listings.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Impossible de charger les annonces.\n$e',
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
              data: (all) {
                final q = _norm(_query.trim());
                final items = all.where((l) {
                  if (_filter != 'all' && l.transaction != _filter) {
                    return false;
                  }
                  if (q.isEmpty) return true;
                  return _norm('${l.title} ${l.city} ${l.address}').contains(q);
                }).toList();

                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          all.isEmpty
                              ? 'Aucune annonce pour le moment.'
                              : 'Aucune annonce ne correspond à votre recherche.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.grey),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListingCard(listing: items[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String firstName, bool loggedIn, UserProfile? profile) {
    final user = ref.watch(authStateProvider).value;
    final greeting = _greeting();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty
                          ? '$greeting 👋'
                          : '$greeting, $firstName 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    const Text('Trouvez votre prochaine maison',
                        style: TextStyle(fontSize: 14, color: AppTheme.grey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () =>
                    loggedIn ? context.go('/profile') : context.push('/login'),
                child: UserAvatar(
                  base64: profile?.avatarBase64,
                  url: (profile?.avatarUrl.isNotEmpty == true)
                      ? profile!.avatarUrl
                      : user?.photoURL,
                  radius: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recherche
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
            ),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher une ville, un quartier...',
                hintStyle:
                    const TextStyle(fontSize: 14, color: Color(0xFF9AA3B2)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.dark),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chips Tous / Vente / Location
          Row(
            children: [
              _chip('all', 'Tous'),
              const SizedBox(width: 10),
              _chip('vente', 'Vente'),
              const SizedBox(width: 10),
              _chip('location', 'Location'),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text('Les dernières annonces',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ),
              GestureDetector(
                onTap: _reset,
                child: const Text('Voir tout',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: active
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }
}
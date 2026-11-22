import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String id;
  final String title;
  final String description;
  final String type;
  final String transaction; // vente | location
  final num price;
  final int rooms;
  final int bathrooms;
  final num surface;
  final String city;
  final String address;
  final double? lat;
  final double? lng;
  final List<String> imageUrls;
  final List<String> amenities;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final DateTime? createdAt;

  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.transaction,
    required this.price,
    required this.rooms,
    required this.bathrooms,
    required this.surface,
    required this.city,
    required this.address,
    required this.lat,
    required this.lng,
    required this.imageUrls,
    required this.amenities,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.createdAt,
  });

  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Listing(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      type: d['type'] as String? ?? 'appartement',
      transaction: d['transaction'] as String? ?? 'location',
      price: d['price'] as num? ?? 0,
      rooms: (d['rooms'] as num?)?.toInt() ?? 0,
      bathrooms: (d['bathrooms'] as num?)?.toInt() ?? 0,
      surface: d['surface'] as num? ?? 0,
      city: d['city'] as String? ?? '',
      address: d['address'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      imageUrls: List<String>.from(d['imageUrls'] as List? ?? const []),
      amenities: List<String>.from(d['amenities'] as List? ?? const []),
      ownerId: d['ownerId'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      ownerPhone: d['ownerPhone'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get hasLocation => lat != null && lng != null;

  String get priceLabel {
    final s = price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return '$s DT';
  }

  String get priceSuffix => transaction == 'location' ? 'par mois' : '';

  String get fullAddress =>
      [address, city].where((s) => s.trim().isNotEmpty).join(', ');

  String get detailsLabel =>
      '$rooms chambre${rooms > 1 ? 's' : ''}  ·  $bathrooms sdb'
      '${surface > 0 ? '  ·  $surface m²' : ''}';

  // createdAt == null : l'annonce vient d'être publiée (timestamp en attente)
  bool get isNew =>
      createdAt == null || DateTime.now().difference(createdAt!).inDays < 7;

  String get publishedAgo {
    if (createdAt == null) return "Publié à l'instant";
    final d = DateTime.now().difference(createdAt!);
    if (d.inMinutes < 1) return "Publié à l'instant";
    if (d.inMinutes < 60) return 'Publié il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'Publié il y a ${d.inHours} h';
    if (d.inDays < 7) {
      return 'Publié il y a ${d.inDays} jour${d.inDays > 1 ? 's' : ''}';
    }
    if (d.inDays < 30) {
      final w = d.inDays ~/ 7;
      return 'Publié il y a $w semaine${w > 1 ? 's' : ''}';
    }
    return 'Publié il y a ${d.inDays ~/ 30} mois';
  }
}
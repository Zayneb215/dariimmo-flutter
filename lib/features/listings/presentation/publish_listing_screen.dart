import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../map/presentation/location_picker.dart';
import '../data/amenities.dart';
import '../data/cloudinary_service.dart';

class PublishListingScreen extends StatefulWidget {
  const PublishListingScreen({super.key});

  @override
  State<PublishListingScreen> createState() => _PublishListingScreenState();
}

class _PublishListingScreenState extends State<PublishListingScreen> {
  static const _types = {
    'appartement': 'Appartement',
    'maison': 'Maison',
    'villa': 'Villa',
    'terrain': 'Terrain',
    'local': 'Local commercial',
  };

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _rooms = TextEditingController();
  final _baths = TextEditingController();
  final _surface = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  String _transaction = 'location';
  String _type = 'appartement';
  final List<XFile> _photos = [];
  final Set<String> _selected = {};
  LatLng? _location;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final d = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(uid)
          .get();
      final p = d.data()?['phone'] as String? ?? '';
      if (mounted && _phone.text.isEmpty) _phone.text = p;
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _desc,
      _price,
      _rooms,
      _baths,
      _surface,
      _city,
      _address,
      _phone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (files.isEmpty) return;
      setState(() {
        _photos.addAll(files);
        if (_photos.length > 8) _photos.removeRange(8, _photos.length);
        _error = null;
      });
    } catch (_) {
      setState(() => _error = "Impossible d'ouvrir la galerie.");
    }
  }

  num _num(TextEditingController c) =>
      num.tryParse(c.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  void _fail(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  Future<void> _submit() async {
    debugPrint('PUBLISH: bouton cliqué');

    if (!_formKey.currentState!.validate()) {
      _fail('Vérifiez les champs en rouge.');
      return;
    }
    if (_photos.isEmpty) {
      _fail('Ajoutez au moins une photo.');
      return;
    }
    if (_location == null) {
      _fail("Placez l'épingle sur la carte.");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        debugPrint('PUBLISH: upload photo ${i + 1}/${_photos.length}');
        urls.add(await CloudinaryService.upload(_photos[i]));
      }

      debugPrint('PUBLISH: écriture Firestore');
      final ref = await FirebaseFirestore.instance
          .collection('listings')
          .add({
            'title': _title.text.trim(),
            'description': _desc.text.trim(),
            'type': _type,
            'transaction': _transaction,
            'price': _num(_price),
            'rooms': _num(_rooms).toInt(),
            'bathrooms': _num(_baths).toInt(),
            'surface': _num(_surface),
            'city': _city.text.trim(),
            'address': _address.text.trim(),
            'lat': _location!.latitude,
            'lng': _location!.longitude,
            'amenities': _selected.toList(),
            'imageUrls': urls,
            'ownerId': user.uid,
            'ownerName': user.displayName ?? '',
            'ownerPhone': _phone.text.trim(),
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
      debugPrint('PUBLISH: OK id=${ref.id}');

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Annonce publiée ✅')));
      context.pop();
    } catch (e) {
      debugPrint('PUBLISH ERROR: $e');
      if (mounted) _fail('Publication impossible : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier une annonce'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Photos (1 à 8)'),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: _saving ? null : _pickPhotos,
                        child: Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppTheme.primary,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ajouter',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (var i = 0; i < _photos.length; i++)
                        Stack(
                          children: [
                            Container(
                              width: 96,
                              margin: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_photos[i].path),
                                  fit: BoxFit.cover,
                                  height: 96,
                                  width: 96,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _photos.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _label("Type d'annonce"),
                Row(
                  children: [
                    _chip('location', 'Location'),
                    const SizedBox(width: 10),
                    _chip('vente', 'Vente'),
                  ],
                ),
                const SizedBox(height: 20),

                _label('Titre'),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Appartement S+2 · La Marsa',
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Titre trop court'
                      : null,
                ),
                const SizedBox(height: 16),

                _label('Type de bien'),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: _types.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 16),

                _label(
                  _transaction == 'location'
                      ? 'Prix par mois (DT)'
                      : 'Prix (DT)',
                ),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '500'),
                  validator: (v) =>
                      (_num(_price) <= 0) ? 'Entrez un prix valide' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _small('Chambres', _rooms)),
                    const SizedBox(width: 10),
                    Expanded(child: _small('Salles de bain', _baths)),
                    const SizedBox(width: 10),
                    Expanded(child: _small('Surface m²', _surface)),
                  ],
                ),
                const SizedBox(height: 16),

                _label('Ville / région'),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'La Marsa, Tunis',
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Entrez la ville'
                      : null,
                ),
                const SizedBox(height: 16),

                _label('Adresse (optionnel)'),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    hintText: 'Rue, quartier...',
                  ),
                ),
                const SizedBox(height: 16),

                _label('Description'),
                TextFormField(
                  controller: _desc,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Décrivez le bien, les équipements...',
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Décrivez un peu plus (10 caractères minimum)'
                      : null,
                ),
                const SizedBox(height: 20),

                _label('Équipements'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: amenities
                      .map(
                        (a) => FilterChip(
                          avatar: Icon(a.icon, size: 18),
                          label: Text(a.label),
                          selected: _selected.contains(a.key),
                          selectedColor: const Color(0x1F0B3C8C),
                          checkmarkColor: AppTheme.primary,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selected.add(a.key);
                            } else {
                              _selected.remove(a.key);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                _label('Localisation sur la carte'),
                LocationPicker(
                  initial: _location,
                  onChanged: (p) => setState(() => _location = p),
                ),
                const SizedBox(height: 20),

                _label('Téléphone de contact'),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+216 20 123 456',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final t = (v ?? '').replaceAll(RegExp(r'[\s+]'), '');
                    return RegExp(r'^\d{8,12}$').hasMatch(t)
                        ? null
                        : 'Numéro invalide';
                  },
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Publication en cours...'),
                          ],
                        )
                      : const Text('Publier'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _small(String label, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '0'),
      ),
    ],
  );

  Widget _chip(String value, String label) {
    final active = _transaction == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transaction = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: active ? AppTheme.primary : const Color(0xFFE5E5E5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

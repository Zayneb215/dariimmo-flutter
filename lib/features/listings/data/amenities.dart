import 'package:flutter/material.dart';

class Amenity {
  final String key;
  final String label;
  final IconData icon;
  const Amenity(this.key, this.label, this.icon);
}

const amenities = <Amenity>[
  Amenity('chauffage', 'Chauffage', Icons.local_fire_department_outlined),
  Amenity('climatisation', 'Climatisation', Icons.ac_unit),
  Amenity('television', 'Télévision', Icons.tv),
  Amenity('machine', 'Machine à laver', Icons.local_laundry_service_outlined),
  Amenity('wifi', 'Wifi', Icons.wifi),
  Amenity('parking', 'Parking', Icons.local_parking),
  Amenity('ascenseur', 'Ascenseur', Icons.elevator_outlined),
  Amenity('meuble', 'Meublé', Icons.chair_outlined),
  Amenity('terrasse', 'Terrasse / balcon', Icons.deck_outlined),
  Amenity('jardin', 'Jardin', Icons.yard_outlined),
  Amenity('cuisine', 'Cuisine équipée', Icons.kitchen_outlined),
  Amenity('securite', 'Sécurité / gardiennage', Icons.security),
];

Amenity? amenityByKey(String key) {
  for (final a in amenities) {
    if (a.key == key) return a;
  }
  return null;
}
import '../data/health_data.dart';

class Pharmacy {
  final String name;
  final String address;
  final String phone;

  Pharmacy({
    required this.name,
    required this.address,
    required this.phone,
  });
}

class PharmacySearchService {
  static const String baseUrl = 'https://www.bdtradeinfo.com/yp-data/medicine-stores';

  Future<List<Pharmacy>> searchPharmacies({
    required String location,
    String query = 'pharmacy',
  }) async {
    // Try hardcoded data first
    final pharmacyList = HealthData.pharmacies[location];

    if (pharmacyList != null && pharmacyList.isNotEmpty) {
      print('Returning hardcoded pharmacies for $location');
      return pharmacyList.map((p) => Pharmacy(
        name: p['name']!,
        address: p['address']!,
        phone: p['phone']!,
      )).toList();
    }

    // Fallback to empty list or scraping if needed
    return [];
  }
}

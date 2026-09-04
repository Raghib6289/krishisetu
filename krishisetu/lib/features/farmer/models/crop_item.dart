class CropItem {
  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String cropName;
  final String category;
  final double quantityQuintals;
  final double pricePerKg;
  final String grade;
  final String harvestDate;
  final String location;
  final String imageUrl;
  final double mandiPriceComparison;
  final String status;

  CropItem({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.cropName,
    required this.category,
    required this.quantityQuintals,
    required this.pricePerKg,
    required this.grade,
    required this.harvestDate,
    required this.location,
    required this.imageUrl,
    required this.mandiPriceComparison,
    this.status = 'AVAILABLE',
  });

  factory CropItem.fromJson(Map<String, dynamic> json) {
    return CropItem(
      id: json['id'] ?? '',
      farmerId: json['farmer_id'] ?? '',
      farmerName: json['farmer_name'] ?? 'Local Farmer',
      farmerPhone: json['farmer_phone'] ?? '',
      cropName: json['crop_name'] ?? '',
      category: json['category'] ?? 'Vegetables',
      quantityQuintals: (json['quantity_quintals'] as num?)?.toDouble() ?? 10.0,
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 20.0,
      grade: json['grade'] ?? 'A',
      harvestDate: json['harvest_date'] ?? '2026-09-01',
      location: json['location'] ?? 'Nashik, Maharashtra',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600',
      mandiPriceComparison: (json['mandi_price_comparison'] as num?)?.toDouble() ?? 18.0,
      status: json['status'] ?? 'AVAILABLE',
    );
  }

  bool get isOutOfStock => status == 'OUT_OF_STOCK' || quantityQuintals <= 0.001;
  bool get isLowStock => !isOutOfStock && quantityQuintals <= 2.0;
  double get availableKg => quantityQuintals * 100.0;

  int get daysSinceHarvest {
    try {
      final parsed = DateTime.parse(harvestDate);
      final diff = DateTime.now().difference(parsed).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 1;
    }
  }

  String get freshnessLabel {
    final days = daysSinceHarvest;
    if (days == 0) return 'Harvested Today • Prime Fresh';
    if (days <= 2) return 'Harvested ${days}d ago • Fresh';
    if (days <= 5) return 'Harvested ${days}d ago • Good';
    return 'Harvested ${days}d ago • Sell Soon';
  }

  CropItem copyWith({
    String? id,
    String? farmerId,
    String? farmerName,
    String? farmerPhone,
    String? cropName,
    String? category,
    double? quantityQuintals,
    double? pricePerKg,
    String? grade,
    String harvestDate = '',
    String? location,
    String? imageUrl,
    double? mandiPriceComparison,
    String? status,
  }) {
    return CropItem(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      cropName: cropName ?? this.cropName,
      category: category ?? this.category,
      quantityQuintals: quantityQuintals ?? this.quantityQuintals,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      grade: grade ?? this.grade,
      harvestDate: harvestDate.isNotEmpty ? harvestDate : this.harvestDate,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      mandiPriceComparison: mandiPriceComparison ?? this.mandiPriceComparison,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'crop_name': cropName,
        'category': category,
        'quantity_quintals': quantityQuintals,
        'price_per_kg': pricePerKg,
        'grade': grade,
        'harvest_date': harvestDate,
        'location': location,
        'image_url': imageUrl,
        'mandi_price_comparison': mandiPriceComparison,
        'status': status,
      };
}


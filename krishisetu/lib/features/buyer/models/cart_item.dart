import '../../farmer/models/crop_item.dart';

class CartItemModel {
  final CropItem crop;
  int quantityKg;

  CartItemModel({
    required this.crop,
    required this.quantityKg,
  });

  double get totalPrice => crop.pricePerKg * quantityKg;

  Map<String, dynamic> toJson() => {
        'listing_id': crop.id,
        'crop_name': crop.cropName,
        'farmer_name': crop.farmerName,
        'quantity_kg': quantityKg.toDouble(),
        'price_per_kg': crop.pricePerKg,
      };
}

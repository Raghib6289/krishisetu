import 'package:flutter_test/flutter_test.dart';
import 'package:krishisetu/core/network/websocket_service.dart';
import 'package:krishisetu/features/buyer/models/cart_item.dart';
import 'package:krishisetu/features/farmer/models/crop_item.dart';

void main() {
  group('Real-Time CropItem & Inventory Tests', () {
    test('CropItem correctly identifies available, low stock, and out of stock states', () {
      final availableCrop = CropItem(
        id: 'crop_1',
        farmerId: 'usr_farmer_101',
        farmerName: 'Ramesh Patil',
        farmerPhone: '+91 98765 43210',
        cropName: 'Fresh Tomatoes',
        category: 'Vegetables',
        quantityQuintals: 25.0,
        pricePerKg: 24.0,
        grade: 'A+',
        harvestDate: '2026-09-02',
        location: 'Nashik',
        imageUrl: 'https://example.com/tomato.jpg',
        mandiPriceComparison: 20.0,
        status: 'AVAILABLE',
      );

      expect(availableCrop.isOutOfStock, false);
      expect(availableCrop.isLowStock, false);
      expect(availableCrop.availableKg, 2500.0);

      // Low stock transition (<= 2.0 quintals)
      final lowStockCrop = availableCrop.copyWith(quantityQuintals: 1.5, status: 'LOW_STOCK');
      expect(lowStockCrop.isOutOfStock, false);
      expect(lowStockCrop.isLowStock, true);
      expect(lowStockCrop.availableKg, 150.0);

      // Out of stock transition (<= 0.001 quintals or OUT_OF_STOCK status)
      final outOfStockCrop = availableCrop.copyWith(quantityQuintals: 0.0, status: 'OUT_OF_STOCK');
      expect(outOfStockCrop.isOutOfStock, true);
      expect(outOfStockCrop.availableKg, 0.0);
    });

    test('InventoryEvent parses STOCK_UPDATED and OUT_OF_STOCK payloads correctly', () {
      final jsonPayload = {
        'type': 'STOCK_UPDATED',
        'crop_id': 'crop_101',
        'crop_name': 'Hybrid Fresh Tomatoes',
        'farmer_name': 'Ramesh Patil',
        'new_quantity_quintals': 0.0,
        'status': 'OUT_OF_STOCK',
        'purchased_kg': 500.0,
        'buyer_name': 'Reliance Fresh Retail Hub',
        'is_out_of_stock': true,
        'message': 'Reliance Fresh purchased 500 kg of Tomatoes. Remaining: 0 Qtl'
      };

      final event = InventoryEvent.fromJson(jsonPayload);
      expect(event.type, 'STOCK_UPDATED');
      expect(event.cropId, 'crop_101');
      expect(event.cropName, 'Hybrid Fresh Tomatoes');
      expect(event.newQuantityQuintals, 0.0);
      expect(event.status, 'OUT_OF_STOCK');
      expect(event.isOutOfStock, true);
      expect(event.purchasedKg, 500.0);
    });

    test('CartItemModel computes total price correctly', () {
      final crop = CropItem(
        id: 'crop_2',
        farmerId: 'usr_farmer_101',
        farmerName: 'Ramesh Patil',
        farmerPhone: '+91 98765 43210',
        cropName: 'Lasalgaon Onions',
        category: 'Vegetables',
        quantityQuintals: 50.0,
        pricePerKg: 20.0,
        grade: 'A',
        harvestDate: '2026-09-01',
        location: 'Lasalgaon',
        imageUrl: 'https://example.com/onion.jpg',
        mandiPriceComparison: 18.0,
      );

      final cartItem = CartItemModel(crop: crop, quantityKg: 150);
      expect(cartItem.totalPrice, 3000.0);
      expect(cartItem.toJson()['quantity_kg'], 150.0);
    });
  });
}

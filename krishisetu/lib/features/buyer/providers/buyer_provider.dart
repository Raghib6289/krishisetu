import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/websocket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../farmer/models/crop_item.dart';
import '../models/cart_item.dart';

class BuyerState {
  final List<CropItem> catalog;
  final List<CartItemModel> cartItems;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCategory;
  final String searchQuery;
  final String? lastPlacedOrderId;
  final bool isLiveConnected;
  final String? lastLiveEventMessage;

  const BuyerState({
    this.catalog = const [],
    this.cartItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.lastPlacedOrderId,
    this.isLiveConnected = true,
    this.lastLiveEventMessage,
  });

  double get cartSubtotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get totalCartKg {
    return cartItems.fold(0, (sum, item) => sum + item.quantityKg);
  }

  // Bulk discount rule: orders >= 500 kg get 5% direct bulk subsidy
  double get bulkDiscount {
    if (totalCartKg >= 500) {
      return cartSubtotal * 0.05;
    }
    return 0.0;
  }

  double get finalTotal => cartSubtotal - bulkDiscount;

  // Check if any item in cart has been depleted by other concurrent buyers
  bool get hasOutOfStockCartItems {
    return cartItems.any((i) => i.crop.isOutOfStock || (i.crop.availableKg < i.quantityKg));
  }

  BuyerState copyWith({
    List<CropItem>? catalog,
    List<CartItemModel>? cartItems,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
    String? lastPlacedOrderId,
    bool? isLiveConnected,
    String? lastLiveEventMessage,
  }) {
    return BuyerState(
      catalog: catalog ?? this.catalog,
      cartItems: cartItems ?? this.cartItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      lastPlacedOrderId: lastPlacedOrderId ?? this.lastPlacedOrderId,
      isLiveConnected: isLiveConnected ?? this.isLiveConnected,
      lastLiveEventMessage: lastLiveEventMessage ?? this.lastLiveEventMessage,
    );
  }
}

class BuyerNotifier extends StateNotifier<BuyerState> {
  final Ref _ref;
  StreamSubscription<InventoryEvent>? _inventorySub;
  StreamSubscription<bool>? _connectionSub;

  BuyerNotifier(this._ref) : super(const BuyerState()) {
    loadCatalog();
    _subscribeToLiveInventory();
  }

  void _subscribeToLiveInventory() {
    final wsService = InventoryWebSocketService();

    _connectionSub = wsService.connectionStatusStream.listen((status) {
      state = state.copyWith(isLiveConnected: status);
    });

    _inventorySub = wsService.inventoryStream.listen((event) {
      _handleLiveInventoryEvent(event);
    });
  }

  void _handleLiveInventoryEvent(InventoryEvent event) {
    if (event.type == 'CROP_ADDED' && event.crop != null) {
      final newCrop = CropItem.fromJson(event.crop!);
      // Avoid duplicate if already in catalog
      if (!state.catalog.any((c) => c.id == newCrop.id)) {
        state = state.copyWith(
          catalog: [newCrop, ...state.catalog],
          lastLiveEventMessage: '🌱 Just Listed: ${newCrop.cropName} (${newCrop.quantityQuintals} Qtl)',
        );
      }
    } else if (event.type == 'STOCK_UPDATED' || event.type == 'RESTOCKED' || event.type == 'CROP_UPDATED') {
      final targetId = event.cropId;
      if (targetId == null) return;

      final updatedCatalog = state.catalog.map((crop) {
        if (crop.id == targetId) {
          final newQty = event.newQuantityQuintals ?? crop.quantityQuintals;
          final newStatus = event.status ?? (newQty <= 0.001 ? 'OUT_OF_STOCK' : (newQty <= 2.0 ? 'LOW_STOCK' : 'AVAILABLE'));
          return crop.copyWith(
            quantityQuintals: newQty,
            status: newStatus,
          );
        }
        return crop;
      }).toList();

      // Also update any matching items in the cart
      final updatedCart = state.cartItems.map((cartItem) {
        if (cartItem.crop.id == targetId) {
          final newQty = event.newQuantityQuintals ?? cartItem.crop.quantityQuintals;
          final newStatus = event.status ?? (newQty <= 0.001 ? 'OUT_OF_STOCK' : (newQty <= 2.0 ? 'LOW_STOCK' : 'AVAILABLE'));
          return CartItemModel(
            crop: cartItem.crop.copyWith(
              quantityQuintals: newQty,
              status: newStatus,
            ),
            quantityKg: cartItem.quantityKg,
          );
        }
        return cartItem;
      }).toList();

      state = state.copyWith(
        catalog: updatedCatalog,
        cartItems: updatedCart,
        lastLiveEventMessage: event.message,
      );
    } else if (event.type == 'CROP_DELETED') {
      final targetId = event.cropId;
      if (targetId != null) {
        state = state.copyWith(
          catalog: state.catalog.where((c) => c.id != targetId).toList(),
          cartItems: state.cartItems.where((c) => c.crop.id != targetId).toList(),
          lastLiveEventMessage: 'Produce listing #$targetId was removed.',
        );
      }
    }
  }

  Future<void> loadCatalog() async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final rawList = await apiClient.getCrops(
        category: state.selectedCategory,
        search: state.searchQuery,
      );
      final crops = rawList.map((e) => CropItem.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(catalog: crops, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setCategory(String cat) {
    state = state.copyWith(selectedCategory: cat);
    loadCatalog();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    loadCatalog();
  }

  bool addToCart(CropItem crop, {int quantityKg = 50}) {
    if (crop.isOutOfStock) return false;

    final existingIndex = state.cartItems.indexWhere((i) => i.crop.id == crop.id);
    final updatedCart = List<CartItemModel>.from(state.cartItems);

    if (existingIndex >= 0) {
      final currentTotal = updatedCart[existingIndex].quantityKg + quantityKg;
      // Cap at available stock
      if (currentTotal > crop.availableKg) {
        updatedCart[existingIndex].quantityKg = crop.availableKg.toInt();
      } else {
        updatedCart[existingIndex].quantityKg = currentTotal;
      }
    } else {
      final clampedQty = (quantityKg > crop.availableKg) ? crop.availableKg.toInt() : quantityKg;
      if (clampedQty > 0) {
        updatedCart.add(CartItemModel(crop: crop, quantityKg: clampedQty));
      }
    }

    state = state.copyWith(cartItems: updatedCart);
    return true;
  }

  void updateQuantity(String cropId, int newQuantity) {
    final updatedCart = List<CartItemModel>.from(state.cartItems);
    final index = updatedCart.indexWhere((i) => i.crop.id == cropId);
    if (index >= 0) {
      if (newQuantity <= 0) {
        updatedCart.removeAt(index);
      } else {
        final available = updatedCart[index].crop.availableKg.toInt();
        updatedCart[index].quantityKg = (newQuantity > available && available > 0) ? available : newQuantity;
      }
      state = state.copyWith(cartItems: updatedCart);
    }
  }

  void clearCart() {
    state = state.copyWith(cartItems: []);
  }

  Future<String?> checkoutOrder({
    required String deliveryAddress,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    if (state.hasOutOfStockCartItems) {
      state = state.copyWith(errorMessage: 'Please adjust or remove out-of-stock items before checkout.');
      return null;
    }

    state = state.copyWith(isLoading: true);
    try {
      final user = _ref.read(authProvider).user;
      final apiClient = _ref.read(apiClientProvider);

      final orderPayload = {
        'buyer_id': user?.id ?? 'usr_buyer_202',
        'buyer_name': user?.name ?? 'Reliance Fresh Retail Hub',
        'buyer_phone': user?.phone ?? '+91 98220 11223',
        'delivery_address': deliveryAddress,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        'items': state.cartItems.map((i) => i.toJson()).toList(),
        'payment_method': 'Razorpay Instant Settlement',
        'payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
      };

      final result = await apiClient.createOrder(orderPayload);
      final orderId = result['id'] as String? ?? 'ord_9901';

      state = state.copyWith(
        cartItems: [],
        isLoading: false,
        lastPlacedOrderId: orderId,
      );
      return orderId;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}

final buyerProvider = StateNotifierProvider<BuyerNotifier, BuyerState>((ref) {
  return BuyerNotifier(ref);
});


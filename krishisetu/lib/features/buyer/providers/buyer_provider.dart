import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const BuyerState({
    this.catalog = const [],
    this.cartItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.lastPlacedOrderId,
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

  BuyerState copyWith({
    List<CropItem>? catalog,
    List<CartItemModel>? cartItems,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
    String? lastPlacedOrderId,
  }) {
    return BuyerState(
      catalog: catalog ?? this.catalog,
      cartItems: cartItems ?? this.cartItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      lastPlacedOrderId: lastPlacedOrderId ?? this.lastPlacedOrderId,
    );
  }
}

class BuyerNotifier extends StateNotifier<BuyerState> {
  final Ref _ref;

  BuyerNotifier(this._ref) : super(const BuyerState()) {
    loadCatalog();
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

  void addToCart(CropItem crop, {int quantityKg = 50}) {
    final existingIndex = state.cartItems.indexWhere((i) => i.crop.id == crop.id);
    final updatedCart = List<CartItemModel>.from(state.cartItems);

    if (existingIndex >= 0) {
      updatedCart[existingIndex].quantityKg += quantityKg;
    } else {
      updatedCart.add(CartItemModel(crop: crop, quantityKg: quantityKg));
    }

    state = state.copyWith(cartItems: updatedCart);
  }

  void updateQuantity(String cropId, int newQuantity) {
    final updatedCart = List<CartItemModel>.from(state.cartItems);
    final index = updatedCart.indexWhere((i) => i.crop.id == cropId);
    if (index >= 0) {
      if (newQuantity <= 0) {
        updatedCart.removeAt(index);
      } else {
        updatedCart[index].quantityKg = newQuantity;
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
}

final buyerProvider = StateNotifierProvider<BuyerNotifier, BuyerState>((ref) {
  return BuyerNotifier(ref);
});

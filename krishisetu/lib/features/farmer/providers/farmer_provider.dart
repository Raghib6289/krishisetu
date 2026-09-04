import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/websocket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/crop_item.dart';

class SaleAlertModel {
  final String cropName;
  final double purchasedKg;
  final double remainingQuintals;
  final String buyerName;
  final String timestamp;
  final bool isOutOfStock;

  SaleAlertModel({
    required this.cropName,
    required this.purchasedKg,
    required this.remainingQuintals,
    required this.buyerName,
    required this.timestamp,
    this.isOutOfStock = false,
  });
}

class FarmerState {
  final List<CropItem> myCrops;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? selectedForecast;
  final bool isForecastLoading;
  final Map<String, dynamic>? analytics;
  final List<SaleAlertModel> recentSaleAlerts;
  final String activeFilter; // 'All', 'Active', 'Low Stock', 'Out of Stock'
  final bool isLiveConnected;

  const FarmerState({
    this.myCrops = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedForecast,
    this.isForecastLoading = false,
    this.analytics,
    this.recentSaleAlerts = const [],
    this.activeFilter = 'All',
    this.isLiveConnected = true,
  });

  int get activeCount => myCrops.where((c) => !c.isOutOfStock && !c.isLowStock).length;
  int get lowStockCount => myCrops.where((c) => c.isLowStock).length;
  int get outOfStockCount => myCrops.where((c) => c.isOutOfStock).length;

  double get totalValuationInr {
    return myCrops.fold(0.0, (sum, c) => sum + (c.quantityQuintals * 100.0 * c.pricePerKg));
  }

  double get directMandiSavings {
    return myCrops.fold(0.0, (sum, c) {
      final diff = c.pricePerKg - c.mandiPriceComparison;
      return sum + (diff > 0 ? diff * c.quantityQuintals * 100.0 : 0.0);
    });
  }

  List<CropItem> get filteredCrops {
    switch (activeFilter) {
      case 'Active':
        return myCrops.where((c) => !c.isOutOfStock && !c.isLowStock).toList();
      case 'Low Stock':
        return myCrops.where((c) => c.isLowStock).toList();
      case 'Out of Stock':
        return myCrops.where((c) => c.isOutOfStock).toList();
      default:
        return myCrops;
    }
  }

  FarmerState copyWith({
    List<CropItem>? myCrops,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? selectedForecast,
    bool? isForecastLoading,
    Map<String, dynamic>? analytics,
    List<SaleAlertModel>? recentSaleAlerts,
    String? activeFilter,
    bool? isLiveConnected,
  }) {
    return FarmerState(
      myCrops: myCrops ?? this.myCrops,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedForecast: selectedForecast ?? this.selectedForecast,
      isForecastLoading: isForecastLoading ?? this.isForecastLoading,
      analytics: analytics ?? this.analytics,
      recentSaleAlerts: recentSaleAlerts ?? this.recentSaleAlerts,
      activeFilter: activeFilter ?? this.activeFilter,
      isLiveConnected: isLiveConnected ?? this.isLiveConnected,
    );
  }
}

class FarmerNotifier extends StateNotifier<FarmerState> {
  final Ref _ref;
  StreamSubscription<InventoryEvent>? _inventorySub;
  StreamSubscription<bool>? _connectionSub;

  FarmerNotifier(this._ref) : super(const FarmerState()) {
    loadFarmerInventory();
    loadForecast('tomato');
    loadAnalytics();
    _subscribeToLiveInventory();
  }

  void _subscribeToLiveInventory() {
    final wsService = InventoryWebSocketService();

    _connectionSub = wsService.connectionStatusStream.listen((connected) {
      state = state.copyWith(isLiveConnected: connected);
    });

    _inventorySub = wsService.inventoryStream.listen((event) {
      _handleInventoryEvent(event);
    });
  }

  void _handleInventoryEvent(InventoryEvent event) {
    if (event.type == 'STOCK_UPDATED') {
      final targetId = event.cropId;
      if (targetId == null) return;

      // Update crop if it's in farmer's list
      final updatedList = state.myCrops.map((c) {
        if (c.id == targetId) {
          final newQty = event.newQuantityQuintals ?? c.quantityQuintals;
          final newStatus = event.status ?? (newQty <= 0.001 ? 'OUT_OF_STOCK' : (newQty <= 2.0 ? 'LOW_STOCK' : 'AVAILABLE'));
          return c.copyWith(
            quantityQuintals: newQty,
            status: newStatus,
          );
        }
        return c;
      }).toList();

      // Create live sale notification
      final newAlert = SaleAlertModel(
        cropName: event.cropName ?? 'Produce',
        purchasedKg: event.purchasedKg ?? 50.0,
        remainingQuintals: event.newQuantityQuintals ?? 0.0,
        buyerName: event.buyerName ?? 'Institutional Buyer',
        timestamp: DateTime.now().toIso8601String(),
        isOutOfStock: event.isOutOfStock,
      );

      state = state.copyWith(
        myCrops: updatedList,
        recentSaleAlerts: [newAlert, ...state.recentSaleAlerts.take(9)],
      );

      loadAnalytics();
    } else if (event.type == 'RESTOCKED' || event.type == 'CROP_UPDATED') {
      final targetId = event.cropId;
      if (targetId == null) return;

      final updatedList = state.myCrops.map((c) {
        if (c.id == targetId) {
          final newQty = event.newQuantityQuintals ?? c.quantityQuintals;
          final newStatus = event.status ?? (newQty <= 0.001 ? 'OUT_OF_STOCK' : (newQty <= 2.0 ? 'LOW_STOCK' : 'AVAILABLE'));
          return c.copyWith(
            quantityQuintals: newQty,
            status: newStatus,
          );
        }
        return c;
      }).toList();

      state = state.copyWith(myCrops: updatedList);
      loadAnalytics();
    } else if (event.type == 'CROP_ADDED' && event.crop != null) {
      final newCrop = CropItem.fromJson(event.crop!);
      final user = _ref.read(authProvider).user;
      if (user != null && newCrop.farmerId == user.id && !state.myCrops.any((c) => c.id == newCrop.id)) {
        state = state.copyWith(myCrops: [newCrop, ...state.myCrops]);
        loadAnalytics();
      }
    }
  }

  Future<void> loadFarmerInventory() async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final rawList = await apiClient.getCrops();
      final crops = rawList.map((e) => CropItem.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(myCrops: crops, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadAnalytics() async {
    try {
      final user = _ref.read(authProvider).user;
      final farmerId = user?.id ?? 'usr_farmer_101';
      final apiClient = _ref.read(apiClientProvider);
      final data = await apiClient.getFarmerAnalytics(farmerId);
      state = state.copyWith(analytics: data);
    } catch (_) {}
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void dismissAlert(int index) {
    final list = List<SaleAlertModel>.from(state.recentSaleAlerts);
    if (index < list.length) {
      list.removeAt(index);
      state = state.copyWith(recentSaleAlerts: list);
    }
  }

  Future<bool> quickRestock(String cropId, double addQuintals) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final res = await apiClient.quickStockUpdate(cropId, action: 'add', amountQuintals: addQuintals);
      final updated = CropItem.fromJson(res);

      state = state.copyWith(
        myCrops: state.myCrops.map((c) => c.id == cropId ? updated : c).toList(),
      );
      loadAnalytics();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updatePrice(String cropId, double newPricePerKg) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final res = await apiClient.updateCropListing(cropId, {'price_per_kg': newPricePerKg});
      final updated = CropItem.fromJson(res);

      state = state.copyWith(
        myCrops: state.myCrops.map((c) => c.id == cropId ? updated : c).toList(),
      );
      loadAnalytics();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleListingStatus(String cropId) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final res = await apiClient.toggleCropStatus(cropId);
      final updated = CropItem.fromJson(res);

      state = state.copyWith(
        myCrops: state.myCrops.map((c) => c.id == cropId ? updated : c).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addCropListing(CropItem newCrop) async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final result = await apiClient.addCrop(newCrop.toJson());
      final createdCrop = CropItem.fromJson(result);
      state = state.copyWith(
        myCrops: [createdCrop, ...state.myCrops],
        isLoading: false,
      );
      loadAnalytics();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> loadForecast(String cropName, {int days = 7}) async {
    state = state.copyWith(isForecastLoading: true);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final forecast = await apiClient.getForecast(cropName, days: days);
      state = state.copyWith(
        selectedForecast: forecast,
        isForecastLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isForecastLoading: false);
    }
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}

final farmerProvider = StateNotifierProvider<FarmerNotifier, FarmerState>((ref) {
  return FarmerNotifier(ref);
});


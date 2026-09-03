import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/crop_item.dart';

class FarmerState {
  final List<CropItem> myCrops;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? selectedForecast;
  final bool isForecastLoading;

  const FarmerState({
    this.myCrops = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedForecast,
    this.isForecastLoading = false,
  });

  FarmerState copyWith({
    List<CropItem>? myCrops,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? selectedForecast,
    bool? isForecastLoading,
  }) {
    return FarmerState(
      myCrops: myCrops ?? this.myCrops,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedForecast: selectedForecast ?? this.selectedForecast,
      isForecastLoading: isForecastLoading ?? this.isForecastLoading,
    );
  }
}

class FarmerNotifier extends StateNotifier<FarmerState> {
  final Ref _ref;

  FarmerNotifier(this._ref) : super(const FarmerState()) {
    loadFarmerInventory();
    loadForecast('tomato');
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
}

final farmerProvider = StateNotifierProvider<FarmerNotifier, FarmerState>((ref) {
  return FarmerNotifier(ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/delivery_task.dart';

class DriverState {
  final List<DeliveryTask> tasks;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? optimizedRoute;
  final bool isRouteOptimizing;
  final bool isStreamingGps;

  const DriverState({
    this.tasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.optimizedRoute,
    this.isRouteOptimizing = false,
    this.isStreamingGps = false,
  });

  DriverState copyWith({
    List<DeliveryTask>? tasks,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? optimizedRoute,
    bool? isRouteOptimizing,
    bool? isStreamingGps,
  }) {
    return DriverState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      optimizedRoute: optimizedRoute ?? this.optimizedRoute,
      isRouteOptimizing: isRouteOptimizing ?? this.isRouteOptimizing,
      isStreamingGps: isStreamingGps ?? this.isStreamingGps,
    );
  }
}

class DriverNotifier extends StateNotifier<DriverState> {
  final Ref _ref;

  DriverNotifier(this._ref) : super(const DriverState()) {
    loadDriverTasks();
    fetchOptimizedRoute();
  }

  Future<void> loadDriverTasks() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = _ref.read(authProvider).user;
      final apiClient = _ref.read(apiClientProvider);
      final rawTasks = await apiClient.getDriverOrders(user?.id ?? 'usr_driver_303');
      final list = rawTasks.map((e) => DeliveryTask.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(tasks: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final updated = state.tasks.map((task) {
      if (task.orderId == orderId) {
        return DeliveryTask(
          orderId: task.orderId,
          buyerName: task.buyerName,
          buyerPhone: task.buyerPhone,
          pickupAddress: task.pickupAddress,
          deliveryAddress: task.deliveryAddress,
          totalAmount: task.totalAmount,
          status: newStatus,
          totalWeightKg: task.totalWeightKg,
          scheduledTime: task.scheduledTime,
        );
      }
      return task;
    }).toList();

    state = state.copyWith(tasks: updated);
  }

  Future<void> fetchOptimizedRoute() async {
    state = state.copyWith(isRouteOptimizing: true);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final sample = await apiClient.getSampleStops();
      final payload = {
        'depot': sample['depot'],
        'stops': sample['stops'],
        'vehicle_capacity': 500,
        'num_vehicles': 1,
      };
      final result = await apiClient.optimizeRoute(payload);
      state = state.copyWith(
        optimizedRoute: result,
        isRouteOptimizing: false,
      );
    } catch (e) {
      state = state.copyWith(isRouteOptimizing: false);
    }
  }

  void setStreamingGps(bool active) {
    state = state.copyWith(isStreamingGps: active);
  }
}

final driverProvider = StateNotifierProvider<DriverNotifier, DriverState>((ref) {
  return DriverNotifier(ref);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/buyer/presentation/cart_screen.dart';
import '../../features/buyer/presentation/catalog_screen.dart';
import '../../features/buyer/presentation/live_tracking_screen.dart';
import '../../features/driver/presentation/driver_dashboard.dart';
import '../../features/driver/presentation/route_navigation_screen.dart';
import '../../features/farmer/presentation/add_crop_screen.dart';
import '../../features/farmer/presentation/farmer_dashboard.dart';
import '../../features/farmer/presentation/forecast_chart_screen.dart';

// Listenable wrapper so GoRouter responds reactively to Riverpod AuthState changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final loc = state.matchedLocation;
    final isLoggingIn = loc == '/login';

    // If user is accessing role routes on page reload/refresh without active auth in memory,
    // auto-restore appropriate demo role based on URL path so page reload remains rock-solid
    if (!authState.isAuthenticated && !isLoggingIn) {
      if (loc.startsWith('/farmer')) {
        _ref.read(authProvider.notifier).switchDemoRole(UserRole.farmer);
        return null;
      } else if (loc.startsWith('/buyer')) {
        _ref.read(authProvider.notifier).switchDemoRole(UserRole.buyer);
        return null;
      } else if (loc.startsWith('/driver')) {
        _ref.read(authProvider.notifier).switchDemoRole(UserRole.driver);
        return null;
      }
      return '/login';
    }

    // If at root '/' redirect to role dashboard if authenticated, otherwise to /login
    if (loc == '/') {
      if (authState.isAuthenticated) {
        switch (authState.role) {
          case UserRole.farmer:
            return '/farmer/dashboard';
          case UserRole.buyer:
            return '/buyer/catalog';
          case UserRole.driver:
            return '/driver/tasks';
          default:
            return '/farmer/dashboard';
        }
      }
      return '/login';
    }

    return null; // allow navigation to requested route
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Farmer Routes
      GoRoute(
        path: '/farmer/dashboard',
        builder: (context, state) => const FarmerDashboardScreen(),
      ),
      GoRoute(
        path: '/farmer/add-crop',
        builder: (context, state) => const AddCropScreen(),
      ),
      GoRoute(
        path: '/farmer/forecast',
        builder: (context, state) => const ForecastChartScreen(),
      ),

      // Buyer Routes
      GoRoute(
        path: '/buyer/catalog',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/buyer/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/buyer/order-tracking/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? 'ord_9901';
          return LiveTrackingScreen(orderId: orderId);
        },
      ),

      // Driver Routes
      GoRoute(
        path: '/driver/tasks',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/driver/route-map/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? 'ord_9901';
          return RouteNavigationScreen(orderId: orderId);
        },
      ),
    ],
  );
});

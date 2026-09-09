import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_widgets.dart';
import '../providers/driver_provider.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final driverState = ref.watch(driverProvider);
    final user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: RefreshIndicator(
              onRefresh: () => ref.read(driverProvider.notifier).loadDriverTasks(),
              color: AppTheme.primaryGreen,
              child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: KrishiHeader(
                  title: 'Logistics Driver Hub',
                  subtitle: user?.name ?? 'Santosh Shinde • Tata 407 Cargo',
                  icon: Icons.local_shipping,
                  currentRole: UserRole.driver,
                  onSwitchRole: () => showKrishiRoleSwitcher(context, ref),
                  onLogout: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistics Row
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Assigned Stops',
                              value: '4 Waypoints',
                              subtitle: 'Farms -> Vashi Terminal',
                              icon: Icons.alt_route,
                              color: AppTheme.skyBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'OR-Tools Savings',
                              value: '22% Fuel',
                              subtitle: 'Route optimized',
                              icon: Icons.eco_outlined,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AI Optimized Route Map Banner
                      InkWell(
                        onTap: () => context.push('/driver/route-map/ord_9901'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'OR-Tools Route Navigation',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Live polyline GPS guidance & telemetry streamer',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Assigned Pickups & Deliveries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Deliveries List with Prominent Action Buttons
              if (driverState.isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = driverState.tasks[index];
                        final isInTransit = task.status == 'IN_TRANSIT';
                        final isDelivered = task.status == 'DELIVERED';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${task.orderId}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? Colors.green.shade50
                                            : (isInTransit ? Colors.blue.shade50 : Colors.amber.shade50),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDelivered
                                              ? Colors.green.shade300
                                              : (isInTransit ? Colors.blue.shade300 : Colors.amber.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        task.status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDelivered
                                              ? AppTheme.primaryGreen
                                              : (isInTransit ? AppTheme.skyBlue : Colors.amber.shade900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Pickup Stop
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.circle, color: AppTheme.primaryGreen, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pickup: Farm Source Hub',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            task.pickupAddress,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: SizedBox(
                                    height: 16,
                                    child: VerticalDivider(color: Colors.grey, thickness: 1),
                                  ),
                                ),

                                // Dropoff Stop
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dropoff: ${task.buyerName}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            task.deliveryAddress,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // Prominent Action Buttons: Start Route & Complete Delivery
                                Row(
                                  children: [
                                    // Start Route Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isInTransit ? Colors.grey : AppTheme.skyBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.play_arrow, size: 18),
                                        label: const Text('Start Route', style: TextStyle(fontSize: 13)),
                                        onPressed: isInTransit || isDelivered
                                            ? null
                                            : () {
                                                ref
                                                    .read(driverProvider.notifier)
                                                    .updateOrderStatus(task.orderId, 'IN_TRANSIT');
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Route Started! GPS streaming activated.'),
                                                    backgroundColor: AppTheme.skyBlue,
                                                  ),
                                                );
                                                context.push('/driver/route-map/${task.orderId}');
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Complete Delivery Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDelivered ? Colors.grey : AppTheme.successGreen,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: const Text('Complete Delivery', style: TextStyle(fontSize: 13)),
                                        onPressed: isDelivered
                                            ? null
                                            : () {
                                                ref
                                                    .read(driverProvider.notifier)
                                                    .updateOrderStatus(task.orderId, 'DELIVERED');
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Delivery Handshake Complete! Payment escrow released.'),
                                                    backgroundColor: AppTheme.successGreen,
                                                  ),
                                                );
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: driverState.tasks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

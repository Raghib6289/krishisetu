import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_widgets.dart';
import '../providers/farmer_provider.dart';

class FarmerDashboardScreen extends ConsumerWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final farmerState = ref.watch(farmerProvider);
    final user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(farmerProvider.notifier).loadFarmerInventory(),
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: KrishiHeader(
                  title: 'Farmer Portal',
                  subtitle: user?.name ?? 'Ramesh Patil (Nashik)',
                  icon: Icons.agriculture,
                  currentRole: UserRole.farmer,
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
                      // Key Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Active Produce',
                              value: '${farmerState.myCrops.length} Crops',
                              subtitle: 'Listed directly',
                              icon: Icons.inventory_2_outlined,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Avg Middleman Cut',
                              value: '0%',
                              subtitle: '+18% profit margin',
                              icon: Icons.savings_outlined,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AI Demand Forecasting Action Card
                      InkWell(
                        onTap: () => context.push('/farmer/forecast'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF004D40), Color(0xFF00796B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.25),
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
                                  Icons.auto_graph_rounded,
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
                                      'AI Demand & Price Forecaster',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'View 7-day ARIMA price trends & optimal harvest date',
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

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Listed Inventory',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.push('/farmer/add-crop'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Produce'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Inventory List
              if (farmerState.isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ),
                  ),
                )
              else if (farmerState.myCrops.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No produce listed yet. Click + Add Produce to begin.'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final crop = farmerState.myCrops[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    crop.imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.green.shade50,
                                      child: const Icon(Icons.eco, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              crop.cropName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Grade ${crop.grade}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Stock: ${crop.quantityQuintals} Quintals',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${crop.pricePerKg.toStringAsFixed(1)} / kg',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                          Text(
                                            'Mandi: ₹${crop.mandiPriceComparison.toStringAsFixed(1)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: farmerState.myCrops.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farmer/add-crop'),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Add Crop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_widgets.dart';
import '../models/crop_item.dart';
import '../providers/farmer_provider.dart';

class FarmerDashboardScreen extends ConsumerWidget {
  const FarmerDashboardScreen({super.key});

  void _showRestockModal(BuildContext context, WidgetRef ref, CropItem crop) {
    final qtyController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restock ${crop.cropName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Current Available Stock: ${crop.quantityQuintals} Quintals (${crop.availableKg.toInt()} kg)',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Add (Quintals):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [10, 25, 50, 100].map((amt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text('+$amt Qtl'),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    onPressed: () {
                      qtyController.text = amt.toString();
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity to add (Quintals)',
                suffixText: 'Qtl',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text(
                  'Confirm Restock & Broadcast Live',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final addAmount = double.tryParse(qtyController.text.trim()) ?? 0.0;
                  if (addAmount > 0) {
                    Navigator.pop(ctx);
                    final ok = await ref.read(farmerProvider.notifier).quickRestock(crop.id, addAmount);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully restocked ${crop.cropName} with +$addAmount Quintals!'),
                          backgroundColor: AppTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPriceModal(BuildContext context, WidgetRef ref, CropItem crop) {
    final priceController = TextEditingController(text: crop.pricePerKg.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Update Price: ${crop.cropName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Text(
              'Benchmark APMC Mandi Rate: ₹${crop.mandiPriceComparison.toStringAsFixed(1)} / kg',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Direct Selling Price per kg',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Update Price & Sync with Buyers',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final newPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
                  if (newPrice > 0) {
                    Navigator.pop(ctx);
                    final ok = await ref.read(farmerProvider.notifier).updatePrice(crop.id, newPrice);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Price for ${crop.cropName} updated to ₹$newPrice/kg!'),
                          backgroundColor: AppTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final farmerState = ref.watch(farmerProvider);
    final user = authState.user;

    final filterList = ['All', 'Active', 'Low Stock', 'Out of Stock'];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(farmerProvider.notifier).loadFarmerInventory();
            await ref.read(farmerProvider.notifier).loadAnalytics();
          },
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: KrishiHeader(
                  title: 'Farmer Enterprise Portal',
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
                      // Real-time WebSocket Live Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: farmerState.isLiveConnected ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: farmerState.isLiveConnected ? Colors.green.shade300 : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: farmerState.isLiveConnected ? AppTheme.primaryGreen : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              farmerState.isLiveConnected
                                  ? 'Real-Time Inventory & Sales Broadcast Active'
                                  : 'Reconnecting to Live Market Stream...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: farmerState.isLiveConnected ? AppTheme.primaryGreen : Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Real-time Live Sale Alert Banner
                      if (farmerState.recentSaleAlerts.isNotEmpty) ...[
                        ...farmerState.recentSaleAlerts.take(2).map((alert) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: alert.isOutOfStock
                                    ? [const Color(0xFFC62828), const Color(0xFFE53935)]
                                    : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    alert.isOutOfStock ? Icons.warning_rounded : Icons.bolt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert.isOutOfStock
                                            ? '🚨 OUT OF STOCK: ${alert.cropName}'
                                            : '⚡ Live Sale: ${alert.purchasedKg.toInt()} kg sold!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Purchased by ${alert.buyerName}. Remaining: ${alert.remainingQuintals} Qtl',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],

                      // Low Stock / Out of Stock Action Banner
                      if (farmerState.outOfStockCount > 0 || farmerState.lowStockCount > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_outlined, color: Colors.orange, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${farmerState.outOfStockCount} produce depleted • ${farmerState.lowStockCount} running low on stock.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                onPressed: () {
                                  ref.read(farmerProvider.notifier).setFilter('Low Stock');
                                },
                                child: const Text('View Low Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),

                      // Key Metrics Row 1
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Inventory Valuation',
                              value: '₹${(farmerState.totalValuationInr / 1000).toStringAsFixed(1)}k',
                              subtitle: '${farmerState.myCrops.length} Produce Listed',
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Direct Mandi Gain',
                              value: '+₹${(farmerState.directMandiSavings / 1000).toStringAsFixed(1)}k',
                              subtitle: '+18% vs APMC',
                              icon: Icons.trending_up,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

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
                      const SizedBox(height: 20),

                      // Section Title & Actions
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
                      const SizedBox(height: 8),

                      // Status Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filterList.map((filter) {
                            final isSelected = farmerState.activeFilter == filter;
                            int count = farmerState.myCrops.length;
                            if (filter == 'Active') count = farmerState.activeCount;
                            if (filter == 'Low Stock') count = farmerState.lowStockCount;
                            if (filter == 'Out of Stock') count = farmerState.outOfStockCount;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text('$filter ($count)'),
                                selected: isSelected,
                                selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
                                checkmarkColor: AppTheme.primaryGreen,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.primaryGreen : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  ref.read(farmerProvider.notifier).setFilter(filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
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
              else if (farmerState.filteredCrops.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No produce in "${farmerState.activeFilter}" filter.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final crop = farmerState.filteredCrops[index];
                        final isOut = crop.isOutOfStock;
                        final isLow = crop.isLowStock;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isOut ? Colors.red.shade200 : (isLow ? Colors.orange.shade200 : Colors.grey.shade200),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        crop.imageUrl,
                                        width: 85,
                                        height: 85,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 85,
                                          height: 85,
                                          color: Colors.green.shade50,
                                          child: const Icon(Icons.eco, color: AppTheme.primaryGreen),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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
                                                  color: isOut
                                                      ? Colors.red.shade50
                                                      : (isLow ? Colors.orange.shade50 : Colors.green.shade50),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isOut
                                                      ? 'OUT OF STOCK'
                                                      : (isLow ? 'LOW STOCK' : 'AVAILABLE'),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isOut
                                                        ? Colors.red.shade700
                                                        : (isLow ? Colors.orange.shade900 : AppTheme.primaryGreen),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 3),

                                          // Freshness Tracker
                                          Row(
                                            children: [
                                              const Icon(Icons.spa_outlined, size: 13, color: AppTheme.primaryGreen),
                                              const SizedBox(width: 4),
                                              Text(
                                                crop.freshnessLabel,
                                                style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          Text(
                                            'Stock: ${crop.quantityQuintals} Qtl (${crop.availableKg.toInt()} kg)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isOut ? Colors.red.shade700 : Colors.grey.shade800,
                                            ),
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
                                const Divider(height: 18),

                                // Quick Action Buttons for Farmer
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          foregroundColor: AppTheme.primaryGreen,
                                          side: const BorderSide(color: AppTheme.primaryGreen),
                                        ),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('+10 Qtl', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final ok = await ref.read(farmerProvider.notifier).quickRestock(crop.id, 10.0);
                                          if (ok && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Added 10 Quintals to ${crop.cropName}!'),
                                                backgroundColor: AppTheme.successGreen,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          backgroundColor: Colors.teal.shade700,
                                        ),
                                        icon: const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                                        label: const Text('Restock...', style: TextStyle(fontSize: 12, color: Colors.white)),
                                        onPressed: () => _showRestockModal(context, ref, crop),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                                      tooltip: 'Update Price',
                                      onPressed: () => _showEditPriceModal(context, ref, crop),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: farmerState.filteredCrops.length,
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

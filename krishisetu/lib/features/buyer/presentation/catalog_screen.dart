import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_widgets.dart';
import '../../farmer/models/crop_item.dart';
import '../providers/buyer_provider.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  final List<String> _categories = ['All', 'Vegetables', 'Grains', 'Tubers', 'Spices'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerState = ref.watch(buyerProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1150
        ? 4
        : (screenWidth > 720 ? 3 : 2);
    final double childAspectRatio = screenWidth > 1150
        ? 0.72
        : (screenWidth > 720 ? 0.68 : 0.64);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: RefreshIndicator(
              onRefresh: () => ref.read(buyerProvider.notifier).loadCatalog(),
              color: AppTheme.primaryGreen,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: KrishiHeader(
                      title: 'Produce Marketplace',
                      subtitle: user?.name ?? 'Reliance Fresh / BigBasket Hub',
                      icon: Icons.storefront_rounded,
                  currentRole: UserRole.buyer,
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
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => ref.read(buyerProvider.notifier).setSearch(v),
                        decoration: InputDecoration(
                          hintText: 'Search farm fresh produce (Tomato, Onion, Wheat)...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(buyerProvider.notifier).setSearch('');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = buyerState.selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
                                checkmarkColor: AppTheme.primaryGreen,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.primaryGreen : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (_) => ref.read(buyerProvider.notifier).setCategory(cat),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active Orders Quick Shortcut
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: const [
                                  Icon(Icons.local_shipping, color: AppTheme.skyBlue, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Active Order: #ord_9901 (In Transit)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => context.push('/buyer/order-tracking/ord_9901'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.skyBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Live Map',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Real-Time Sync Indicator & Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Direct Farm Produce (${buyerState.catalog.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: buyerState.isLiveConnected ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: buyerState.isLiveConnected ? Colors.green.shade300 : Colors.orange.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: buyerState.isLiveConnected ? AppTheme.primaryGreen : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  buyerState.isLiveConnected ? 'Live Synced' : 'Reconnecting...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: buyerState.isLiveConnected ? AppTheme.primaryGreen : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (buyerState.lastLiveEventMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  buyerState.lastLiveEventMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Catalog GridView
              if (buyerState.isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ),
                  ),
                )
              else if (buyerState.catalog.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No produce matches your search.'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final crop = buyerState.catalog[index];
                        return _ProduceCard(crop: crop);
                      },
                      childCount: buyerState.catalog.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    ),
  ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/buyer/cart'),
        backgroundColor: AppTheme.primaryGreen,
        icon: Badge(
          isLabelVisible: buyerState.cartItems.isNotEmpty,
          label: Text('${buyerState.cartItems.length}'),
          child: const Icon(Icons.shopping_cart, color: Colors.white),
        ),
        label: Text(
          buyerState.cartItems.isEmpty
              ? 'Cart'
              : 'Cart (₹${buyerState.finalTotal.toStringAsFixed(0)})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ProduceCard extends ConsumerWidget {
  final CropItem crop;
  const _ProduceCard({required this.crop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = crop.isOutOfStock;
    final isLow = crop.isLowStock;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOut ? Colors.red.shade300 : (isLow ? Colors.orange.shade300 : Colors.grey.shade200),
          width: isOut ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Image with Grade & Stock Badge
          Stack(
            children: [
              Image.network(
                crop.imageUrl,
                height: 105,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 105,
                  color: Colors.green.shade50,
                  child: const Icon(Icons.grass, color: AppTheme.primaryGreen, size: 40),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Grade ${crop.grade}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (isOut)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))
                      ],
                    ),
                    child: const Text(
                      'OUT OF STOCK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
              else if (isLow)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ONLY ${crop.availableKg.toInt()} KG LEFT',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crop.cropName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOut ? Colors.grey.shade600 : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By ${crop.farmerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),

                // Live Stock Display
                Text(
                  isOut
                      ? 'Out of Stock'
                      : 'Stock: ${crop.quantityQuintals} Qtl (${crop.availableKg.toInt()} kg)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOut
                        ? Colors.red.shade700
                        : (isLow ? Colors.orange.shade800 : AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    Text(
                      '₹${crop.pricePerKg.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isOut ? Colors.grey.shade500 : AppTheme.primaryGreen,
                      ),
                    ),
                    const Text(' /kg', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: isOut
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.grey.shade300,
                            elevation: 0,
                          ),
                          onPressed: null,
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                          onPressed: () {
                            final added = ref.read(buyerProvider.notifier).addToCart(crop, quantityKg: 50);
                            if (added) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added 50 kg of ${crop.cropName} to cart!'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${crop.cropName} is currently out of stock!'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: const Text('Add 50 kg', style: TextStyle(fontSize: 12)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

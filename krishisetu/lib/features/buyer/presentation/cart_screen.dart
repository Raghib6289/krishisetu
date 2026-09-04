import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/buyer_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _addressController = TextEditingController(
    text: 'Reliance Fresh Distribution Center, Sector 19, Vashi, Navi Mumbai',
  );
  bool _isProcessingPayment = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _triggerRazorpayCheckout() async {
    final buyerState = ref.read(buyerProvider);
    if (buyerState.cartItems.isEmpty) return;

    setState(() => _isProcessingPayment = true);

    // Simulate Razorpay Gateway Modal Dialog
    final paymentSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.payment, color: Color(0xFF0C2340)),
            SizedBox(width: 8),
            Text('Razorpay Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Razorpay Merchant: KrishiSetu Agri Escrow'),
            const SizedBox(height: 8),
            Text(
              'Amount: ₹${buyerState.finalTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'UPI / NetBanking / Corporate Escrow Card\nDirect Farmer Settlement on Delivery Confirmation',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C2340)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Authorize & Pay'),
          ),
        ],
      ),
    );

    if (paymentSuccess == true) {
      final orderId = await ref.read(buyerProvider.notifier).checkoutOrder(
            deliveryAddress: _addressController.text.trim(),
            deliveryLat: 19.0760,
            deliveryLng: 72.9980,
          );

      setState(() => _isProcessingPayment = false);

      if (orderId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Order assigned to driver.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        // Direct to live logistics map tracking
        context.go('/buyer/order-tracking/$orderId');
      }
    } else {
      setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyerState = ref.watch(buyerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Purchase Cart'),
      ),
      body: buyerState.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is currently empty',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add produce from the catalog to initiate bulk purchase.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Browse Produce Catalog'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Out of stock warning banner
                      if (buyerState.hasOutOfStockCartItems)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Real-time update: An item in your cart is depleted or exceeds available stock! Please adjust or remove it.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Cart items list
                      ...buyerState.cartItems.map((item) {
                        final isItemOut = item.crop.isOutOfStock;
                        final exceedsAvailable = item.quantityKg > item.crop.availableKg;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: (isItemOut || exceedsAvailable) ? Colors.red.shade400 : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.crop.imageUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 60,
                                          height: 60,
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
                                          Text(
                                            item.crop.cropName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            '₹${item.crop.pricePerKg.toStringAsFixed(1)} / kg • ${item.crop.farmerName}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Subtotal: ₹${item.totalPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity Stepper
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          onPressed: () => ref
                                              .read(buyerProvider.notifier)
                                              .updateQuantity(item.crop.id, item.quantityKg - 50),
                                        ),
                                        Text(
                                          '${item.quantityKg} kg',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: (isItemOut || exceedsAvailable) ? Colors.red : Colors.black87,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: (isItemOut || item.quantityKg >= item.crop.availableKg)
                                              ? null
                                              : () => ref
                                                  .read(buyerProvider.notifier)
                                                  .updateQuantity(item.crop.id, item.quantityKg + 50),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                if (isItemOut) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '🚨 Out of Stock - sold to another buyer in real time',
                                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ] else if (exceedsAvailable) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '⚠️ Only ${item.crop.availableKg.toInt()} kg left in stock',
                                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),
                      // Delivery Location Input
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.local_shipping_outlined, color: AppTheme.primaryGreen, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delivery Destination Hub',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Enter complete warehouse / market address',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Order Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              title: 'Total Weight',
                              value: '${buyerState.totalCartKg} kg',
                            ),
                            const SizedBox(height: 8),
                            _SummaryRow(
                              title: 'Produce Subtotal',
                              value: '₹${buyerState.cartSubtotal.toStringAsFixed(2)}',
                            ),
                            if (buyerState.bulkDiscount > 0) ...[
                              const SizedBox(height: 8),
                              _SummaryRow(
                                title: 'Direct Bulk Subsidy (5%)',
                                value: '- ₹${buyerState.bulkDiscount.toStringAsFixed(2)}',
                                isGreen: true,
                              ),
                            ],
                            const Divider(height: 20),
                            _SummaryRow(
                              title: 'Estimated Total Payable',
                              value: '₹${buyerState.finalTotal.toStringAsFixed(2)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Checkout Button Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C2340), // Razorpay dark navy
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: (_isProcessingPayment || buyerState.hasOutOfStockCartItems)
                            ? null
                            : _triggerRazorpayCheckout,
                        child: _isProcessingPayment
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : buyerState.hasOutOfStockCartItems
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Resolve Stock Issues to Pay',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pay ₹${buyerState.finalTotal.toStringAsFixed(0)} via Razorpay',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isBold;
  final bool isGreen;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isBold = false,
    this.isGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isGreen ? AppTheme.primaryGreen : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isGreen
                ? AppTheme.primaryGreen
                : (isBold ? AppTheme.primaryGreen : Colors.black87),
          ),
        ),
      ],
    );
  }
}

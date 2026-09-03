class DeliveryTask {
  final String orderId;
  final String buyerName;
  final String buyerPhone;
  final String pickupAddress;
  final String deliveryAddress;
  final double totalAmount;
  final String status;
  final int totalWeightKg;
  final String scheduledTime;

  DeliveryTask({
    required this.orderId,
    required this.buyerName,
    required this.buyerPhone,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.totalAmount,
    required this.status,
    required this.totalWeightKg,
    required this.scheduledTime,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      orderId: json['id'] ?? 'ord_9901',
      buyerName: json['buyer_name'] ?? 'Reliance Fresh Hub',
      buyerPhone: json['buyer_phone'] ?? '+91 98220 11223',
      pickupAddress: json['pickup_address'] ?? 'Dindori Farm Cluster, Nashik',
      deliveryAddress: json['delivery_address'] ?? 'Vashi Sector 19, Navi Mumbai',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 38400.0,
      status: json['status'] ?? 'ASSIGNED',
      totalWeightKg: json['total_weight_kg'] ?? 1600,
      scheduledTime: json['created_at'] ?? 'Today 08:30 AM',
    );
  }
}

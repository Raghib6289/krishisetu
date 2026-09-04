import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class TelemetryData {
  final String orderId;
  final String driverId;
  final String driverName;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double headingDeg;
  final String timestamp;
  final String status;

  TelemetryData({
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.headingDeg,
    required this.timestamp,
    required this.status,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    return TelemetryData(
      orderId: json['order_id'] ?? '',
      driverId: json['driver_id'] ?? '',
      driverName: json['driver_name'] ?? 'Driver',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 19.9975,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 73.7898,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 40.0,
      headingDeg: (json['heading_deg'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      status: json['status'] ?? 'IN_TRANSIT',
    );
  }

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'driver_id': driverId,
        'driver_name': driverName,
        'latitude': latitude,
        'longitude': longitude,
        'speed_kmh': speedKmh,
        'heading_deg': headingDeg,
        'timestamp': timestamp,
        'status': status,
      };
}

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _simulationTimer;

  final _telemetryController = StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Connect to live tracking channel for a specific order
  void connectToOrder(String orderId) {
    disconnect();
    final wsEndpoint = '${ApiClient.wsUrl}/ws/tracking/$orderId';
    debugPrint('[WebSocket] Connecting to $wsEndpoint');

    try {
      final uri = Uri.parse(wsEndpoint);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel?.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final telemetry = TelemetryData.fromJson(parsed);
            _telemetryController.add(telemetry);
          } catch (e) {
            debugPrint('[WebSocket] Error parsing telemetry: $e');
          }
        },
        onError: (error) {
          debugPrint('[WebSocket] Channel error: $error. Starting simulation.');
          _isConnected = false;
          _startSimulationFallback(orderId);
        },
        onDone: () {
          debugPrint('[WebSocket] Channel closed.');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e. Starting simulation.');
      _isConnected = false;
      _startSimulationFallback(orderId);
    }
  }

  // Stream driver GPS update to the server
  void sendTelemetry(TelemetryData telemetry) {
    if (_channel != null && _isConnected) {
      try {
        final payload = jsonEncode(telemetry.toJson());
        _channel?.sink.add(payload);
        // Also emit locally for immediate UI reactivity
        _telemetryController.add(telemetry);
      } catch (e) {
        debugPrint('[WebSocket] Error sending telemetry: $e');
      }
    } else {
      // Offline fallback: emit locally
      _telemetryController.add(telemetry);
    }
  }

  // Smooth realistic simulation along Nashik -> Mumbai agricultural highway corridor
  void _startSimulationFallback(String orderId) {
    _simulationTimer?.cancel();

    // Key waypoints between farm cluster and buyer terminal
    final waypoints = [
      [20.1738, 73.8344], // Dindori Tomato Farm
      [20.0931, 73.9189], // Ozar Potato Hub
      [19.9975, 73.7898], // Nashik Cold Chain
      [19.6950, 73.5350], // Igatpuri Ghats
      [19.2967, 73.0631], // Bhiwandi Logistics
      [19.0760, 72.9980], // Vashi Terminal
    ];

    int currentWaypoint = 0;
    double progress = 0.0;

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (currentWaypoint >= waypoints.length - 1) {
        currentWaypoint = 0;
        progress = 0.0;
      }

      final start = waypoints[currentWaypoint];
      final end = waypoints[currentWaypoint + 1];

      progress += 0.08;
      if (progress >= 1.0) {
        progress = 0.0;
        currentWaypoint++;
      }

      if (currentWaypoint < waypoints.length - 1) {
        final curLat = start[0] + (end[0] - start[0]) * progress;
        final curLng = start[1] + (end[1] - start[1]) * progress;

        final mockTelemetry = TelemetryData(
          orderId: orderId,
          driverId: 'usr_driver_303',
          driverName: 'Santosh Shinde',
          latitude: curLat,
          longitude: curLng,
          speedKmh: 48.0,
          headingDeg: 195.0,
          timestamp: DateTime.now().toIso8601String(),
          status: 'IN_TRANSIT',
        );
        _telemetryController.add(mockTelemetry);
      }
    });
  }

  void disconnect() {
    _simulationTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
  }
}

class InventoryEvent {
  final String type; // CROP_ADDED, STOCK_UPDATED, RESTOCKED, CROP_UPDATED, CROP_DELETED
  final Map<String, dynamic>? crop;
  final String? cropId;
  final String? cropName;
  final String? farmerName;
  final double? newQuantityQuintals;
  final String? status;
  final double? purchasedKg;
  final String? buyerName;
  final String? orderId;
  final bool isOutOfStock;
  final String message;
  final String timestamp;

  InventoryEvent({
    required this.type,
    this.crop,
    this.cropId,
    this.cropName,
    this.farmerName,
    this.newQuantityQuintals,
    this.status,
    this.purchasedKg,
    this.buyerName,
    this.orderId,
    this.isOutOfStock = false,
    required this.message,
    required this.timestamp,
  });

  factory InventoryEvent.fromJson(Map<String, dynamic> json) {
    return InventoryEvent(
      type: json['type'] ?? '',
      crop: json['crop'] as Map<String, dynamic>?,
      cropId: json['crop_id'] ?? (json['crop'] != null ? json['crop']['id'] : null),
      cropName: json['crop_name'] ?? (json['crop'] != null ? json['crop']['crop_name'] : null),
      farmerName: json['farmer_name'] ?? (json['crop'] != null ? json['crop']['farmer_name'] : null),
      newQuantityQuintals: (json['new_quantity_quintals'] as num?)?.toDouble() ??
          (json['crop'] != null ? (json['crop']['quantity_quintals'] as num?)?.toDouble() : null),
      status: json['status'] ?? (json['crop'] != null ? json['crop']['status'] : null),
      purchasedKg: (json['purchased_kg'] as num?)?.toDouble(),
      buyerName: json['buyer_name'],
      orderId: json['order_id'],
      isOutOfStock: json['is_out_of_stock'] == true || (json['status'] == 'OUT_OF_STOCK'),
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class InventoryWebSocketService {
  static final InventoryWebSocketService _instance = InventoryWebSocketService._internal();
  factory InventoryWebSocketService() => _instance;

  InventoryWebSocketService._internal() {
    connect();
  }

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  final _inventoryController = StreamController<InventoryEvent>.broadcast();
  Stream<InventoryEvent> get inventoryStream => _inventoryController.stream;

  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isConnected && _channel != null) return;

    final wsEndpoint = '${ApiClient.wsUrl}/ws/inventory';
    debugPrint('[InventoryWebSocket] Connecting to $wsEndpoint');

    try {
      final uri = Uri.parse(wsEndpoint);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _connectionStatusController.add(true);

      _subscription = _channel?.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final event = InventoryEvent.fromJson(parsed);
            _inventoryController.add(event);
          } catch (e) {
            debugPrint('[InventoryWebSocket] Error parsing event: $e');
          }
        },
        onError: (error) {
          debugPrint('[InventoryWebSocket] Channel error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[InventoryWebSocket] Channel closed.');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[InventoryWebSocket] Connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    // Auto reconnect after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void broadcastLocalEvent(InventoryEvent event) {
    // Allows local emission if operating in offline mode
    _inventoryController.add(event);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStatusController.add(false);
  }
}


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String orderId;

  const LiveTrackingScreen({super.key, required this.orderId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  late final WebSocketService _wsService;
  StreamSubscription<TelemetryData>? _telemetrySub;

  LatLng _currentLocation = const LatLng(19.9975, 73.7898); // Nashik Hub default
  double _speedKmh = 45.0;
  String _driverName = 'Santosh Shinde';
  String _orderStatus = 'IN_TRANSIT';
  bool _isConnected = false;

  final List<LatLng> _routeTrace = [
    const LatLng(20.1738, 73.8344), // Farm 1
    const LatLng(20.0931, 73.9189), // Farm 2
    const LatLng(19.9975, 73.7898), // Hub
    const LatLng(19.6950, 73.5350), // Ghats
    const LatLng(19.2967, 73.0631), // Bhiwandi
    const LatLng(19.0760, 72.9980), // Vashi Dropoff
  ];

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _wsService.connectToOrder(widget.orderId);

    _telemetrySub = _wsService.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(data.latitude, data.longitude);
          _speedKmh = data.speedKmh;
          _driverName = data.driverName;
          _orderStatus = data.status;
          _isConnected = true;
        });
        // Smoothly center map around moving delivery vehicle
        try {
          _mapController.move(_currentLocation, 11.0);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Logistics: #${widget.orderId}'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green.shade700 : Colors.amber.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'WS LIVE' : 'SYNCING',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 10.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.krishisetu.app',
              ),
              // Planned Route Polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeTrace,
                    strokeWidth: 4.5,
                    color: AppTheme.skyBlue.withOpacity(0.8),
                  ),
                ],
              ),
              // Fixed Waypoint Markers (Farm Pickup & Buyer Dropoff)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _routeTrace.first,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.agriculture, color: AppTheme.primaryGreen, size: 30),
                  ),
                  Marker(
                    point: _routeTrace.last,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                  ),
                  // Real-time Moving Vehicle Marker (Updated continuously via WebSocket)
                  Marker(
                    point: _currentLocation,
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen.withOpacity(0.25),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Floating Status Pill
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.speed, color: AppTheme.skyBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Status: ${_orderStatus.replaceAll('_', ' ')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'GPS Coordinates: ${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_speedKmh.toStringAsFixed(0)} km/h',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  )
                ],
              ),
            ),
          ),

          // Bottom Driver Details Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
                        child: const Icon(Icons.person, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Text(
                              'Tata 407 Agri Cargo • MH-15-EG-4421',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: AppTheme.primaryGreen,
                        ),
                        icon: const Icon(Icons.phone),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Driver Santosh Shinde (+91 94231 88776)...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StepMilestone(title: 'Farm Pickup', isCompleted: true),
                      const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      _StepMilestone(title: 'Corridor Transit', isCompleted: true),
                      const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      _StepMilestone(title: 'Buyer Terminal', isCompleted: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepMilestone extends StatelessWidget {
  final String title;
  final bool isCompleted;

  const _StepMilestone({required this.title, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isCompleted ? AppTheme.primaryGreen : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
            color: isCompleted ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

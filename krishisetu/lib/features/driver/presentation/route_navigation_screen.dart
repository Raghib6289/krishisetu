import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/driver_provider.dart';

class RouteNavigationScreen extends ConsumerStatefulWidget {
  final String orderId;

  const RouteNavigationScreen({super.key, required this.orderId});

  @override
  ConsumerState<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends ConsumerState<RouteNavigationScreen> {
  final MapController _mapController = MapController();
  late final WebSocketService _wsService;
  Timer? _gpsStreamerTimer;
  bool _isLiveStreaming = false;

  int _currentStepIndex = 0;
  double _currentLat = 19.9975;
  double _currentLng = 73.7898;
  double _currentSpeed = 46.0;

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _wsService.connectToOrder(widget.orderId);
  }

  @override
  void dispose() {
    _gpsStreamerTimer?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  void _toggleGpsStreaming(List<LatLng> polylinePoints) {
    if (_isLiveStreaming) {
      _gpsStreamerTimer?.cancel();
      setState(() => _isLiveStreaming = false);
      ref.read(driverProvider.notifier).setStreamingGps(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS Telemetry streaming paused.')),
      );
    } else {
      setState(() => _isLiveStreaming = true);
      ref.read(driverProvider.notifier).setStreamingGps(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live GPS Telemetry streaming active via WebSocket!'),
          backgroundColor: AppTheme.skyBlue,
        ),
      );

      // Stream continuous GPS coordinate telemetry along the polyline path
      _gpsStreamerTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (polylinePoints.isEmpty) return;

        if (_currentStepIndex >= polylinePoints.length) {
          _currentStepIndex = 0;
        }

        final target = polylinePoints[_currentStepIndex];
        _currentLat = target.latitude;
        _currentLng = target.longitude;
        _currentStepIndex++;

        final telemetry = TelemetryData(
          orderId: widget.orderId,
          driverId: 'usr_driver_303',
          driverName: 'Santosh Shinde',
          latitude: _currentLat,
          longitude: _currentLng,
          speedKmh: _currentSpeed + (_currentStepIndex % 3 == 0 ? 4.0 : -2.0),
          headingDeg: 195.0,
          timestamp: DateTime.now().toIso8601String(),
          status: 'IN_TRANSIT',
        );

        // Stream coordinate to Python WebSocket server
        _wsService.sendTelemetry(telemetry);

        if (mounted) {
          setState(() {});
          try {
            _mapController.move(LatLng(_currentLat, _currentLng), 11.5);
          } catch (_) {}
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final routeData = driverState.optimizedRoute;

    // Parse polyline from OR-Tools response
    final List<LatLng> polylinePoints = [];
    final List<dynamic> rawPoly =
        routeData?['routes']?[0]?['polyline_coordinates'] as List<dynamic>? ?? [];

    for (final pt in rawPoly) {
      if (pt is List && pt.length >= 2) {
        polylinePoints.add(LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
      }
    }

    if (polylinePoints.isEmpty) {
      polylinePoints.addAll([
        const LatLng(19.9975, 73.7898),
        const LatLng(20.1738, 73.8344),
        const LatLng(20.0931, 73.9189),
        const LatLng(19.0760, 72.9980),
      ]);
    }

    final stopsSequence =
        routeData?['routes']?[0]?['stops_sequence'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('OR-Tools Optimal Route'),
        actions: [
          IconButton(
            icon: Icon(
              _isLiveStreaming ? Icons.cell_tower : Icons.cell_tower_outlined,
              color: _isLiveStreaming ? Colors.amber : Colors.white,
            ),
            onPressed: () => _toggleGpsStreaming(polylinePoints),
          )
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: polylinePoints.first,
              initialZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.krishisetu.app',
              ),
              // Render OR-Tools Polyline Path
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.0,
                    color: AppTheme.skyBlue,
                  ),
                ],
              ),
              // Waypoint Numbered Markers in Optimal Sequence
              MarkerLayer(
                markers: [
                  for (int i = 0; i < stopsSequence.length; i++)
                    Marker(
                      point: LatLng(
                        (stopsSequence[i]['latitude'] as num).toDouble(),
                        (stopsSequence[i]['longitude'] as num).toDouble(),
                      ),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == 0
                              ? Colors.grey.shade800
                              : (i == stopsSequence.length - 1
                                  ? Colors.red.shade700
                                  : AppTheme.primaryGreen),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Current Moving Truck Marker
                  Marker(
                    point: LatLng(_currentLat, _currentLng),
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.local_shipping, color: Colors.black87, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top OR-Tools Optimization Metrics Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.alt_route, color: AppTheme.skyBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Google OR-Tools VRP Solved',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '22% Fuel Saved',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Total Distance',
                        val: '${routeData?['total_distance_km'] ?? 198.5} km',
                      ),
                      _StatItem(
                        label: 'Est. Transit Time',
                        val: '${routeData?['total_time_mins'] ?? 295} mins',
                      ),
                      _StatItem(
                        label: 'Optimal Stops',
                        val: '${stopsSequence.isNotEmpty ? stopsSequence.length : 4}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Floating GPS Telemetry Broadcast Trigger
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLiveStreaming ? Colors.red.shade700 : AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(
                _isLiveStreaming ? Icons.stop : Icons.sensors,
                color: Colors.white,
              ),
              label: Text(
                _isLiveStreaming
                    ? 'Broadcasting Telemetry via WebSocket (Tap to Stop)'
                    : 'Transmit Live GPS Coordinates to Buyer (WebSocket)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () => _toggleGpsStreaming(polylinePoints),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String val;

  const _StatItem({required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

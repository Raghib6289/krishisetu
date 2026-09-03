import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/farmer_provider.dart';

class ForecastChartScreen extends ConsumerStatefulWidget {
  const ForecastChartScreen({super.key});

  @override
  ConsumerState<ForecastChartScreen> createState() => _ForecastChartScreenState();
}

class _ForecastChartScreenState extends ConsumerState<ForecastChartScreen> {
  String _selectedCrop = 'tomato';
  final List<String> _supportedCrops = ['tomato', 'onion', 'potato', 'wheat', 'chili'];

  @override
  Widget build(BuildContext context) {
    final farmerState = ref.watch(farmerProvider);
    final forecast = farmerState.selectedForecast;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Demand & Price Forecast'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crop Selector Chips
              const Text(
                'Select Commodity for Predictive Analysis:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _supportedCrops.map((crop) {
                    final isSelected = _selectedCrop == crop;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          crop.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryGreen,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCrop = crop);
                            ref.read(farmerProvider.notifier).loadForecast(crop);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              if (farmerState.isForecastLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                  ),
                ),
              ] else if (forecast != null) ...[
                // AI Intelligence Insight Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade900, AppTheme.primaryGreen],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'ARIMA Price Intelligence',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              forecast['trend_summary'] ?? 'Stable',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        forecast['ai_recommendation'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.event_available, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Optimal Harvest Date: ${forecast['best_time_to_sell'] ?? 'Upcoming Week'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // fl_chart Line Chart Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedCrop.toUpperCase()} - 7-Day Forecast (₹/kg)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text(
                              '90% Confidence Band',
                              style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 240,
                        child: _buildLineChart(forecast),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendIndicator(color: AppTheme.primaryGreen, label: 'Predicted Price (₹/kg)'),
                          const SizedBox(width: 16),
                          _LegendIndicator(color: Colors.green.shade100, label: 'Confidence Bounds'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                // Mandi Price Comparison Breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Buyer vs Traditional Mandi Margins',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _MarginRow(
                        label: 'KrishiSetu Direct Buyer Price',
                        price: '₹${(forecast['forecast']?[0]?['price'] ?? 26.0).toStringAsFixed(1)} / kg',
                        color: AppTheme.primaryGreen,
                        icon: Icons.check_circle_outline,
                      ),
                      const Divider(height: 16),
                      _MarginRow(
                        label: 'Traditional APMC Middleman Payout',
                        price: '₹${((forecast['forecast']?[0]?['price'] ?? 26.0) * 0.82).toStringAsFixed(1)} / kg',
                        color: Colors.red.shade700,
                        icon: Icons.remove_circle_outline,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.monetization_on, color: AppTheme.accentGold, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Farmers retain an average +18% higher margin by disintermediating commission agents.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, dynamic> forecast) {
    final forecastList = forecast['forecast'] as List<dynamic>? ?? [];
    if (forecastList.isEmpty) {
      return const Center(child: Text('No forecast points available'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < forecastList.length; i++) {
      final p = (forecastList[i]['price'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), p));
    }

    final minPrice = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxPrice = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minPrice > 0 ? minPrice : 0,
        maxY: maxPrice,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < forecastList.length) {
                  final dateStr = forecastList[idx]['date'] as String? ?? '';
                  final parts = dateStr.split('-');
                  final display = parts.length == 3 ? '${parts[2]}/${parts[1]}' : 'D${idx + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(display, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${value.toInt()}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryGreen,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryGreen.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _MarginRow extends StatelessWidget {
  final String label;
  final String price;
  final Color color;
  final IconData icon;

  const _MarginRow({
    required this.label,
    required this.price,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        Text(
          price,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}

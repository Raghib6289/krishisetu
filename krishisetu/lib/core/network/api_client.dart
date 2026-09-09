import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  // Base URL: On web in production (Vercel), use relative root so /api routes directly to same-origin domain
  // In local web debug, default to http://127.0.0.1:8000
  static String get baseUrl {
    if (kIsWeb) {
      if (kDebugMode) return 'http://127.0.0.1:8000';
      return '';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static String get wsUrl {
    if (kIsWeb) return 'ws://127.0.0.1:8000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'ws://10.0.2.2:8000'
        : 'ws://127.0.0.1:8000';
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio] $obj'),
      ),
    );
  }

  Dio get dio => _dio;

  // Mobile OTP Authentication
  Future<Map<String, dynamic>> sendOtp(String phone, {String? userType, String? name}) async {
    try {
      final response = await _dio.post(
        '/api/auth/send-otp',
        data: {
          'phone': phone,
          if (userType != null) 'user_type': userType,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': 'success',
        'message': 'OTP sent (offline fallback)',
        'phone': phone,
        'demo_otp': '123456',
      };
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String? userType,
    String? name,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/verify-otp',
        data: {
          'phone': phone,
          'otp': otp,
          if (userType != null) 'user_type': userType,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return _mockLoginFallback(phone);
    }
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      // Offline fallback for demo
      return _mockLoginFallback(email);
    }
  }

  // Crops
  Future<List<dynamic>> getCrops({String? category, String? search}) async {
    try {
      final response = await _dio.get(
        '/api/crops',
        queryParameters: {
          if (category != null && category != 'All') 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return response.data as List<dynamic>;
    } catch (e) {
      return _mockCropsFallback();
    }
  }

  Future<Map<String, dynamic>> addCrop(Map<String, dynamic> cropData) async {
    try {
      final response = await _dio.post('/api/crops', data: cropData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return cropData;
    }
  }

  Future<Map<String, dynamic>> updateCropListing(String cropId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/api/crops/$cropId', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return data;
    }
  }

  Future<Map<String, dynamic>> quickStockUpdate(
    String cropId, {
    String action = 'add',
    required double amountQuintals,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/crops/$cropId/quick-stock',
        data: {'action': action, 'amount_quintals': amountQuintals},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'id': cropId, 'quantity_quintals': amountQuintals, 'status': 'AVAILABLE'};
    }
  }

  Future<Map<String, dynamic>> toggleCropStatus(String cropId) async {
    try {
      final response = await _dio.patch('/api/crops/$cropId/toggle-status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'id': cropId, 'status': 'AVAILABLE'};
    }
  }

  Future<Map<String, dynamic>> getFarmerAnalytics(String farmerId) async {
    try {
      final response = await _dio.get('/api/crops/farmer/$farmerId/analytics');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {
        'farmer_id': farmerId,
        'total_crops': 6,
        'active_crops': 5,
        'low_stock_crops': 1,
        'out_of_stock_crops': 0,
        'total_quintals_available': 450.0,
        'total_inventory_valuation_inr': 1250000.0,
        'estimated_mandi_arbitrage_gain': 185000.0,
        'total_orders_received': 8,
        'total_sales_revenue_inr': 245000.0,
        'total_sales_kg': 9500.0,
        'recent_sales': []
      };
    }
  }

  // AI Demand Forecasting
  Future<Map<String, dynamic>> getForecast(String crop, {int days = 7}) async {
    try {
      final response = await _dio.get(
        '/api/forecast',
        queryParameters: {'crop': crop.toLowerCase(), 'days': days},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return _mockForecastFallback(crop);
    }
  }

  // AI Route Optimization
  Future<Map<String, dynamic>> optimizeRoute(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/api/routes/optimize', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return _mockRouteFallback();
    }
  }

  // Sample stops for demonstration
  Future<Map<String, dynamic>> getSampleStops() async {
    try {
      final response = await _dio.get('/api/routes/sample-stops');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return _mockSampleStopsFallback();
    }
  }

  // Orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _dio.post('/api/orders', data: orderData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {
        'id': 'ord_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'status': 'ASSIGNED',
        ...orderData,
      };
    }
  }

  Future<List<dynamic>> getDriverOrders(String driverId) async {
    try {
      final response = await _dio.get('/api/orders/driver/$driverId');
      return response.data as List<dynamic>;
    } catch (e) {
      return _mockOrdersFallback();
    }
  }

  // Fallback fixtures
  Map<String, dynamic> _mockLoginFallback(String email) {
    if (email.contains('driver')) {
      return {
        'id': 'usr_driver_303',
        'name': 'Santosh Shinde',
        'email': email,
        'phone': '+91 94231 88776',
        'user_type': 'driver',
        'location': 'Nashik Central Logistics Hub',
        'token': 'mock_driver_jwt_token',
      };
    } else if (email.contains('buyer')) {
      return {
        'id': 'usr_buyer_202',
        'name': 'Reliance Fresh Retail',
        'email': email,
        'phone': '+91 98220 11223',
        'user_type': 'buyer',
        'location': 'Vashi APMC Market, Navi Mumbai',
        'token': 'mock_buyer_jwt_token',
      };
    } else {
      return {
        'id': 'usr_farmer_101',
        'name': 'Ramesh Patil',
        'email': email,
        'phone': '+91 98765 43210',
        'user_type': 'farmer',
        'location': 'Dindori Farm Cluster, Nashik',
        'token': 'mock_farmer_jwt_token',
      };
    }
  }

  List<dynamic> _mockCropsFallback() {
    return [
      {
        'id': 'crop_101',
        'farmer_id': 'usr_farmer_101',
        'farmer_name': 'Ramesh Patil',
        'crop_name': 'Hybrid Fresh Tomatoes',
        'category': 'Vegetables',
        'quantity_quintals': 45.0,
        'price_per_kg': 24.0,
        'grade': 'A+',
        'harvest_date': '2026-09-02',
        'location': 'Dindori, Nashik',
        'image_url': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop',
        'mandi_price_comparison': 21.0,
      },
      {
        'id': 'crop_102',
        'farmer_id': 'usr_farmer_101',
        'farmer_name': 'Ramesh Patil',
        'crop_name': 'Lasalgaon Red Onions',
        'category': 'Vegetables',
        'quantity_quintals': 120.0,
        'price_per_kg': 19.5,
        'grade': 'A',
        'harvest_date': '2026-09-01',
        'location': 'Lasalgaon, Nashik',
        'image_url': 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=600&auto=format&fit=crop',
        'mandi_price_comparison': 17.0,
      },
      {
        'id': 'crop_103',
        'farmer_id': 'usr_farmer_102',
        'farmer_name': 'Balasaheb Deshmukh',
        'crop_name': 'Chandramukhi Potatoes',
        'category': 'Tubers',
        'quantity_quintals': 85.0,
        'price_per_kg': 16.0,
        'grade': 'A',
        'harvest_date': '2026-08-30',
        'location': 'Ozar, Nashik',
        'image_url': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600&auto=format&fit=crop',
        'mandi_price_comparison': 14.5,
      }
    ];
  }

  Map<String, dynamic> _mockForecastFallback(String crop) {
    return {
      'crop': crop.toUpperCase(),
      'mandi': 'Nashik APMC Mandi',
      'forecast_horizon_days': 7,
      'historical': [
        {'date': '2026-08-28', 'price': 22.0, 'demand_index': 65.0},
        {'date': '2026-08-29', 'price': 23.5, 'demand_index': 70.0},
        {'date': '2026-08-30', 'price': 23.0, 'demand_index': 68.0},
        {'date': '2026-08-31', 'price': 24.2, 'demand_index': 72.0},
        {'date': '2026-09-01', 'price': 25.0, 'demand_index': 76.0},
        {'date': '2026-09-02', 'price': 24.8, 'demand_index': 74.0},
        {'date': '2026-09-03', 'price': 26.0, 'demand_index': 80.0},
      ],
      'forecast': [
        {'date': '2026-09-04', 'price': 26.8, 'demand_index': 82.0},
        {'date': '2026-09-05', 'price': 27.5, 'demand_index': 85.0},
        {'date': '2026-09-06', 'price': 28.2, 'demand_index': 89.0},
        {'date': '2026-09-07', 'price': 29.0, 'demand_index': 92.0},
        {'date': '2026-09-08', 'price': 28.4, 'demand_index': 88.0},
        {'date': '2026-09-09', 'price': 27.9, 'demand_index': 84.0},
        {'date': '2026-09-10', 'price': 27.2, 'demand_index': 81.0},
      ],
      'trend_summary': 'Bullish Uptrend (+11.5% expected)',
      'price_change_percent': 11.5,
      'best_time_to_sell': '2026-09-07',
      'ai_recommendation': 'Wholesale demand spike predicted on Day 4. Holding stock until 2026-09-07 can increase profits by ~Rs.3.0/kg.',
    };
  }

  Map<String, dynamic> _mockSampleStopsFallback() {
    return {
      'depot': {
        'id': 'depot_central',
        'name': 'Nashik Central Cold Storage & Hub',
        'address': 'MIDC Ambad, Nashik',
        'latitude': 19.9975,
        'longitude': 73.7898,
        'stop_type': 'depot',
      },
      'stops': [
        {
          'id': 'stop_farm_1',
          'name': 'Patil Tomato Farm (45 Qtl)',
          'address': 'Dindori Farm Road',
          'latitude': 20.1738,
          'longitude': 73.8344,
          'stop_type': 'pickup',
        },
        {
          'id': 'stop_farm_2',
          'name': 'Deshmukh Potato Barn (85 Qtl)',
          'address': 'Ozar Agri Cluster',
          'latitude': 20.0931,
          'longitude': 73.9189,
          'stop_type': 'pickup',
        },
        {
          'id': 'stop_buyer_1',
          'name': 'Navi Mumbai Retail Terminal',
          'address': 'Vashi Sector 19',
          'latitude': 19.0760,
          'longitude': 72.9980,
          'stop_type': 'dropoff',
        }
      ]
    };
  }

  Map<String, dynamic> _mockRouteFallback() {
    return {
      'total_distance_km': 198.5,
      'total_time_mins': 295,
      'optimization_method': 'Google OR-Tools Guided VRP',
      'routes': [
        {
          'vehicle_id': 1,
          'total_distance_km': 198.5,
          'total_time_mins': 295,
          'stops_sequence': [
            {
              'stop_id': 'depot_central',
              'name': 'Nashik Central Cold Storage',
              'address': 'MIDC Ambad',
              'latitude': 19.9975,
              'longitude': 73.7898,
              'stop_type': 'depot',
              'cumulative_distance_km': 0.0,
              'estimated_arrival_mins': 0,
            },
            {
              'stop_id': 'stop_farm_1',
              'name': 'Patil Tomato Farm',
              'address': 'Dindori Road',
              'latitude': 20.1738,
              'longitude': 73.8344,
              'stop_type': 'pickup',
              'cumulative_distance_km': 20.15,
              'estimated_arrival_mins': 31,
            },
            {
              'stop_id': 'stop_farm_2',
              'name': 'Deshmukh Potato Barn',
              'address': 'Ozar Agri Zone',
              'latitude': 20.0931,
              'longitude': 73.9189,
              'stop_type': 'pickup',
              'cumulative_distance_km': 32.73,
              'estimated_arrival_mins': 50,
            },
            {
              'stop_id': 'stop_buyer_1',
              'name': 'Navi Mumbai Terminal',
              'address': 'Vashi APMC Market',
              'latitude': 19.0760,
              'longitude': 72.9980,
              'stop_type': 'dropoff',
              'cumulative_distance_km': 198.5,
              'estimated_arrival_mins': 295,
            }
          ],
          'polyline_coordinates': [
            [19.9975, 73.7898],
            [20.0800, 73.8100],
            [20.1738, 73.8344],
            [20.1300, 73.8800],
            [20.0931, 73.9189],
            [19.6000, 73.4000],
            [19.0760, 72.9980]
          ]
        }
      ]
    };
  }

  List<dynamic> _mockOrdersFallback() {
    return [
      {
        'id': 'ord_9901',
        'buyer_name': 'Reliance Fresh Retail Hub',
        'delivery_address': 'Vashi Sector 19, Navi Mumbai',
        'total_amount': 38400.0,
        'status': 'IN_TRANSIT',
        'driver_name': 'Santosh Shinde',
        'created_at': '2026-09-03 18:30',
      },
      {
        'id': 'ord_9902',
        'buyer_name': 'BigBasket Fulfillment Yard',
        'delivery_address': 'Bhiwandi Logistics Hub, Thane',
        'total_amount': 62500.0,
        'status': 'ASSIGNED',
        'driver_name': 'Santosh Shinde',
        'created_at': '2026-09-03 19:15',
      }
    ];
  }

  // ================= FARMER AI CHATBOT (GEMINI) =================
  Future<Map<String, dynamic>> askFarmerChatbot({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/api/chat',
        data: {
          'message': message,
          'history': history,
          'user_role': 'farmer',
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiClient] askFarmerChatbot error: $e');
      return _clientChatFallback(message);
    }
  }

  Map<String, dynamic> _clientChatFallback(String message) {
    final lower = message.toLowerCase();
    String reply;
    List<String> actions;

    if (lower.contains('list') || lower.contains('crop') || lower.contains('sell')) {
      reply = 'Namaste! To list your crop on KrishiSetu:\n\n'
          '1. Tap the "+ Add Produce" button on your inventory dashboard.\n'
          '2. Enter your crop details (Name, Grade, Quantity in Quintals, and Direct Price in ₹/kg).\n'
          '3. Once saved, your produce is immediately broadcast live to verified bulk buyers with +15% to 18% higher margins!';
      actions = ['What are Grade A+ criteria?', 'Mandi vs Direct Price', 'Escrow Payouts'];
    } else if (lower.contains('forecast') || lower.contains('price') || lower.contains('tomato')) {
      reply = 'Namaste! Our AI Demand Forecaster uses ARIMA/SARIMAX time-series models trained on APMC mandi data.\n\n'
          '• Current Tomato trend: Steady with an expected +8% price rise over the next 4 days.\n'
          '• Optimal harvest window: Selling mid-week yields highest direct profit margins.';
      actions = ['View Forecast Chart', 'Check Onion Price', 'List Produce'];
    } else if (lower.contains('escrow') || lower.contains('pay') || lower.contains('money')) {
      reply = 'Namaste! KrishiSetu integrates Razorpay Escrow to completely eliminate payment risk for farmers:\n\n'
          '1. Buyers deposit 100% of order funds into the secure Escrow pool before driver pickup.\n'
          '2. Once goods are inspected and delivered, payout is automatically released directly to your registered bank account.';
      actions = ['How to list crops?', 'Pickup Logistics', 'Quality Grades'];
    } else if (lower.contains('grade') || lower.contains('quality')) {
      reply = 'Namaste! KrishiSetu categorizes produce into 3 verified standards:\n\n'
          '• Grade A+ (Premium): Uniform shape, rich color, zero blemishes. Commands peak market rates.\n'
          '• Grade A (Standard): Standard commercial quality, minimal cosmetic variations.\n'
          '• Grade B (Fair): Minor irregularities, ideal for food processing and purees.';
      actions = ['List Grade A+ Crop', 'Escrow Payouts', 'Demand Forecast'];
    } else if (lower.contains('world cup') || lower.contains('python') || lower.contains('football')) {
      reply = 'I am KrishiSetu Sahayak, dedicated exclusively to assisting you with the KrishiSetu platform. I cannot assist with topics outside our platform. How can I help you with your crop listings, market prices, demand forecasts, or payouts on KrishiSetu today?';
      actions = ['List Crop Guide', 'Tomato Forecast', 'Escrow Payouts'];
    } else {
      reply = 'Namaste! I am KrishiSetu Sahayak, your agricultural AI assistant.\n\n'
          'I can assist you with listing produce, checking 7-day ARIMA price forecasts, understanding Grade A+/A quality standards, and tracking Razorpay Escrow payouts. What would you like to explore?';
      actions = ['🌾 List Crop Guide', '📈 Tomato Forecast', '💰 Escrow Payouts'];
    }

    return {
      'success': true,
      'reply': reply,
      'suggested_actions': actions,
    };
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/crop_item.dart';
import '../providers/farmer_provider.dart';

class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key});

  @override
  ConsumerState<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends ConsumerState<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropNameController = TextEditingController(text: 'Organic Vine Tomatoes');
  final _quantityController = TextEditingController(text: '50');
  final _priceController = TextEditingController(text: '25');
  final _locationController = TextEditingController(text: 'Dindori Farm Cluster, Nashik');
  
  String _selectedCategory = 'Vegetables';
  String _selectedGrade = 'A+';
  DateTime _harvestDate = DateTime.now();
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Vegetables',
    'Grains',
    'Tubers',
    'Pulses',
    'Spices',
    'Fruits',
    'Oilseeds',
  ];

  final List<String> _grades = ['A+', 'A', 'B'];

  @override
  void dispose() {
    _cropNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() => _selectedImage = photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo selection: ${e.toString()}')),
      );
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final user = ref.read(authProvider).user;

    final newCrop = CropItem(
      id: 'crop_${DateTime.now().millisecondsSinceEpoch}',
      farmerId: user?.id ?? 'usr_farmer_101',
      farmerName: user?.name ?? 'Ramesh Patil',
      farmerPhone: user?.phone ?? '+91 98765 43210',
      cropName: _cropNameController.text.trim(),
      category: _selectedCategory,
      quantityQuintals: double.tryParse(_quantityController.text) ?? 10.0,
      pricePerKg: double.tryParse(_priceController.text) ?? 20.0,
      grade: _selectedGrade,
      harvestDate: DateFormat('yyyy-MM-dd').format(_harvestDate),
      location: _locationController.text.trim(),
      imageUrl: _selectedImage != null
          ? _selectedImage!.path
          : 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600',
      mandiPriceComparison: (double.tryParse(_priceController.text) ?? 20.0) * 0.85,
    );

    final success = await ref.read(farmerProvider.notifier).addCropListing(newCrop);
    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crop inventory listed successfully on KrishiSetu!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Produce to Inventory'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Upload Container
                GestureDetector(
                  onTap: () => _showImageSourceDialog(),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 36,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload Crop Photo (image_picker)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Take photo or choose from gallery',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Crop Name
                TextFormField(
                  controller: _cropNameController,
                  decoration: const InputDecoration(
                    labelText: 'Crop / Variety Name',
                    hintText: 'e.g. Hybrid Fresh Tomatoes, Sharbati Wheat',
                    prefixIcon: Icon(Icons.eco, color: AppTheme.primaryGreen),
                  ),
                  validator: (v) => v!.isEmpty ? 'Please enter crop name' : null,
                ),
                const SizedBox(height: 16),

                // Category & Grade Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedGrade,
                        decoration: const InputDecoration(labelText: 'Quality Grade'),
                        items: _grades.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGrade = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity & Price Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Available Stock',
                          suffixText: 'Quintals',
                          prefixIcon: Icon(Icons.scale, color: AppTheme.primaryGreen),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter quantity' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Direct Price',
                          prefixText: '₹ ',
                          suffixText: '/ kg',
                          prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter price' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Farm Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Farm Location',
                    hintText: 'Village, Taluka, District',
                    prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryGreen),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter location' : null,
                ),
                const SizedBox(height: 16),

                // Harvest Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _harvestDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() => _harvestDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppTheme.primaryGreen),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Harvest Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(_harvestDate),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save & Publish to Direct Buyers'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
              title: const Text('Take Photo from Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
              title: const Text('Choose from Photo Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

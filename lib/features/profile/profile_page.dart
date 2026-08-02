import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_catalog.dart';
import '../../core/constants/app_colors.dart';
import '../../data/directory_data_store.dart';
import '../../data/local_directory_store.dart';
import '../../models/business.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final LocalDirectoryStore _store = LocalDirectoryStore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isEditing = false;
  String? _selectedCategory;
  String? _imagePath;

  @override
  void initState() {
    super.initState();

    final business = _store.currentUserBusiness;
    if (business == null) {
      _isEditing = true;
      return;
    }

    _isEditing = false;
    _loadBusiness(business);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadBusiness(Business business) {
    _nameController.text = business.name;
    _phoneController.text = business.phone;
    _whatsappController.text = business.whatsapp;
    _descriptionController.text = business.details;
    _selectedCategory = business.category;
    _imagePath = business.imagePath;
  }

  Future<void> _pickImage() async {
    final selectedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (!mounted || selectedImage == null) {
      return;
    }

    setState(() {
      _imagePath = selectedImage.path;
    });
  }

  void _saveBusiness() {
    if (_nameController.text.trim().isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إكمال الاسم واختيار القسم',
          ),
        ),
      );
      return;
    }

    _store.saveCurrentUserBusiness(
      name: _nameController.text,
      phone: _phoneController.text,
      whatsapp: _whatsappController.text,
      category: _selectedCategory!,
      details: _descriptionController.text,
      imagePath: _imagePath,
    );

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم حفظ الملف الشخصي بنجاح',
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _deleteBusiness(BuildContext dialogContext) {
    _store.deleteCurrentUserBusiness();

    Navigator.of(dialogContext).pop();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل البيانات' : 'الملف الشخصي',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: _isEditing ? _buildEditForm() : _buildProfileView(),
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _buildHeaderImage(isEditable: true),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildSectionTitle('بياناتك'),
              _buildInputCard([
                _buildCustomField(
                  'الاسم التجاري / الشخصي',
                  _nameController,
                  Icons.person_outline,
                ),
                _buildCustomField(
                  'رقم الجوال',
                  _phoneController,
                  Icons.phone_android,
                  isPhone: true,
                ),
                _buildCustomField(
                  'رقم الواتساب',
                  _whatsappController,
                  Icons.chat_outlined,
                  isPhone: true,
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionTitle('تفاصيل النشاط'),
              _buildInputCard([
                _buildCategoryDropdown(),
                _buildCustomField(
                  'وصف الخدمة',
                  _descriptionController,
                  Icons.description_outlined,
                  lines: 3,
                ),
              ]),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _saveBusiness,
                  icon: const Icon(
                    Icons.save,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'حفظ البيانات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.home,
                  color: Colors.grey,
                ),
                label: const Text(
                  'إلغاء والعودة للرئيسية',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        _buildHeaderImage(isEditable: false),
        const SizedBox(height: 20),
        Text(
          _nameController.text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTeal,
          ),
        ),
        Text(
          _selectedCategory ?? 'غير محدد',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.phone,
                  'رقم الجوال',
                  _phoneController.text,
                ),
                const Divider(),
                _buildInfoRow(
                  Icons.description,
                  'الوصف',
                  _descriptionController.text.isEmpty
                      ? 'لا يوجد وصف'
                      : _descriptionController.text,
                ),
                const Divider(),
                _buildInfoRow(
                  Icons.location_on,
                  'العنوان',
                  'الحامي',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 50),
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'تعديل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 50),
                  ),
                  onPressed: _showDeleteDialog,
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'حذف الحساب',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeaderImage({
    required bool isEditable,
  }) {
    ImageProvider<Object>? imageProvider;

    if (_imagePath != null &&
        _imagePath!.isNotEmpty &&
        File(_imagePath!).existsSync()) {
      imageProvider = FileImage(
        File(_imagePath!),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 100,
          decoration: const BoxDecoration(
            color: AppColors.primaryTeal,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
        ),
        Positioned(
          top: 40,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              if (isEditable)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.lightTeal,
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryTeal,
            size: 24,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 10,
          bottom: 8,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildCustomField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int lines = 1,
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: lines,
        textAlign: TextAlign.right,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.primaryTeal,
            size: 22,
          ),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final remoteCategories = DirectoryDataStore.instance.categories;
    final categories = remoteCategories.isNotEmpty
        ? remoteCategories
        : AppCatalog.allCategories;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: const Text('اختر النشاط'),
          isExpanded: true,
          value: _selectedCategory,
          items: categories.map((category) {
            return DropdownMenuItem<String>(
              value: category.name,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(category.name),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'هل أنت متأكد؟',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'سيتم حذف جميع بياناتك ولن تظهر في الدليل بعد الآن.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => _deleteBusiness(dialogContext),
              child: const Text(
                'نعم، احذف',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

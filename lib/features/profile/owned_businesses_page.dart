import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../data/repositories/account_repository.dart';
import '../../models/account_business.dart';
import 'profile_page.dart';
import 'widgets/add_business_button.dart';

class OwnedBusinessesPage extends StatefulWidget {
  const OwnedBusinessesPage({super.key});

  @override
  State<OwnedBusinessesPage> createState() => _OwnedBusinessesPageState();
}

class _OwnedBusinessesPageState extends State<OwnedBusinessesPage> {
  final AccountRepository _repository = AccountRepository();
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;

  List<AccountBusiness> _businesses = const <AccountBusiness>[];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _repository.loadCurrentAccount();
      if (!mounted) return;
      setState(() {
        _businesses = snapshot.allBusinesses;
        _isOffline = snapshot.isOffline;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createBusiness() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => const ProfilePage(startInCreateMode: true),
      ),
    );
    if (!mounted) return;
    await _load();
    await _directoryStore.refreshSyncQueueState();
  }

  Future<void> _openBusiness(AccountBusiness business) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => ProfilePage(businessId: business.id),
      ),
    );
    if (!mounted) return;
    await _load();
    await _directoryStore.refreshSyncQueueState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text(
          'أنشطتي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey<String>('owned-businesses-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            40,
          ),
          children: [
            AddBusinessButton(
              buttonKey: const ValueKey<String>(
                'owned-businesses-add-button',
              ),
              onPressed: _isLoading ? null : _createBusiness,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isOffline)
              _InfoBanner(
                icon: Icons.cloud_off_outlined,
                text: 'يتم عرض النسخة المحفوظة في الجهاز.',
                color: AppColors.warning,
              ),
            if (_isOffline) const SizedBox(height: AppSpacing.sm),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else if (_businesses.isEmpty)
              _EmptyState(onAdd: _createBusiness)
            else ...[
              Text(
                'لديك ${_businesses.length} نشاط',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final business in _businesses) ...[
                OwnedBusinessCard(
                  business: business,
                  onPressed: () => _openBusiness(business),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class OwnedBusinessCard extends StatelessWidget {
  const OwnedBusinessCard({
    required this.business,
    required this.onPressed,
    super.key,
  });

  final AccountBusiness business;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (business.status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      'changes_requested' => AppColors.warning,
      'pending' => AppColors.warning,
      'local_pending' => AppColors.primaryTeal,
      'sync_failed' => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Container(
      key: ValueKey<String>('owned-business-${business.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.storefront_rounded, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      business.categoryName.isEmpty
                          ? 'تصنيف غير محدد'
                          : business.categoryName,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  business.statusLabel,
                  style: AppTextStyles.bodySmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            business.phone.isEmpty ? 'لا يوجد رقم هاتف' : business.phone,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: ValueKey<String>('manage-business-${business.id}'),
              onPressed: onPressed,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('إدارة النشاط'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_business_outlined,
            size: 54,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('لا توجد أنشطة مسجلة', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'يمكنك إضافة أكثر من نشاط وإدارة كل نشاط بصورة مستقلة.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AddBusinessButton(onPressed: onAdd),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

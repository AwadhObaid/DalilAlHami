import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/admin_repository.dart';
import '../../models/admin_business_review.dart';

class AdminBusinessReviewDetailPage extends StatefulWidget {
  const AdminBusinessReviewDetailPage({
    required this.initialBusiness,
    required this.detailLoader,
    required this.reviewAction,
    super.key,
  });

  final AdminBusinessReviewItem initialBusiness;
  final Future<AdminBusinessReviewItem> Function(String businessId)
      detailLoader;
  final Future<AdminBusinessReviewResult> Function(
    String businessId,
    AdminReviewDecision decision,
    String? reason,
  ) reviewAction;

  @override
  State<AdminBusinessReviewDetailPage> createState() =>
      _AdminBusinessReviewDetailPageState();
}

class _AdminBusinessReviewDetailPageState
    extends State<AdminBusinessReviewDetailPage> {
  late AdminBusinessReviewItem _business;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _business = widget.initialBusiness;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final business = await widget.detailLoader(_business.id);
      if (!mounted) return;
      setState(() {
        _business = business;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error is AdminRepositoryFailure
            ? error.message
            : 'تعذر تحميل التفاصيل الكاملة للنشاط.';
      });
    }
  }

  Future<void> _startDecision(AdminReviewDecision decision) async {
    if (_isSubmitting || _business.status != 'pending') {
      return;
    }

    final submission = decision == AdminReviewDecision.approve
        ? await _confirmApproval()
        : await _requestReason(decision);
    if (!mounted || submission == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await widget.reviewAction(
        _business.id,
        submission.decision,
        submission.reason,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_successMessage(result.resultingStatus)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(true);
      } else {
        setState(() {
          _business = _business.copyWith(
            status: result.resultingStatus,
            rejectionReason: result.reason,
          );
          _isSubmitting = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is AdminRepositoryFailure
                  ? error.message
                  : 'تعذر حفظ قرار المراجعة.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<AdminReviewSubmission?> _confirmApproval() {
    return showDialog<AdminReviewSubmission>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اعتماد النشاط'),
          content: const Text(
            'سيظهر النشاط مباشرة في الدليل العام بعد الاعتماد. '
            'هل راجعت البيانات والصور ووسائل التواصل؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('confirm-approve-business'),
              onPressed: () {
                Navigator.pop(
                  context,
                  const AdminReviewSubmission(
                    decision: AdminReviewDecision.approve,
                  ),
                );
              },
              icon: const Icon(Icons.verified_rounded),
              label: const Text('اعتماد ونشر'),
            ),
          ],
        );
      },
    );
  }

  Future<AdminReviewSubmission?> _requestReason(
    AdminReviewDecision decision,
  ) {
    return showModalBottomSheet<AdminReviewSubmission>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _AdminReviewReasonSheet(decision: decision);
      },
    );
  }

  String _successMessage(String status) {
    return switch (status) {
      'approved' => 'تم اعتماد النشاط ونشره في الدليل.',
      'rejected' => 'تم رفض النشاط وحفظ السبب.',
      'changes_requested' => 'تم إرسال طلب التعديل لصاحب النشاط.',
      _ => 'تم حفظ قرار المراجعة.',
    };
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('تفاصيل مراجعة النشاط'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _DetailErrorState(message: _error!, onRetry: _loadDetail)
              : _buildContent(),
      bottomNavigationBar:
          !_isLoading && _error == null && _business.status == 'pending'
              ? _ReviewActionBar(
                  isSubmitting: _isSubmitting,
                  onApprove: () => _startDecision(AdminReviewDecision.approve),
                  onReject: () => _startDecision(AdminReviewDecision.reject),
                  onRequestChanges: () =>
                      _startDecision(AdminReviewDecision.requestChanges),
                )
              : null,
    );
  }

  Widget _buildContent() {
    return ListView(
      key: const PageStorageKey<String>('admin-business-review-detail'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        _BusinessHeroCard(business: _business),
        const SizedBox(height: AppSpacing.md),
        _DetailSection(
          title: 'صاحب النشاط',
          icon: Icons.person_outline_rounded,
          children: [
            _DetailRow(label: 'الاسم', value: _business.displayOwnerName),
            _DetailRow(
              label: 'البريد',
              value: _business.ownerEmail ?? 'غير متوفر',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailSection(
          title: 'بيانات النشاط',
          icon: Icons.storefront_rounded,
          children: [
            _DetailRow(label: 'القسم', value: _business.categoryName),
            _DetailRow(label: 'الهاتف', value: _business.phone),
            _DetailRow(label: 'واتساب', value: _business.whatsapp),
            _DetailRow(label: 'العنوان', value: _business.address),
            if (_business.latitude != null && _business.longitude != null)
              _DetailRow(
                label: 'الإحداثيات',
                value: '${_business.latitude}, ${_business.longitude}',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailSection(
          title: 'وصف النشاط',
          icon: Icons.description_outlined,
          children: [
            Text(
              _business.description.trim().isEmpty
                  ? 'لم يُضف وصف للنشاط.'
                  : _business.description,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _BusinessImagesSection(business: _business),
        const SizedBox(height: AppSpacing.sm),
        _ReviewHistorySection(history: _business.history),
        if (_business.status == 'pending') ...[
          const SizedBox(height: AppSpacing.md),
          const _ReviewSafetyNotice(),
        ],
      ],
    );
  }
}

class _AdminReviewReasonSheet extends StatefulWidget {
  const _AdminReviewReasonSheet({required this.decision});

  final AdminReviewDecision decision;

  @override
  State<_AdminReviewReasonSheet> createState() =>
      _AdminReviewReasonSheetState();
}

class _AdminReviewReasonSheetState extends State<_AdminReviewReasonSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _validationMessage;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isClosing) {
      return;
    }

    final reason = _controller.text.trim();
    if (reason.length < 5) {
      setState(() {
        _validationMessage = 'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.';
      });
      return;
    }

    setState(() {
      _isClosing = true;
      _validationMessage = null;
    });
    _focusNode.unfocus();

    Navigator.of(context).pop(
      AdminReviewSubmission(
        decision: widget.decision,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final isReject = widget.decision == AdminReviewDecision.reject;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md + keyboard,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isReject ? 'رفض النشاط' : 'طلب تعديل من صاحب النشاط',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isReject
                    ? 'اكتب سببًا واضحًا سيظهر لصاحب النشاط.'
                    : 'اكتب التعديلات المطلوبة بدقة حتى يستطيع صاحب النشاط إعادة الإرسال.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('admin-review-reason-field'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                enabled: !_isClosing,
                minLines: 3,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  if (_validationMessage != null) {
                    setState(() {
                      _validationMessage = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: isReject ? 'سبب الرفض' : 'التعديلات المطلوبة',
                  errorText: _validationMessage,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey<String>('confirm-review-with-reason'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isReject ? AppColors.danger : AppColors.warning,
                ),
                onPressed: _isClosing ? null : _submit,
                icon: Icon(
                  isReject ? Icons.block_rounded : Icons.edit_note_rounded,
                ),
                label: Text(
                  isReject ? 'تأكيد الرفض' : 'إرسال طلب التعديل',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessHeroCard extends StatelessWidget {
  const _BusinessHeroCard({required this.business});

  final AdminBusinessReviewItem business;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: business.preferredImageUrl.isEmpty
                ? const _LargeImagePlaceholder()
                : Image.network(
                    business.preferredImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _LargeImagePlaceholder(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name, style: AppTextStyles.titleLarge),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        business.categoryName.isEmpty
                            ? 'قسم غير محدد'
                            : business.categoryName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    business.status == 'pending'
                        ? 'قيد المراجعة'
                        : business.status,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeImagePlaceholder extends StatelessWidget {
  const _LargeImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primarySoft, AppColors.mintSoft],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: AppColors.primaryTeal,
          size: 68,
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryTeal),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children.expand(
            (child) => <Widget>[
              child,
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? 'غير متوفر' : value,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _BusinessImagesSection extends StatelessWidget {
  const _BusinessImagesSection({required this.business});

  final AdminBusinessReviewItem business;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final urls = <String>{
      if (business.logoUrl?.trim().isNotEmpty == true) business.logoUrl!.trim(),
      if (business.coverUrl?.trim().isNotEmpty == true)
        business.coverUrl!.trim(),
      ...business.images
          .map((image) => image.publicUrl.trim())
          .where((url) => url.isNotEmpty),
    }.toList(growable: false);

    return _DetailSection(
      title: 'صور النشاط',
      icon: Icons.photo_library_outlined,
      children: [
        if (urls.isEmpty)
          const Text('لا توجد صور مرفوعة لهذا النشاط.')
        else
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 180,
                    child: Image.network(
                      urls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _LargeImagePlaceholder(),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ReviewHistorySection extends StatelessWidget {
  const _ReviewHistorySection({required this.history});

  final List<AdminBusinessReviewHistory> history;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return _DetailSection(
      title: 'سجل المراجعة',
      icon: Icons.history_rounded,
      children: [
        if (history.isEmpty)
          const Text('هذه أول مراجعة مسجلة للنشاط.')
        else
          for (final item in history) ...[
            _HistoryItem(item: item),
            if (item != history.last) const Divider(),
          ],
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.item});

  final AdminBusinessReviewHistory item;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final local = item.createdAt.toLocal();
    final date = '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.actionLabel, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${item.reviewerName ?? 'مدير النظام'} — $date',
          style: AppTextStyles.bodySmall,
        ),
        if (item.reason?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(item.reason!, style: AppTextStyles.bodyMedium),
        ],
      ],
    );
  }
}

class _ReviewSafetyNotice extends StatelessWidget {
  const _ReviewSafetyNotice();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineStrong),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primaryTeal),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'يُحفظ القرار مع هوية المدير ووقت التنفيذ. '
              'الاعتماد ينشر النشاط فورًا، بينما الرفض أو طلب التعديل '
              'يجب أن يتضمنا سببًا واضحًا لصاحب النشاط.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActionBar extends StatelessWidget {
  const _ReviewActionBar({
    required this.isSubmitting,
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
  });

  final bool isSubmitting;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            : Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>(
                        'approve-business-review-button',
                      ),
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('اعتماد'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'request-business-changes-button',
                      ),
                      onPressed: onRequestChanges,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('طلب تعديل'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filledTonal(
                    key: const ValueKey<String>('reject-business-button'),
                    tooltip: 'رفض النشاط',
                    onPressed: onReject,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      backgroundColor: AppColors.dangerSoft,
                    ),
                    icon: const Icon(Icons.block_rounded),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

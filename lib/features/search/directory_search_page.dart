import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../directory/member_details_page.dart';
import '../directory/widgets/business_card.dart';
import '../home/widgets/search_box.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_status_banner.dart';
import '../shared/widgets/page_header.dart';

class DirectorySearchPage extends StatefulWidget {
  const DirectorySearchPage({super.key});

  @override
  State<DirectorySearchPage> createState() => _DirectorySearchPageState();
}

class _DirectorySearchPageState extends State<DirectorySearchPage>
    with AutomaticKeepAliveClientMixin<DirectorySearchPage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;
  final TextEditingController _controller = TextEditingController();

  String _query = '';
  List<Business> _results = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);

    if (!_store.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _store.load();
      });
    }
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _results = _store.search(_query);
    });
  }

  void _search(String value) {
    setState(() {
      _query = value;
      _results = _store.search(value);
    });
  }

  void _clearSearch() {
    _controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _query = '';
      _results = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        PageHeader(
          title: 'البحث',
          subtitle: 'ابحث بالاسم أو القسم أو العنوان أو رقم الهاتف',
          icon: Icons.search_rounded,
          action: IconButton.filledTonal(
            tooltip: 'تحديث البيانات',
            onPressed: _store.isLoading ? null : _store.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        SearchBox(
          controller: _controller,
          query: _query,
          onChanged: _search,
          onClear: _clearSearch,
        ),
        if (_store.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        if (_store.fallbackMessage != null)
          DirectoryStatusBanner(
            message: _store.fallbackMessage!,
            isRefreshing: _store.isRefreshing,
            onRetry: _store.refresh,
          ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_store.isInitialLoading) {
      return const DirectoryLoadingSkeleton();
    }

    if (_query.trim().isEmpty) {
      return _SearchPrompt(onExampleSelected: _selectExample);
    }

    if (_store.isLoading && _results.isEmpty) {
      return const DirectoryLoadingSkeleton();
    }

    if (_results.isEmpty) {
      return RefreshIndicator(
        onRefresh: _store.refresh,
        child: ListView(
          key: const ValueKey<String>('empty-search-results'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            56,
            AppSpacing.xl,
            130,
          ),
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 42,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'لم نجد نشاطًا مطابقًا',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'جرّب اسمًا أقصر، أو ابحث بالقسم أو رقم الهاتف.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('مسح البحث'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _store.refresh,
      child: ListView.separated(
        key: const PageStorageKey<String>('directory-search-results'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          130,
        ),
        itemCount: _results.length,
        separatorBuilder: (context, index) => const SizedBox(
          height: AppSpacing.sm,
        ),
        itemBuilder: (context, index) {
          final business = _results[index];

          return BusinessCard(
            business: business,
            onOpen: () => _openBusiness(business),
          );
        },
      ),
    );
  }

  void _selectExample(String example) {
    _controller.text = example;
    _controller.selection = TextSelection.collapsed(
      offset: example.length,
    );
    _search(example);
  }

  void _openBusiness(Business business) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemberDetailsPage(
          business: business,
        ),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({
    required this.onExampleSelected,
  });

  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) {
    const examples = ['مطاعم', 'صيدليات', 'ورش', 'نقل'];

    return ListView(
      key: const ValueKey<String>('search-prompt'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        46,
        AppSpacing.xl,
        130,
      ),
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.manage_search_rounded,
            size: 46,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'ما الذي تبحث عنه اليوم؟',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'اكتب اسم النشاط أو الخدمة أو الموقع أو رقم التواصل.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: examples.map((example) {
            return ActionChip(
              onPressed: () => onExampleSelected(example),
              avatar: const Icon(
                Icons.search_rounded,
                size: 17,
              ),
              label: Text(example),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

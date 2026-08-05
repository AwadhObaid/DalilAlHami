import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../data/directory_data_store.dart';
import '../../models/business.dart';
import '../shared/widgets/directory_loading_skeleton.dart';
import '../shared/widgets/directory_status_banner.dart';
import 'member_details_page.dart';
import 'widgets/business_card.dart';

class AllBusinessesPage extends StatelessWidget {
  const AllBusinessesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DirectoryDataStore.instance;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('جميع الأنشطة'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, child) {
          final businesses = store.businesses
              .where((business) => !business.isDeleted)
              .toList(growable: false)
            ..sort(_compareBusinesses);

          if (store.isInitialLoading) {
            return const DirectoryLoadingSkeleton();
          }

          return RefreshIndicator(
            onRefresh: store.refresh,
            child: CustomScrollView(
              key: const PageStorageKey<String>('all-businesses-page'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (store.isRefreshing)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (store.fallbackMessage != null)
                  SliverToBoxAdapter(
                    child: DirectoryStatusBanner(
                      message: store.fallbackMessage!,
                      isRefreshing: store.isRefreshing,
                      onRetry: store.refresh,
                    ),
                  ),
                if (businesses.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyBusinessesState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: businesses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final business = businesses[index];

                        return BusinessCard(
                          business: business,
                          onOpen: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    MemberDetailsPage(business: business),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _compareBusinesses(Business first, Business second) {
    if (first.isFeatured != second.isFeatured) {
      return first.isFeatured ? -1 : 1;
    }

    final firstUpdated = first.updatedAt ?? first.createdAt;
    final secondUpdated = second.updatedAt ?? second.createdAt;

    if (firstUpdated != null && secondUpdated != null) {
      return secondUpdated.compareTo(firstUpdated);
    }

    return first.displayName.compareTo(second.displayName);
  }
}

class _EmptyBusinessesState extends StatelessWidget {
  const _EmptyBusinessesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 52,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'لا توجد أنشطة متاحة حاليًا',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'اسحب إلى الأسفل لتحديث بيانات الدليل.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

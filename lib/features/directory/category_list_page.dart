import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/directory_data_store.dart';
import '../../models/service_category.dart';
import 'member_details_page.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({
    required this.category,
    super.key,
  });

  final ServiceCategory category;

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final DirectoryDataStore _store = DirectoryDataStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _store.byCategory(
      widget.category,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: AppColors.primaryTeal,
        centerTitle: true,
      ),
      body: _store.isLoading && !_store.hasLoaded
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _store.refresh,
              child: businesses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.65,
                          child: Center(
                            child: Text(
                              'لا توجد بيانات حالياً في قسم '
                              '${widget.category.name}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      itemCount: businesses.length,
                      itemBuilder: (context, index) {
                        final business = businesses[index];

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => MemberDetailsPage(
                                    business: business,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryTeal.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: business.logoUrl == null
                                  ? null
                                  : NetworkImage(
                                      business.logoUrl!,
                                    ),
                              child: business.logoUrl == null
                                  ? Icon(
                                      widget.category.icon,
                                      color: AppColors.primaryTeal,
                                    )
                                  : null,
                            ),
                            title: Text(
                              business.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(business.place),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color:
                                    AppColors.lightTeal.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.phone,
                                  color: AppColors.primaryTeal,
                                ),
                                onPressed: () {
                                  LaunchActions.makePhoneCall(
                                    context,
                                    business.phone,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

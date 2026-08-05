class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalCategories,
    required this.activeCategories,
    required this.totalBusinesses,
    required this.pendingBusinesses,
    required this.approvedBusinesses,
    required this.rejectedBusinesses,
    required this.changesRequestedBusinesses,
    required this.draftBusinesses,
    required this.suspendedBusinesses,
    required this.totalAdvertisements,
    required this.activeAdvertisements,
    required this.loadedAt,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalCategories;
  final int activeCategories;
  final int totalBusinesses;
  final int pendingBusinesses;
  final int approvedBusinesses;
  final int rejectedBusinesses;
  final int changesRequestedBusinesses;
  final int draftBusinesses;
  final int suspendedBusinesses;
  final int totalAdvertisements;
  final int activeAdvertisements;
  final DateTime loadedAt;
}

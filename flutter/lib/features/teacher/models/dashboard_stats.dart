/// Simple dashboard stats model — placeholder for richer views.
class DashboardStats {
  const DashboardStats({
    this.commissionThisMonth = 0,
    this.classroomsCount = 0,
    this.totalStudents = 0,
    this.aiQuotaRemaining = 0,
  });

  final int commissionThisMonth;
  final int classroomsCount;
  final int totalStudents;
  final int aiQuotaRemaining;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      commissionThisMonth: json['commission_this_month'] as int? ?? 0,
      classroomsCount: json['classrooms_count'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? 0,
      aiQuotaRemaining: json['ai_quota_remaining'] as int? ?? 0,
    );
  }
}
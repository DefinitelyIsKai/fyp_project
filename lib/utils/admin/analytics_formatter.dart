import 'package:fyp_project/models/admin/analytics_model.dart';

class AnalyticsFormatter {
  // Cap engagement rate at 100%
  static double capEngagementRate(double rate) {
    return rate > 100.0 ? 100.0 : rate;
  }

  // Cap growth rate at 100% and hide negative rates
  static double capGrowthRate(double rate) {
    if (rate > 100.0) return 100.0;
    if (rate < 0) return 0.0;
    return rate;
  }

  // Format growth rate for PDF - handle special cases and cap at 100%
  // -999.0 means no previous data, so calculate from current values instead
  static String formatGrowthRateForPDF(double rate, String metricType, AnalyticsModel analytics) {
    const double newDataIndicator = -999.0;
    if (rate == newDataIndicator) {
      // No previous data, calculate percentage from current values
      switch (metricType) {
        case 'userGrowth':
          return '100.0%';
        case 'activeUserGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.activeUsers / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '0.0%';
        case 'registrationGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.newRegistrations / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '100.0%';
        case 'engagementGrowth':
          return '${capEngagementRate(analytics.engagementRate).toStringAsFixed(1)}%';
        case 'messageGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.totalMessages / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '0.0%';
        case 'applicationGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.totalApplications / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '0.0%';
        case 'reportGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.totalReports / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '0.0%';
        case 'jobPostGrowth':
          if (analytics.totalUsers > 0) {
            final calculated = (analytics.totalJobPosts / analytics.totalUsers * 100);
            return '${(calculated > 100 ? 100.0 : calculated).toStringAsFixed(1)}%';
          }
          return '0.0%';
        default:
          return '0.0%';
      }
    }
    // Hide negative rates for certain metrics (looks better in report)
    if (rate < 0 && (metricType == 'registrationGrowth' || metricType == 'engagementGrowth' || metricType == 'applicationGrowth' || metricType == 'messageGrowth')) {
      return '0.0%';
    }
    // Cap everything at 100% max
    if (rate > 100) {
      return '100.0%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }
}


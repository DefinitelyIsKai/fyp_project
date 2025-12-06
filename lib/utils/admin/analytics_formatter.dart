import 'package:fyp_project/models/admin/analytics_model.dart';

class AnalyticsFormatter {
  
  static double capEngagementRate(double rate) {
    return rate > 100.0 ? 100.0 : rate;
  }

  static double capGrowthRate(double rate) {
    if (rate > 100.0) return 100.0;
    if (rate < 0) return 0.0;
    return rate;
  }

  static String formatGrowthRateForPDF(double rate, String metricType, AnalyticsModel analytics) {
    const double newDataIndicator = -999.0;
    if (rate == newDataIndicator) {
      
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
    
    if (rate < 0 && (metricType == 'registrationGrowth' || metricType == 'engagementGrowth' || metricType == 'applicationGrowth' || metricType == 'messageGrowth')) {
      return '0.0%';
    }
    
    if (rate > 100) {
      return '100.0%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }
}

import 'package:flutter/material.dart';
import 'package:fyp_project/widgets/admin/cards/content_analytics_stat_card.dart';

class ContentAnalyticsQuickStats extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const ContentAnalyticsQuickStats({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 50),
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: ContentAnalyticsStatCard(
                    title: 'Total Posts',
                    value: analytics['totalPosts'].toString(),
                    subtitle: 'All Time',
                    icon: Icons.article,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: ContentAnalyticsStatCard(
                    title: 'In Period',
                    value: analytics['postsInPeriod'].toString(),
                    subtitle: 'Selected Range',
                    icon: Icons.timeline,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: ContentAnalyticsStatCard(
                    title: 'Active',
                    value: analytics['active'].toString(),
                    subtitle: '${analytics['activeInPeriod']} in period',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: ContentAnalyticsStatCard(
                    title: 'Pending',
                    value: analytics['pending'].toString(),
                    subtitle: '${analytics['pendingInPeriod']} in period',
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.8),
                      Colors.white,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Scroll',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


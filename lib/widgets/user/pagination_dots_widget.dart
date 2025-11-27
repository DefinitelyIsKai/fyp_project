import 'package:flutter/material.dart';

/// A reusable smart pagination dots widget
/// Shows maximum 4 dots with ellipsis for many pages
/// Current page is indicated by larger size
class PaginationDotsWidget extends StatelessWidget {
  const PaginationDotsWidget({
    super.key,
    required this.totalPages,
    required this.currentPage,
  });

  final int totalPages;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 4) {
      // Show all dots if 4 or fewer pages
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => _buildDot(index == currentPage),
        ),
      );
    }
    
    // For many pages, show smart pagination with ellipsis
    List<Widget> dots = [];
    
    // Always show first page
    dots.add(_buildDot(currentPage == 0));
    dots.add(const SizedBox(width: 4));
    
    if (currentPage <= 2) {
      // Near start: show 0, 1, 2, 3, ...
      for (int i = 1; i <= 3 && i < totalPages; i++) {
        dots.add(_buildDot(i == currentPage));
        dots.add(const SizedBox(width: 4));
      }
      if (totalPages > 4) {
        dots.add(_buildEllipsis());
        dots.add(const SizedBox(width: 4));
        dots.add(_buildDot(currentPage == totalPages - 1)); // Last page
      }
    } else if (currentPage >= totalPages - 3) {
      // Near end: show ..., n-3, n-2, n-1, n
      if (totalPages > 4) {
        dots.add(_buildEllipsis());
        dots.add(const SizedBox(width: 4));
      }
      for (int i = totalPages - 3; i < totalPages; i++) {
        dots.add(_buildDot(i == currentPage));
        if (i < totalPages - 1) {
          dots.add(const SizedBox(width: 4));
        }
      }
    } else {
      // Middle: show first, ..., current (large), ..., last
      // Simplified to: first, ellipsis, current (large), ellipsis, last
      dots.removeLast(); // Remove the spacing after first dot
      dots.add(_buildEllipsis());
      dots.add(const SizedBox(width: 4));
      dots.add(_buildDot(true)); // current (always larger)
      dots.add(const SizedBox(width: 4));
      dots.add(_buildEllipsis());
      dots.add(const SizedBox(width: 4));
      dots.add(_buildDot(currentPage == totalPages - 1)); // last
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots,
    );
  }

  Widget _buildDot(bool isCurrent) {
    final size = isCurrent ? 12.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent
            ? const Color(0xFF00C8A0)
            : Colors.grey[300],
      ),
    );
  }

  Widget _buildEllipsis() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


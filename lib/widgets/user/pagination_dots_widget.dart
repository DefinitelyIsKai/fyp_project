import 'package:flutter/material.dart';

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
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => _buildDot(index == currentPage),
        ),
      );
    }
    

    List<Widget> dots = [];
    
    //first page
    dots.add(_buildDot(currentPage == 0));
    dots.add(const SizedBox(width: 4));
    
    if (currentPage <= 2) {
      for (int i = 1; i <= 3 && i < totalPages; i++) {
        dots.add(_buildDot(i == currentPage));
        dots.add(const SizedBox(width: 4));
      }
      if (totalPages > 4) {
        dots.add(_buildEllipsis());
        dots.add(const SizedBox(width: 4));
        dots.add(_buildDot(currentPage == totalPages - 1)); //last page
      }
    } else if (currentPage >= totalPages - 3) {
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
      dots.removeLast();
      dots.add(_buildEllipsis());
      dots.add(const SizedBox(width: 4));
      dots.add(_buildDot(true)); 
      dots.add(const SizedBox(width: 4));
      dots.add(_buildEllipsis());
      dots.add(const SizedBox(width: 4));
      dots.add(_buildDot(currentPage == totalPages - 1));
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


import '../../models/user/post.dart';

/// Utility functions for post operations
class PostUtils {
  /// Compute pages from a list of posts
  /// Splits posts into pages of specified size
  static List<List<Post>> computePages(
    List<Post> allPosts, {
    int itemsPerPage = 10,
  }) {
    final pages = <List<Post>>[];
    for (int i = 0; i < allPosts.length; i += itemsPerPage) {
      final end = (i + itemsPerPage < allPosts.length)
          ? i + itemsPerPage
          : allPosts.length;
      pages.add(allPosts.sublist(i, end));
    }
    if (pages.isEmpty && allPosts.isNotEmpty) {
      pages.add(allPosts);
    }
    return pages;
  }

  /// Check if two lists of posts are equal (by ID only)
  static bool listsEqual(List<Post> a, List<Post> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Check if post content has changed (not just IDs)
  /// This detects when a post is updated in Firestore
  static bool postsContentChanged(List<Post>? oldPosts, List<Post> newPosts) {
    if (oldPosts == null) return true;
    if (oldPosts.length != newPosts.length) return true;

    // Create a map of old posts by ID for quick lookup
    final oldPostsMap = {for (var p in oldPosts) p.id: p};

    // Check if any post content has changed
    for (final newPost in newPosts) {
      final oldPost = oldPostsMap[newPost.id];
      if (oldPost == null) return true; // New post

      // Compare key fields that might change when a post is updated
      if (oldPost.title != newPost.title ||
          oldPost.status != newPost.status ||
          oldPost.budgetMin != newPost.budgetMin ||
          oldPost.budgetMax != newPost.budgetMax ||
          oldPost.location != newPost.location ||
          oldPost.views != newPost.views ||
          oldPost.applicants != newPost.applicants ||
          oldPost.description != newPost.description) {
        return true; // Content changed
      }
    }

    return false; // No content changes detected
  }
}



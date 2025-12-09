import '../../models/user/post.dart';

class PostUtils {
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
 
  static bool listsEqual(List<Post> a, List<Post> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

 
  static bool postsContentChanged(List<Post>? oldPosts, List<Post> newPosts) {
    if (oldPosts == null) return true;
    if (oldPosts.length != newPosts.length) return true;
    final oldPostsMap = {for (var p in oldPosts) p.id: p};

    //check content
    for (final newPost in newPosts) {
      final oldPost = oldPostsMap[newPost.id];
      if (oldPost == null) return true; //new

      //compare field
      if (oldPost.title != newPost.title ||
          oldPost.status != newPost.status ||
          oldPost.budgetMin != newPost.budgetMin ||
          oldPost.budgetMax != newPost.budgetMax ||
          oldPost.location != newPost.location ||
          oldPost.views != newPost.views ||
          oldPost.applicants != newPost.applicants ||
          oldPost.description != newPost.description) {
        return true; //content change
      }
    }

    return false;
  }
}



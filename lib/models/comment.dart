class Comment {
  final String id;
  final String articleUrl;
  final String userId;
  final String commentText;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.articleUrl,
    required this.userId,
    required this.commentText,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      articleUrl: json['article_url'],
      userId: json['user_id'],
      commentText: json['comment_text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

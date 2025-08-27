import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;

  const CommentCard({Key? key, required this.comment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment.commentText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: ${comment.userId.substring(0, 8)}...', // Display first 8 chars of user ID
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

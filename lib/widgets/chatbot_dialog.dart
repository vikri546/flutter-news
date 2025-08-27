import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/article_provider.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';

class ChatbotDialog extends StatefulWidget {
  const ChatbotDialog({Key? key}) : super(key: key);

  @override
  _ChatbotDialogState createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog> {
  final TextEditingController _textController = TextEditingController();
  final List<dynamic> _messages = [];
  bool _isLoading = false;

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.insert(0, {'isUser': true, 'text': text});
      _isLoading = true;
    });

    final articleProvider =
        Provider.of<ArticleProvider>(context, listen: false);
    await articleProvider.searchArticles(text,
        dateFilter: {}, sortBy: 'relevancy');

    setState(() {
      _messages.insert(0, {'isUser': false, 'articles': articleProvider.searchResults});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI Chatbot'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  if (message['isUser']) {
                    return ListTile(
                      title: Text(message['text'], textAlign: TextAlign.right),
                    );
                  } else {
                    if (message['articles'].isEmpty) {
                      return const ListTile(
                        title: Text('No articles found.'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (message['articles'] as List<Article>)
                          .map((article) => ListTile(
                                title: Text(article.title),
                                subtitle: Text(
                                  article.description ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  final articleProvider =
                                      Provider.of<ArticleProvider>(context,
                                          listen: false);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ArticleDetailScreen(
                                        article: article,
                                        isBookmarked: articleProvider
                                            .bookmarkedArticles
                                            .any((a) => a.id == article.id),
                                        onBookmarkToggle: () {
                                          articleProvider
                                              .toggleBookmark(article);
                                        },
                                        heroTag: 'chatbot-${article.id}',
                                      ),
                                    ),
                                  );
                                },
                              ))
                          .toList(),
                    );
                  }
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            const Divider(height: 1.0),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration:
                    const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

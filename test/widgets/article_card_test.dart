import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:your_app/widgets/article_card.dart';
import 'package:your_app/models/article.dart';

void main() {
  late Article testArticle;

  setUp(() {
    testArticle = Article(
      id: '1',
      title: 'Test Article',
      description: 'Test Description',
      content: 'Test Content',
      urlToImage: 'https://test.com/image.jpg',
      url: 'https://test.com',
      publishedAt: DateTime.now(),
      category: 'Technology',
      source: Source(id: '1', name: 'Test Source'),
    );
  });

  testWidgets('ArticleCard renders correctly with all properties', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleCard(
            article: testArticle,
            isBookmarked: false,
            onBookmarkToggle: () {},
            index: 0,
          ),
        ),
      ),
    );

    expect(find.text('Test Article'), findsOneWidget);
    expect(find.text('Test Description'), findsOneWidget);
    expect(find.text('From Test Source'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('Technology'), findsOneWidget);
  });

  testWidgets('ArticleCard handles null image URL', (WidgetTester tester) async {
    final articleWithoutImage = Article(
      id: '2',
      title: 'No Image Article',
      description: null,
      content: 'Test Content',
      urlToImage: null,
      url: 'https://test.com',
      publishedAt: DateTime.now(),
      category: 'Technology',
      source: Source(id: '1', name: 'Test Source'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleCard(
            article: articleWithoutImage,
            isBookmarked: false,
            onBookmarkToggle: () {},
            index: 0,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
  });

  testWidgets('BookmarkButton toggles state on tap', (WidgetTester tester) async {
    bool isBookmarked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkButton(
            isBookmarked: isBookmarked,
            onToggle: () {
              isBookmarked = !isBookmarked;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsNothing);

    await tester.tap(find.byType(BookmarkButton));
    await tester.pump();

    expect(isBookmarked, true);
  });

  test('_formatDate returns correct format', () {
    final now = DateTime.now();
    final widget = _ArticleCardState();
    
    expect(widget._formatDate(now), '0 min ago');
    expect(widget._formatDate(now.subtract(const Duration(hours: 2))), '2 hours ago');
    expect(widget._formatDate(now.subtract(const Duration(days: 1))), 'Yesterday');
    expect(widget._formatDate(now.subtract(const Duration(days: 3))), '3 days ago');
  });

  testWidgets('ArticleCard applies scale animation on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleCard(
            article: testArticle,
            isBookmarked: false,
            onBookmarkToggle: () {},
            index: 0,
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(find.byType(ArticleCard)));
    await tester.pump();

    await gesture.up();
    await tester.pump();
  });
}

class Article {
  final String? id;
  final Source source;
  final String? author;
  final String title;
  final String? description;
  final String url;
  final String? urlToImage;
  final DateTime publishedAt;
  final String? content;
  final String category;

  Article({
    this.id,
    required this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    this.content,
    required this.category,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ??
          json[
              'https://newsapi.org/v2'], // Use URL as ID if no ID is provided
      source: Source.fromJson(json['source']),
      author: json['author'],
      title: json['title'] ?? 'No Title',
      description: json['description'],
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'],
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : DateTime.now(),
      content: json['content'],
      category:
          json['category'] ?? 'General', // Default to General if no category
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source.toJson(),
      'author': author,
      'title': title,
      'description': description,
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt.toIso8601String(),
      'content': content,
      'category': category,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Source {
  final String? id;
  final String name;

  Source({
    this.id,
    required this.name,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'],
      name: json['name'] ?? 'Unknown Source',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

// Categories that match NewsAPI categories
List<String> categories = [
  'All',
  'DIGITAL',
  'EKBIS',
  'HUKUM',
  'POLITIK',
];

// Mengimpor utility untuk membersihkan tag HTML
import 'package:html_unescape/html_unescape.dart';

class Article {
  final String id;
  final Source source;
  final String? author;
  final String title;
  final String? description;
  final String url;
  final String? urlToImage;
  final DateTime publishedAt;
  final DateTime modifiedAt;
  final String? content;
  final String category;
  final String? penulis;
  final List<String> tags; // BARU: Untuk menyimpan keywords/tags

  Article({
    required this.id,
    required this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    required this.modifiedAt,
    this.content,
    required this.category,
    this.penulis,
    this.tags = const [], // BARU: Default empty list
  });

  factory Article.fromWordPress(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();

    final String id = (json['id'] ?? 0).toString();
    final String title = (json['title'] != null && json['title']['rendered'] is String)
        ? unescape.convert(_stripHtml(json['title']['rendered']))
        : 'No Title';
    final String url = json['link'] ?? '';
    final String? description = (json['excerpt'] != null && json['excerpt']['rendered'] is String)
        ? unescape.convert(_stripHtml(json['excerpt']['rendered']))
        : null;
    final String? content = (json['content'] != null && json['content']['rendered'] is String)
        ? json['content']['rendered']
        : null;
        
    final DateTime publishedAt = (json['date_gmt'] != null)
        ? (DateTime.tryParse(
            json['date_gmt'].endsWith('Z') ? json['date_gmt'] : json['date_gmt'] + 'Z'
          )?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final DateTime modifiedAt = (json['modified_gmt'] != null)
        ? (DateTime.tryParse(
            json['modified_gmt'].endsWith('Z') ? json['modified_gmt'] : json['modified_gmt'] + 'Z'
          )?.toLocal() ?? publishedAt)
        : publishedAt;

    final Map<String, dynamic> embedded = json['_embedded'] ?? {};

    String? author;
    if (embedded['author'] != null && embedded['author'] is List) {
      final authorList = embedded['author'] as List;
      if (authorList.isNotEmpty && authorList[0] is Map) {
        final authorData = authorList[0] as Map;
        final authorName = authorData['name']?.toString().trim() ?? '';

        if (authorName.isNotEmpty) {
          if (authorName.contains(',')) {
            final names = authorName.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty).toList();
            author = names.join(' / ');
          } else {
            author = authorName;
          }
        }
      }
    }
    author ??= 'Unknown Author';

    String? imageUrl;
    if (embedded['wp:featuredmedia'] != null && embedded['wp:featuredmedia'] is List && (embedded['wp:featuredmedia'] as List).isNotEmpty) {
      final media = embedded['wp:featuredmedia'][0];
      if (media['media_details'] != null && media['media_details'] is Map) {
         final mediaDetails = media['media_details'] as Map;
         if (mediaDetails['sizes'] != null && mediaDetails['sizes'] is Map) {
            final sizes = mediaDetails['sizes'] as Map;
            if(sizes['medium_large'] != null && sizes['medium_large'] is Map && sizes['medium_large']['source_url'] != null) {
               imageUrl = sizes['medium_large']['source_url'];
            }
            else if (sizes['full'] != null && sizes['full'] is Map && sizes['full']['source_url'] != null) {
               imageUrl = sizes['full']['source_url'];
            }
         }
      }
      imageUrl ??= media['source_url'];
    }

    String category = 'General';
    if (embedded['wp:term'] != null && embedded['wp:term'] is List) {
      final terms = embedded['wp:term'] as List;
      final categoryList = terms.firstWhere(
        (termList) => termList is List && termList.isNotEmpty && termList[0] is Map && termList[0]['taxonomy'] == 'category',
        orElse: () => null
      );
      if (categoryList != null && categoryList is List && categoryList.isNotEmpty && categoryList[0] is Map) {
        category = categoryList[0]['name'] ?? 'General';
      }
    }

    final String? penulis = (json['twitter_misc'] != null && 
                            json['twitter_misc'] is Map && 
                            json['twitter_misc']['Ditulis oleh'] != null)
        ? json['twitter_misc']['Ditulis oleh'] as String
        : null;

    // BARU: Parsing tags dari yoast_head_json > schema > @graph > keywords
    List<String> tags = [];
    if (json['yoast_head_json'] != null && json['yoast_head_json'] is Map) {
      final yoastData = json['yoast_head_json'] as Map;
      if (yoastData['schema'] != null && yoastData['schema'] is Map) {
        final schema = yoastData['schema'] as Map;
        if (schema['@graph'] != null && schema['@graph'] is List) {
          final graph = schema['@graph'] as List;
          for (var node in graph) {
            if (node is Map && node['keywords'] != null && node['keywords'] is List) {
              tags = (node['keywords'] as List)
                  .where((item) => item is String && item.trim().isNotEmpty)
                  .map((item) => item.toString().trim())
                  .toList();
              break; // Ambil keywords pertama yang ditemukan
            }
          }
        }
      }
    }

    return Article(
      id: id,
      source: Source(id: 'owrite-id', name: 'Owrite ID'),
      author: author,
      title: title,
      description: description,
      url: url,
      urlToImage: imageUrl,
      publishedAt: publishedAt,
      modifiedAt: modifiedAt,
      content: content,
      category: category,
      penulis: penulis,
      tags: tags, // BARU
    );
  }

  Map<String, dynamic> toJson() {
    String authorString = author ?? 'Unknown Author';
    if (authorString.contains(' / ')) {
      authorString = authorString.replaceAll(' / ', ', ');
    }

    return {
      'id': int.tryParse(id) ?? 0,
      'link': url,
      'date_gmt': publishedAt.toUtc().toIso8601String().replaceAll('Z', ''),
      'modified_gmt': modifiedAt.toUtc().toIso8601String().replaceAll('Z', ''),
      'title': {'rendered': title},
      'excerpt': {'rendered': description ?? ''},
      'content': {'rendered': content ?? ''},
      'twitter_misc': penulis != null ? {'Ditulis oleh': penulis} : null,
      'yoast_head_json': tags.isNotEmpty ? {
        'schema': {
          '@graph': [
            {'keywords': tags}
          ]
        }
      } : null, // BARU
      '_embedded': {
        'author': [{'name': authorString}],
        'wp:featuredmedia': [{'source_url': urlToImage ?? ''}],
        'wp:term': [[{'name': category, 'taxonomy': 'category'}]]
      }
    };
  }

   factory Article.fromJson(Map<String, dynamic> json) {
    return Article.fromWordPress(json);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

   List<Map<String, String>> get authorList {
     if (author == null || author!.isEmpty || author == 'Unknown Author') {
       return [];
     }
     final names = author!.split(' / ');
     return names.map((name) {
       final cleanName = name.trim();
       final slug = cleanName.toLowerCase()
           .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
           .replaceAll(RegExp(r'\s+'), '-');
       return {'name': cleanName, 'url': 'https://www.owrite.id/author/$slug/'};
     }).toList();
   }
}

class Source {
  final String? id;
  final String name;

  Source({ this.id, required this.name });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id']?.toString(),
      name: json['name'] ?? 'Unknown Source',
    );
  }

  Map<String, dynamic> toJson() {
    return { 'id': id, 'name': name };
  }
}

String _stripHtml(String htmlString) {
  final RegExp exp = RegExp(r"<\s*[^>]*\s*>", multiLine: true, caseSensitive: false);
  return HtmlUnescape().convert(htmlString).replaceAll(exp, '').trim();
}
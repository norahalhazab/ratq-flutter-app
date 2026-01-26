class NewsArticle {
  final String title;
  final String? description;
  final String? url;
  final String? imageUrl;
  final String? source;
  final String? publishedAt;

  NewsArticle({
    required this.title,
    this.description,
    this.url,
    this.imageUrl,
    this.source,
    this.publishedAt,
  });

  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    return NewsArticle(
      title: map['title'] ?? 'No title',
      description: map['description'],
      url: map['url'],
      imageUrl: map['imageUrl'],
      source: map['source'],
      publishedAt: map['publishedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'imageUrl': imageUrl,
      'source': source,
      'publishedAt': publishedAt,
    };
  }

  @override
  String toString() {
    return 'NewsArticle(title: $title, source: $source)';
  }
} 
import 'package:http/http.dart' as http;

class SearchService {
  /// Performs a simple web search and returns the text results.
  /// This uses DuckDuckGo's HTML version (non-JS) for easy scraping.
  Future<String> searchProduct(String barcode) async {
    try {
      final query = Uri.encodeComponent(barcode);
      final url = 'https://html.duckduckgo.com/html/?q=$query';
      
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      });

      if (response.statusCode == 200) {
        // We just return the raw HTML for the AI to parse, 
        // or we could strip tags. Strip tags is safer for token usage.
        return _stripHtmlTags(response.body);
      }
    } catch (e) {
      print('Search Error: $e');
    }
    return '';
  }

  String _stripHtmlTags(String html) {
    // Basic regex to strip tags. Not perfect but reduces token count significantly.
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

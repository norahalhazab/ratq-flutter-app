import 'dart:convert';

class ToonConverter {
  /// Encodes a Dart object (Map or List) into a TOON-like string.
  /// This format is designed to be token-efficient for LLMs.
  static String encode(dynamic data) {
    if (data == null) return '';
    return _encodeValue(data, 0);
  }

  static String _encodeValue(dynamic value, int indentLevel) {
    final indent = '  ' * indentLevel;
    
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final buffer = StringBuffer();
      value.forEach((k, v) {
        // For simple keys, no quotes.
        buffer.writeln('$indent$k: ${_encodeValue(v, indentLevel + 1).trimLeft()}');
      });
      return buffer.toString().trimRight();
    } else if (value is List) {
      if (value.isEmpty) return '[]';
      // Optimization: If list contains only primitives, use CSV-like or compact list
      if (value.every((e) => e is! Map && e is! List)) {
        return '$indent[${value.join(', ')}]';
      }
      
      final buffer = StringBuffer();
      for (var item in value) {
        buffer.writeln('$indent- ${_encodeValue(item, indentLevel + 1).trimLeft()}');
      }
      return buffer.toString().trimRight();
    } else {
      // Primitives
      return value.toString();
    }
  }

  /// Decodes a TOON-like string back into a Dart object.
  /// This is a simplified parser designed for LLM outputs which are usually
  /// well-structured if prompted correctly.
  static dynamic decode(String text) {
    text = text.trim();
    if (text.isEmpty) return {};

    // Try to parse as standard JSON first, just in case the LLM reverted to JSON
    try {
      if (text.startsWith('{') || text.startsWith('[')) {
        return jsonDecode(text);
      }
    } catch (_) {}

    final lines = text.split('\n');
    final root = <String, dynamic>{};
    List<dynamic>? currentList;
    Map<String, dynamic>? currentMap = root;
    
    // Simple stack-based parsing could be complex. 
    // For now, we'll implement a heuristic parser that handles the expected output formats.
    // 1. Key-Value pairs
    // 2. Lists with dashes
    
    // If the text looks like a list (starts with -)
    if (text.startsWith('- ')) {
      return _parseList(lines);
    }

    return _parseMap(lines);
  }

  static Map<String, dynamic> _parseMap(List<String> lines) {
    final result = <String, dynamic>{};
    String? currentKey;
    List<String> buffer = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Check for "key: value" BUT ignore if it looks like a list item
      final colonIndex = line.indexOf(':');
      final isListItem = trimmed.startsWith('-');
      
      if (colonIndex != -1 && !isListItem) {
        // If we have a previous key with buffered lines, process them
        if (currentKey != null && buffer.isNotEmpty) {
          result[currentKey] = _parseBuffer(buffer);
          buffer.clear();
        }

        final key = line.substring(0, colonIndex).trim();
        final valuePart = line.substring(colonIndex + 1).trim();

        currentKey = key;
        if (valuePart.isNotEmpty) {
          // Immediate value
          if (valuePart.startsWith('[') && valuePart.endsWith(']')) {
             // Inline list
             final content = valuePart.substring(1, valuePart.length - 1);
             result[key] = content.split(',').map((e) => e.trim()).toList();
             currentKey = null; // Reset
          } else {
             result[key] = valuePart;
             currentKey = null; // Reset
          }
        } else {
          // Multiline value or nested object coming up
        }
      } else {
        // Continuation of previous key
        if (currentKey != null) {
          buffer.add(line);
        }
      }
    }

    // Process last buffer
    if (currentKey != null && buffer.isNotEmpty) {
      result[currentKey] = _parseBuffer(buffer);
    }

    return result;
  }

  static dynamic _parseBuffer(List<String> lines) {
    if (lines.isEmpty) return '';
    
    // Check if it's a list
    if (lines.every((l) => l.trim().startsWith('- '))) {
      return lines.map((l) => l.trim().substring(2)).toList();
    }
    
    // Check if it's a nested map
    if (lines.any((l) => l.contains(':'))) {
      return _parseMap(lines);
    }
    
    // Just text
    return lines.join('\n');
  }

  static List<dynamic> _parseList(List<String> lines) {
    return lines
        .where((l) => l.trim().startsWith('- '))
        .map((l) => l.trim().substring(2))
        .toList();
  }
}

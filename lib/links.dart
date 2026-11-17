/// Pulls a share code out of an https short link or a quero:// link.
String? shareCodeFromUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme == 'quero' && uri.host == 's') {
    if (uri.pathSegments.isEmpty) return null;
    final code = uri.pathSegments.first.trim();
    return code.isEmpty ? null : code;
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 's') {
      final code = uri.pathSegments[1].trim();
      return code.isEmpty ? null : code;
    }
  }
  return null;
}

const blockedRetryMessage = 'A loja bloqueou a busca automática. Edite o preço ou toque em Tentar de novo.';
const genericRetryMessage = 'Não consegui atualizar agora. Edite o preço ou toque em Tentar de novo.';

/// One short line for the card. Older saves joined the store message and
/// "Mantivemos a foto…" without a sentence break.
String conciseScrapeMessage(String raw) {
  final trimmed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final keptAt = trimmed.toLowerCase().indexOf('mantivemos ');
  final head = (keptAt > 0 ? trimmed.substring(0, keptAt) : trimmed).trim();
  final folded = head.toLowerCase();
  if (folded.contains('bloqueia') || folded.contains('bloqueou')) return blockedRetryMessage;
  if (keptAt > 0) {
    if (head.isEmpty) return genericRetryMessage;
    final end = head.endsWith('.') || head.endsWith('!') || head.endsWith('?') ? '' : '.';
    return '$head$end';
  }
  return trimmed;
}

bool offerScrapeRetry({required String status, String? message}) {
  if (status == 'failed' || status == 'partial') {
    final text = message ?? '';
    if (text.startsWith('Atualizamos')) return false;
    return status == 'failed' || text.contains('Tentar de novo') || text.toLowerCase().contains('bloque');
  }
  return false;
}

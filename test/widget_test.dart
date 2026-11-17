import 'package:flutter_test/flutter_test.dart';
import 'package:quero/api.dart';
import 'package:quero/links.dart';
import 'package:quero/main.dart';
import 'package:quero/money.dart';
import 'package:quero/session.dart';

void main() {
  test('formata real e dólar', () {
    expect(formatMoney(6196.39, 'BRL'), 'R\$ 6.196,39');
    expect(formatMoney(584.1, 'BRL'), 'R\$ 584,10');
    expect(formatMoney(12.5, 'USD'), 'US\$ 12.50');
    expect(formatMoney(10, null), '10,00');
  });

  test('lê preço digitado no formato brasileiro', () {
    expect(parseUserPrice('1.299,90'), 1299.90);
    expect(parseUserPrice('R\$ 584,10'), 584.10);
    expect(parseUserPrice(''), null);
  });

  test('lê código de link curto e do esquema do app', () {
    expect(shareCodeFromUri(Uri.parse('https://lista-desejos-backend.onrender.com/s/Ab12cd')), 'Ab12cd');
    expect(shareCodeFromUri(Uri.parse('wishly://s/Ab12cd')), 'Ab12cd');
    expect(shareCodeFromUri(Uri.parse('https://cesarwillemberg.github.io/lista-desejos-frontend/#/l/Ab12cd')), null);
    expect(inviteCodeFromUri(Uri.parse('https://lista-desejos-backend.onrender.com/c/Ab12cd')), 'Ab12cd');
    expect(inviteCodeFromUri(Uri.parse('wishly://c/Ab12cd')), 'Ab12cd');
  });

  testWidgets('mostra entrar e criar conta', (tester) async {
    await tester.pumpWidget(
      QueroApp(api: QueroApi(root: 'http://test.local'), tokens: MemoryTokenStore(), claims: MemoryClaimStore()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Não tem conta? Criar conta'), findsOneWidget);
  });
}

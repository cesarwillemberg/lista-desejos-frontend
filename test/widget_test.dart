import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quero/api.dart';
import 'package:quero/main.dart';
import 'package:quero/money.dart';

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

  testWidgets('mostra a lista vazia', (tester) async {
    final api = QueroApi(
      root: 'http://test.local',
      client: MockClient((request) async {
        return http.Response(jsonEncode({'items': [], 'totals': [], 'unpriced_count': 0}), 200);
      }),
    );
    await tester.pumpWidget(QueroApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Quero'), findsWidgets);
    expect(find.text('Nada por aqui ainda'), findsOneWidget);
  });
}

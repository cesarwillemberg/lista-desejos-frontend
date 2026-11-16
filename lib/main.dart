import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'home_page.dart';
import 'theme.dart';

void main() {
  runApp(const QueroApp());
}

class QueroApp extends StatelessWidget {
  const QueroApp({super.key, this.api});

  final QueroApi? api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quero',
      debugShowCheckedModeBanner: false,
      theme: queroTheme(),
      home: HomePage(api: api ?? QueroApi()),
    );
  }
}

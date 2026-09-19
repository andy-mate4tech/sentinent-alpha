import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(SentientAlphaApp(state: AppState()));
}

class SentientAlphaApp extends StatelessWidget {
  const SentientAlphaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sentient Alpha',
          debugShowCheckedModeBanner: false,
          theme: buildSentientTheme(),
          home: ShellScreen(state: state),
        );
      },
    );
  }
}

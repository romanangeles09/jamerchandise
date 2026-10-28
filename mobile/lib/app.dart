import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'auth.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

class JaApp extends StatefulWidget {
  const JaApp({super.key});

  @override
  State<JaApp> createState() => _JaAppState();
}

class _JaAppState extends State<JaApp> {
  late final ApiClient api;
  late final AuthController auth;

  @override
  void initState() {
    super.initState();
    api = ApiClient(
      onUnauthorized: () {
        auth.logout();
      },
    );
    auth = AuthController(api);
    auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        title: 'JA Merchandise',
        debugShowCheckedModeBanner: false,
        theme: buildJaTheme(),
        home: Consumer<AuthController>(
          builder: (context, auth, _) {
            if (auth.loading) {
              return const Scaffold(
                body: Center(
                  child: Text('Loading JA Merchandise...', style: TextStyle(color: JaColors.muted)),
                ),
              );
            }
            if (auth.user == null) return const LoginScreen();
            return const AppShell();
          },
        ),
      ),
    );
  }
}

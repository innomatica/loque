import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:provider/provider.dart';

import 'logic/loque.dart';
import 'logic/search.dart';
import 'screens/home/home.dart';
import 'services/apptheme.dart';
import 'services/sharedprefs.dart';

void main() async {
  // flutter
  WidgetsFlutterBinding.ensureInitialized();
  // audio handler
  final LoqueAudioHandler handler = await initAudioService();
  // shared preference
  await SharedPrefsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchLogic()),
        ChangeNotifierProvider(create: (_) => LoqueLogic(handler)),
        // Provider<LoqueAudioHandler>(
        //   create: (context) {
        //     // inject dependency without ProxyProvider
        //     handler.setLogic(context.read<LoqueLogic>());
        //     return handler;
        //   },
        //   dispose: (context, value) => handler.dispose(),
        // ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // debugPrint('MyApp.build');
    return DynamicColorBuilder(
        builder: (ColorScheme? lightScheme, ColorScheme? darkScheme) {
      return MaterialApp(
        title: 'Loque',
        theme: AppTheme.lightTheme(lightScheme),
        darkTheme: AppTheme.darkTheme(darkScheme),
        home: const HomePage(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

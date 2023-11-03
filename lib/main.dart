import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/services/audiohandler.dart';
// import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'logic/loque.dart';
import 'logic/search.dart';
import 'screens/home/home.dart';
import 'services/apptheme.dart';
import 'services/sharedprefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /*
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    // check https://github.com/ryanheise/just_audio/issues/619
    androidNotificationIcon: 'drawable/app_icon',
  );
  */

  final LoqueAudioHandler handler = await initAudioService();

  await SharedPrefsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchLogic()),
        ChangeNotifierProvider(create: (_) => LoqueLogic()),
        Provider<LoqueAudioHandler>(
          create: (context) {
            // inject dependency without ProxyProvider
            handler.setLogic(context.read<LoqueLogic>());
            return handler;
          },
          dispose: (context, value) => handler.dispose(),
        ),
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
        title: 'Flutter Demo',
        theme: AppTheme.lightTheme(lightScheme),
        darkTheme: AppTheme.darkTheme(darkScheme),
        home: const HomePage(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

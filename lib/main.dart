import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:innova/login/loginScreen.dart';
import 'package:innova/login/splashScreen.dart';
import 'package:innova/navigation/internNavigationScreen.dart';
import 'package:innova/navigation/managerNavigationScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://stzxsuezwxeouofryqlb.supabase.co',
    publishableKey: 'sb_publishable_Fb6CIVFLsNhnvpjHBCRXPQ_klBQg_ZU'
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M.I.S. Task',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        iconTheme: const IconThemeData(color: Colors.black),
        useMaterial3: true,
        primarySwatch: Colors.teal,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(fontSizeFactor: 0.9,),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
    );
  }
}

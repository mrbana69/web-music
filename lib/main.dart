import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/audio_handler.dart';
import 'providers/player_state.dart';
import 'providers/library_state.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar & navigation bar for iOS and Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Storage & API Services
  final storageService = await StorageService.init();
  final apiService = ApiService(storageService);

  // Initialize Native Audio Service for iOS Background & Lock Screen Playback
  final audioHandler = await initAudioService(apiService, storageService);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<PlayerState>(
          create: (_) => PlayerState(audioHandler as PreludedAudioHandler, apiService),
        ),
        ChangeNotifierProvider<LibraryState>(
          create: (_) => LibraryState(storageService),
        ),
      ],
      child: const PreludedMusicApp(),
    ),
  );
}

class PreludedMusicApp extends StatelessWidget {
  const PreludedMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preluded',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

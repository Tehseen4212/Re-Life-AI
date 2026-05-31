import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables. In production, this might fail if not present.
  // We wrap in try-catch to allow the app to boot even if .env is missing.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file. Falling back to empty strings.");
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://nbmparowweqnanqzkdri.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ibXBhcm93d2VxbmFucXprZHJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwOTE0MDUsImV4cCI6MjA5MTY2NzQwNX0.fUDCRQjYc4KRP--shV1xWpGezOkgJQrq0tXhMyXE61U';

  // Always initialize Supabase to prevent StateErrors when trying to access Supabase.instance.client
  // We use the loaded URL or the fallback URL. Network requests might fail if fallback is used, but the app UI will load.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const RelifeAIApp(),
    ),
  );
}

class RelifeAIApp extends StatefulWidget {
  const RelifeAIApp({super.key});

  @override
  State<RelifeAIApp> createState() => _RelifeAIAppState();
}

class _RelifeAIAppState extends State<RelifeAIApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Relife AI',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

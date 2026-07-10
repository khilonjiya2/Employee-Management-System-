import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/network/connectivity_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/local_database.dart';
import 'data/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: ErrorWidget.builder below fixes the "blank screen on first
  // login" class of bugs — without it, any error thrown while a widget is
  // building (missing linked record on a freshly-created account, a null
  // profile field, a transient network hiccup right after login, etc.)
  // renders as a bare grey screen in release builds. Now it shows a
  // friendly, recoverable screen everywhere in the app instead.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Widget build error: ${details.exception}');
    return _InlineErrorScreen(error: details.exceptionAsString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled Error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  try {
    await dotenv.load(fileName: '.env');

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL missing in .env');
    }

    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY missing in .env');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );

    final localDb = LocalDatabase();
    await localDb.init();

    runApp(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(localDb),
        ],
        child: const AppRoot(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Initialization Error: $e');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FatalStartupErrorScreen(error: e.toString()),
      ),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(connectivityServiceProvider);

    return MaterialApp.router(
      title: 'EMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

/// Friendly fallback rendered by [ErrorWidget.builder] whenever a widget
/// throws while building, anywhere in the app. Prevents the default
/// bare/blank grey box (Flutter's release-mode default) that users were
/// seeing as a "crash" or "blank screen" right after logging in.
class _InlineErrorScreen extends ConsumerWidget {
  final String error;
  const _InlineErrorScreen({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFFF5F6FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong loading this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reload'),
                onPressed: () {
                  // Re-fetch the profile instead of leaving the stale/failed
                  // state cached, then send the user back through the
                  // splash flow so the dashboard is rebuilt with fresh,
                  // fully-resolved data. This replaces the old "force close
                  // and reopen the app" workaround with an in-app fix.
                  ref.invalidate(currentProfileProvider);
                  GoRouter.of(context).go('/splash');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FatalStartupErrorScreen extends StatelessWidget {
  final String error;

  const FatalStartupErrorScreen({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Application Startup Failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: SystemNavigator.pop,
                  child: const Text('Close App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
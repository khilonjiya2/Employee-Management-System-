import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Minimum splash duration
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        context.go('/login');
        return;
      }

      // IMPORTANT — this is the fix for the "dashboard breaks on cold
      // start, works after a restart" bug: previously we routed to
      // /dashboard as soon as `currentSession` was non-null, without
      // waiting for the user's profile row to actually load.
      // `currentProfileProvider` runs exactly once and caches its result;
      // on a fresh launch, `client.auth.currentUser` can still be mid
      // hydration and the profile fetch can still be in flight. Sending
      // the router into /dashboard at that moment means every screen
      // downstream (MainShell, DashboardRouterWidget, the dashboards
      // themselves) reads a not-yet-ready profile and falls back to
      // undefined/mismatched role branches — which is what produced the
      // wrong bottom-nav + crash you were seeing. By awaiting the profile
      // here, /dashboard is only entered once real data is ready.
      try {
        await ref.read(currentProfileProvider.future);
      } catch (_) {
        // If profile loading itself fails, still proceed to /dashboard —
        // DashboardRouterWidget has its own error UI for that case. We
        // only needed to wait for it to settle, not to succeed.
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _retry() async {
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'EMS',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Startup Failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'An unexpected error occurred.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
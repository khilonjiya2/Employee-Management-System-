import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  final _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  ConnectivityNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    state = results.any((r) => r != ConnectivityResult.none);
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline != state) state = isOnline;
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Scaffold(
      body: child,
    );
  }
}
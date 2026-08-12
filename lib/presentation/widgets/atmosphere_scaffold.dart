import 'package:flutter/material.dart';

/// Soft nocturnal gradient backdrop used across communication screens.
class AtmosphereScaffold extends StatelessWidget {
  const AtmosphereScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0B1420),
                  Color(0xFF102033),
                  Color(0xFF0B1420),
                ]
              : const [
                  Color(0xFFF7FBFA),
                  Color(0xFFE8F1F0),
                  Color(0xFFF3F6F8),
                ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: child,
      ),
    );
  }
}

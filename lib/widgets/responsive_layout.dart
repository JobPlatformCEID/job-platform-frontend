import 'package:flutter/material.dart';

/// Responsive layout breakpoints.
///   mobile  < 600   → single column, bottom nav bar
///   tablet  600–1024 → rail nav + wider cards
///   desktop > 1024  → persistent left sidebar (240px) + content
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w <= 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > 1024;

  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }

  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 1200;
    if (isTablet(context)) return 900;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1024) return desktop;
        if (constraints.maxWidth >= 600) return tablet;
        return mobile;
      },
    );
  }
}

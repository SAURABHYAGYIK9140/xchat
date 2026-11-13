import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double mobileBreakpoint = 768.0;

  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }
}


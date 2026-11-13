import 'package:flutter/material.dart';

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final bool slideFromBottom;

  SlidePageRoute({
    required this.page,
    this.slideFromBottom = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = slideFromBottom ? const Offset(0.0, 0.08) : const Offset(0.08, 0.0);
            const end = Offset.zero;
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(begin: begin, end: end).animate(curve),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

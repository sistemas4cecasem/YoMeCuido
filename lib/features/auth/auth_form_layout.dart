import 'package:flutter/material.dart';

class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class CharacterImage extends StatelessWidget {
  const CharacterImage({
    required this.assetPath,
    required this.semanticLabel,
    this.height = 128,
    super.key,
  });

  final String assetPath;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Image.asset(
        assetPath,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

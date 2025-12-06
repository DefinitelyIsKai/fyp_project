import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final EdgeInsets? padding;

  const LoadingIndicator.standard({
    super.key,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = const CircularProgressIndicator(
      color: Color(0xFF00C8A0),
      strokeWidth: 4.0,
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: Center(child: indicator),
      );
    }

    return Center(child: indicator);
  }
}


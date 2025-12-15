import 'package:flutter/material.dart';

enum MessageBoxType {
  success,
  warning,
  info,
}


class MessageBox extends StatelessWidget {

  final String message;
  final MessageBoxType type;
  final Duration duration;
  final Color? backgroundColor;
  final Color? textColor;

  const MessageBox({
    super.key,
    required this.message,
    this.type = MessageBoxType.success,
    this.duration = const Duration(seconds: 3),
    this.backgroundColor,
    this.textColor,
  });

  Color get _getBackgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    
    switch (type) {
      case MessageBoxType.success:
        return const Color(0xFF00C8A0);
      case MessageBoxType.warning:
        return Colors.red;
      case MessageBoxType.info:
        return Colors.blue;
    }
  }

  Color get _getTextColor {
    return textColor ?? Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _getBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RichText(
        text: TextSpan(
          text: message,
          style: TextStyle(
            color: _getTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static void show({
    required BuildContext context,
    required String message,
    MessageBoxType type = MessageBoxType.success,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _MessageBoxOverlay(
        message: message,
        type: type,
        duration: duration,
        backgroundColor: backgroundColor,
        textColor: textColor,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );
    overlay.insert(overlayEntry);
  }
}

class _MessageBoxOverlay extends StatefulWidget {
  final String message;
  final MessageBoxType type;
  final Duration duration;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback onDismiss;

  const _MessageBoxOverlay({
    required this.message,
    required this.type,
    required this.duration,
    this.backgroundColor,
    this.textColor,
    required this.onDismiss,
  });

  @override
  State<_MessageBoxOverlay> createState() => _MessageBoxOverlayState();
}

class _MessageBoxOverlayState extends State<_MessageBoxOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: MessageBox(
            message: widget.message,
            type: widget.type,
            duration: widget.duration,
            backgroundColor: widget.backgroundColor,
            textColor: widget.textColor,
          ),
        ),
      ),
    );
  }
}


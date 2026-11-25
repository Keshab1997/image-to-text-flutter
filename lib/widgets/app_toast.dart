import 'package:flutter/material.dart';

/// Toast duration contract from IMPLEMENTATION_SPEC.md §2.4:
/// - short ≈ 2 s
/// - long  ≈ 3.5 s
enum ToastLength {
  short(Duration(milliseconds: 2000)),
  long(Duration(milliseconds: 3500));

  const ToastLength(this.duration);
  final Duration duration;
}

/// Displays case- and punctuation-exact toast messages via [ScaffoldMessenger].
class AppToast {
  const AppToast._();

  static void showShort(BuildContext context, String message) {
    show(context, message, length: ToastLength.short);
  }

  static void showLong(BuildContext context, String message) {
    show(context, message, length: ToastLength.long);
  }

  static void show(
    BuildContext context,
    String message, {
    ToastLength length = ToastLength.short,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: ValueKey<String>('toast:$message'),
        duration: length.duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        content: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB388FF),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

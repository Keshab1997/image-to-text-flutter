import 'dart:io';

import 'package:flutter/material.dart';

/// Gate for the app's decorative motion.
///
/// A perpetual animation never lets the scheduler go idle, so `pumpAndSettle`
/// would hang forever in a widget test. Tests therefore run the app still.
/// The same switch honours the OS "remove animations" accessibility setting, so
/// someone who asked for less motion gets a static UI rather than a busy one.
class AppMotion {
  const AppMotion._();

  static bool _inTest() {
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      // Platform.environment is unavailable on web.
      return false;
    }
  }

  /// True when decorative animation should run.
  static bool enabled(BuildContext context) {
    if (_inTest()) return false;
    final media = MediaQuery.maybeOf(context);
    if (media != null && media.disableAnimations) return false;
    return true;
  }
}

/// The scan viewfinder: corner brackets, an AUTO pill and a laser line that
/// sweeps up and down. The line is the app's "it is working" tell, so it is the
/// one place that is allowed to move on its own.
class AnimatedScanFrame extends StatefulWidget {
  const AnimatedScanFrame({
    super.key,
    required this.title,
    required this.caption,
    this.icon = Icons.description_outlined,
    this.badge,
  });

  final String title;
  final String caption;
  final IconData icon;
  final String? badge;

  @override
  State<AnimatedScanFrame> createState() => _AnimatedScanFrameState();
}

class _AnimatedScanFrameState extends State<AnimatedScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.enabled(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF232326), Color(0xFF17171A)]
              : const [Color(0xFFFBFBFC), Color(0xFFF1F1F3)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF35353B) : const Color(0xFFE4E4E7),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Corner brackets, drawn so their stroke weight stays identical at
            // any card size.
            Positioned.fill(
              child: CustomPaint(
                painter: _ScanBracketPainter(color: accent),
              ),
            ),
            // The sweeping laser.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final travel = constraints.maxHeight - 48;
                      final y = 24 + travel * _controller.value;
                      return Stack(
                        children: [
                          Positioned(
                            left: 16,
                            right: 16,
                            top: y,
                            child: _LaserLine(color: accent),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.badge != null)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    widget.badge!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: accent,
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 44,
                    color: isDark
                        ? const Color(0xFF8B8B94)
                        : const Color(0xFF9C9CA5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF4F4F5)
                          : const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.caption,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF8B8B94)
                          : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One frame of the laser: a bright core with a soft, wide glow behind it.
class _LaserLine extends StatelessWidget {
  const _LaserLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.0),
                color.withValues(alpha: 0.16),
              ],
            ),
          ),
        ),
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.0),
                color,
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanBracketPainter extends CustomPainter {
  const _ScanBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 14.0;
    const arm = 26.0;
    const radius = 14.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = <List<Offset>>[
      // top-left
      [
        Offset(inset, inset + arm),
        Offset(inset, inset + radius),
        Offset(inset + arm, inset),
      ],
      // top-right
      [
        Offset(size.width - inset - arm, inset),
        Offset(size.width - inset, inset + radius),
        Offset(size.width - inset, inset + arm),
      ],
      // bottom-left
      [
        Offset(inset, size.height - inset - arm),
        Offset(inset, size.height - inset - radius),
        Offset(inset + arm, size.height - inset),
      ],
      // bottom-right
      [
        Offset(size.width - inset - arm, size.height - inset),
        Offset(size.width - inset, size.height - inset - radius),
        Offset(size.width - inset, size.height - inset - arm),
      ],
    ];

    for (final pts in corners) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      path.arcToPoint(pts[1], radius: const Radius.circular(radius));
      path.lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ScanBracketPainter old) => old.color != color;
}

/// Fades and lifts a child into place once, after a delay. Used to give a tab a
/// deliberate "settling" feel instead of everything appearing at once.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int index;
  final Duration duration;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (!AppMotion.enabled(context)) {
      // Jump straight to the settled state: tests assert on layout, not motion.
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 60 * widget.index);
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - _curve.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

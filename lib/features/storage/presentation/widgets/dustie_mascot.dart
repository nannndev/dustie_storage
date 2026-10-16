import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum DustieMood { idle, scanning, happy, sleeping }

class DustieMascot extends StatefulWidget {
  final double size;
  final DustieMood mood;
  final bool animate;

  const DustieMascot({
    super.key,
    this.size = 80,
    this.mood = DustieMood.idle,
    this.animate = true,
  });

  @override
  State<DustieMascot> createState() => _DustieMascotState();
}

class _DustieMascotState extends State<DustieMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DustieMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final floatOffset = widget.animate
            ? math.sin(_controller.value * math.pi) * 4.0
            : 0.0;
        final wobbleAngle = widget.mood == DustieMood.scanning
            ? math.sin(_controller.value * math.pi * 4) * 0.08
            : 0.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.rotate(
            angle: wobbleAngle,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _DustiePainter(
                mood: widget.mood,
                progress: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DustiePainter extends CustomPainter {
  final DustieMood mood;
  final double progress;

  _DustiePainter({required this.mood, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // Outer Glow / Aura
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.35));
    canvas.drawCircle(center, radius * 1.35, glowPaint);

    // Body (Fluffy Dust Ball)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFDDFB8A),
          const Color(0xFFB8F03C),
          const Color(0xFF7FB20F),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bodyPaint);

    // Cheeks (Cute Pink Blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.55);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.55, center.dy + radius * 0.15),
      radius * 0.16,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.55, center.dy + radius * 0.15),
      radius * 0.16,
      blushPaint,
    );

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF101400);
    final sparkPaint = Paint()..color = Colors.white;

    final leftEyeCenter = Offset(
      center.dx - radius * 0.32,
      center.dy - radius * 0.1,
    );
    final rightEyeCenter = Offset(
      center.dx + radius * 0.32,
      center.dy - radius * 0.1,
    );
    final eyeRadius = radius * 0.22;

    if (mood == DustieMood.sleeping) {
      final arcPaint = Paint()
        ..color = const Color(0xFF101400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: leftEyeCenter, radius: eyeRadius * 0.8),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        arcPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: rightEyeCenter, radius: eyeRadius * 0.8),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        arcPaint,
      );
    } else {
      canvas.drawCircle(leftEyeCenter, eyeRadius, eyePaint);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyePaint);

      final gazeOffset = mood == DustieMood.scanning
          ? Offset(math.sin(progress * math.pi * 2) * 3, 0)
          : const Offset(0, 1);

      canvas.drawCircle(
        leftEyeCenter + gazeOffset,
        eyeRadius * 0.65,
        pupilPaint,
      );
      canvas.drawCircle(
        rightEyeCenter + gazeOffset,
        eyeRadius * 0.65,
        pupilPaint,
      );

      canvas.drawCircle(
        leftEyeCenter + gazeOffset - const Offset(2.5, 2.5),
        eyeRadius * 0.26,
        sparkPaint,
      );
      canvas.drawCircle(
        rightEyeCenter + gazeOffset - const Offset(2.5, 2.5),
        eyeRadius * 0.26,
        sparkPaint,
      );
    }

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF101400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (mood == DustieMood.happy) {
      final mouthPath = Path();
      mouthPath.moveTo(center.dx - radius * 0.18, center.dy + radius * 0.25);
      mouthPath.quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.45,
        center.dx + radius * 0.18,
        center.dy + radius * 0.25,
      );
      canvas.drawPath(mouthPath, mouthPaint);
    } else {
      final mouthPath = Path();
      mouthPath.moveTo(center.dx - radius * 0.12, center.dy + radius * 0.26);
      mouthPath.quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.35,
        center.dx + radius * 0.12,
        center.dy + radius * 0.26,
      );
      canvas.drawPath(mouthPath, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustiePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.mood != mood;
  }
}

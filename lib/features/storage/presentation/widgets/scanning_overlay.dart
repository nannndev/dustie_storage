import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'dustie_mascot.dart';

/// Full-area scanning screen: a rotating 3D particle globe with a sweeping scan beam.
class ScanningOverlay extends StatefulWidget {
  final String statusMessage;
  final VoidCallback onCancel;

  const ScanningOverlay({
    super.key,
    required this.statusMessage,
    required this.onCancel,
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  final Stopwatch _stopwatch = Stopwatch()..start();
  // Lives in this State, so each new scan starts full-screen again
  bool _minimized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _elapsed {
    final s = _stopwatch.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _minimized ? _buildPill() : _buildFull(),
    );
  }

  /// Small floating card so tabs stay usable while the scan keeps running.
  Widget _buildPill() {
    return Align(
      key: const ValueKey('pill'),
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Material(
          color: AppColors.bgCard,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _minimized = false),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GlobePainter(
                          _controller,
                          isDark: AppColors.isDark,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (_, _) => Text(
                          'Scanning... $_elapsed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Showing previous results until done',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Expand',
                    icon: Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _minimized = false),
                  ),
                  IconButton(
                    tooltip: 'Stop Scan',
                    icon: Icon(
                      Icons.stop_circle_rounded,
                      size: 20,
                      color: AppColors.danger,
                    ),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFull() {
    return Container(
      key: const ValueKey('full'),
      color: AppColors.bgDark.withValues(alpha: 0.94),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 340,
              height: 340,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GlobePainter(
                          _controller,
                          isDark: AppColors.isDark,
                        ),
                      ),
                    ),
                  ),
                  const DustieMascot(size: 72, mood: DustieMood.scanning),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dustie is sniffing your files...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                widget.statusMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Text(
                _elapsed,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => setState(() => _minimized = true),
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                  label: const Text('Run in Background'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.stop_circle_rounded, size: 18),
                  label: const Text('Stop Scan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final Animation<double> anim;
  final bool isDark;
  final bool compact;

  _GlobePainter(this.anim, {required this.isDark, this.compact = false})
    : super(repaint: anim);

  static const _palette = [
    AppColors.catInstaller,
    AppColors.catImage,
    AppColors.catCode,
    AppColors.catAudio,
    AppColors.catDocument,
    AppColors.catArchive,
    AppColors.catVideo,
  ];

  // Fibonacci sphere: evenly spread unit-sphere points, computed once.
  static final List<List<double>> _points = List.generate(320, (i) {
    const n = 320;
    final y = 1 - (i / (n - 1)) * 2;
    final r = math.sqrt(1 - y * y);
    final theta = math.pi * (3 - math.sqrt(5)) * i;
    return [math.cos(theta) * r, y, math.sin(theta) * r];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2 * math.pi;
    final c = size.center(Offset.zero);
    final radius = size.shortestSide * (compact ? 0.46 : 0.38);
    const tilt = 0.45;
    const camera = 3.2;
    // Beam sweeps from pole to pole in screen space
    final beamY = math.sin(t * 3);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.16),
          AppColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: radius * 1.5));
    canvas.drawCircle(c, radius * 1.5, glow);

    if (!compact) {
      _drawRing(canvas, c, radius * 1.25, t, 0.35);
      _drawRing(canvas, c, radius * 1.12, -t * 1.4, -0.6);
    }
    final dotScale = compact ? 0.4 : 1.0;

    final projected = <(Offset, double, double, Color)>[];
    final cy = math.cos(t), sy = math.sin(t);
    final cx = math.cos(tilt), sx = math.sin(tilt);
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      // Rotate around Y (spin) then X (tilt)
      final x1 = p[0] * cy + p[2] * sy;
      final z1 = -p[0] * sy + p[2] * cy;
      final y2 = p[1] * cx - z1 * sx;
      final z2 = p[1] * sx + z1 * cx;
      final scale = camera / (camera - z2);
      final depth = (z2 + 1) / 2; // 0 = back, 1 = front
      final hit = (y2 - beamY).abs() < 0.08;
      final color = hit
          ? (isDark ? Colors.white : AppColors.primaryDark)
          : _palette[i % _palette.length];
      projected.add((
        c + Offset(x1, y2) * radius * scale,
        depth,
        (hit ? 3.2 : 1.2 + depth * 2.2) * dotScale,
        color,
      ));
    }
    projected.sort((a, b) => a.$2.compareTo(b.$2));

    final dot = Paint();
    for (final (pos, depth, r, color) in projected) {
      dot.color = color.withValues(alpha: 0.15 + depth * 0.85);
      canvas.drawCircle(pos, r, dot);
    }

    final beamPx = c.dy + beamY * radius;
    final halfW = radius * math.sqrt(math.max(0, 1 - beamY * beamY)) * 1.1;
    canvas.drawLine(
      Offset(c.dx - halfW, beamPx),
      Offset(c.dx + halfW, beamPx),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primaryLight.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawRing(Canvas canvas, Offset c, double r, double spin, double tilt) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 2,
      height: r * 0.5,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.primary.withValues(alpha: 0.25),
    );
    // Satellite riding the ring
    final sat = Offset(math.cos(spin) * r, math.sin(spin) * r * 0.25);
    canvas.drawCircle(sat, 4, Paint()..color = AppColors.primaryLight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.isDark != isDark || old.compact != compact;
}

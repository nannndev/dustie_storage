import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/scan_progress.dart';
import 'dustie_mascot.dart';

/// Full-area scanning screen: Dustie vacuums up file "dust" coloured by what the scan is finding.
class ScanningOverlay extends StatefulWidget {
  final ScanProgress? progress;
  final VoidCallback onCancel;

  const ScanningOverlay({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final Stopwatch _stopwatch = Stopwatch()..start();
  // Lives in this State, so each new scan starts full-screen again
  bool _minimized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting: keep the scene, drop the movement.
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduce && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _elapsed {
    final s = _stopwatch.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Share of bytes found so far per category; uniform until anything is found.
  List<double> get _mix {
    final p = widget.progress;
    if (p == null || p.bytes == 0) {
      return List.filled(
        FileCategory.values.length,
        1 / FileCategory.values.length,
      );
    }
    return [for (final b in p.categoryBytes) b / p.bytes];
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
    final p = widget.progress;
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
                  const DustieMascot(size: 40, mood: DustieMood.scanning),
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
                          p == null
                              ? 'Showing previous results until done'
                              : '${FileSizeFormatter.formatCount(p.fileCount)} files • ${FileSizeFormatter.format(p.bytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 200,
                        child: _CategoryBar(mix: _mix, height: 4),
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
    final p = widget.progress;
    final secs = _stopwatch.elapsedMilliseconds / 1000;
    final rate = p == null || secs < 1 ? 0 : p.fileCount / secs;

    return Container(
      key: const ValueKey('full'),
      color: AppColors.bgDark.withValues(alpha: 0.95),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _SuctionPainter(
                              _controller,
                              mix: _mix,
                              isDark: AppColors.isDark,
                            ),
                          ),
                        ),
                      ),
                      const DustieMascot(size: 92, mood: DustieMood.scanning),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dustie is vacuuming up your files...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat(
                      label: 'Files',
                      value: FileSizeFormatter.formatCount(p?.fileCount ?? 0),
                    ),
                    _Stat(
                      label: 'Found',
                      value: FileSizeFormatter.format(p?.bytes ?? 0),
                      highlight: true,
                    ),
                    _Stat(
                      label: 'Per second',
                      value: FileSizeFormatter.formatCount(rate.round()),
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) =>
                          _Stat(label: 'Elapsed', value: _elapsed),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _CategoryBar(mix: _mix, height: 10),
                const SizedBox(height: 10),
                _CategoryLegend(progress: p),
                const SizedBox(height: 14),
                Text(
                  p?.currentPath ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => setState(() => _minimized = true),
                      icon: const Icon(
                        Icons.close_fullscreen_rounded,
                        size: 18,
                      ),
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
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                // Tabular digits stop the numbers jittering as they tick up.
                fontFeatures: const [FontFeature.tabularFigures()],
                color: highlight
                    ? AppColors.primaryLight
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The "dust bag": one stacked bar showing what the scan is made of so far.
class _CategoryBar extends StatelessWidget {
  final List<double> mix;
  final double height;

  const _CategoryBar({required this.mix, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final c in FileCategory.values)
              if (mix[c.index] > 0)
                Expanded(
                  // Flex needs ints; 1000 keeps sub-percent slices visible.
                  flex: math.max(1, (mix[c.index] * 1000).round()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: c.color,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  final ScanProgress? progress;

  const _CategoryLegend({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null || p.bytes == 0) return const SizedBox(height: 18);
    final top = FileCategory.values.where((c) => p.bytesOf(c) > 0).toList()
      ..sort((a, b) => p.bytesOf(b).compareTo(p.bytesOf(a)));

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final c in top.take(5))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${c.label} ${FileSizeFormatter.format(p.bytesOf(c))}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}

/// File "dust" spiralling into Dustie. Colours follow the live category mix.
class _SuctionPainter extends CustomPainter {
  final Animation<double> anim;
  final List<double> mix;
  final bool isDark;

  _SuctionPainter(this.anim, {required this.mix, required this.isDark})
    : super(repaint: anim);

  static const _count = 90;

  // Per-particle constants, computed once: start angle, speed, size, colour roll.
  static final List<(double, double, double, double)> _seeds = () {
    final rnd = math.Random(7);
    return List.generate(
      _count,
      (_) => (
        rnd.nextDouble() * 2 * math.pi,
        0.8 + rnd.nextDouble() * 0.7,
        1.6 + rnd.nextDouble() * 2.4,
        rnd.nextDouble(),
      ),
    );
  }();

  Color _pick(double roll) {
    var acc = 0.0;
    for (final c in FileCategory.values) {
      acc += mix[c.index];
      if (roll <= acc) return c.color;
    }
    return FileCategory.other.color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.62;
    final innerR = 30.0; // Dustie's mouth, roughly

    // Soft suction glow behind Dustie
    canvas.drawCircle(
      c,
      maxR * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.30 : 0.18),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.7)),
    );

    final dot = Paint();
    final trail = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _count; i++) {
      final (angle0, speed, radius, roll) = _seeds[i];
      // phase 0 = spawned at the edge, 1 = swallowed
      final phase = (anim.value * speed * 2 + i / _count) % 1.0;
      final eased = Curves.easeIn.transform(phase);
      final r = innerR + (maxR - innerR) * (1 - eased);
      // Swirl tightens as particles approach, like a real vortex.
      final angle = angle0 + eased * 2.4;
      final pos = c + Offset(math.cos(angle), math.sin(angle) * 0.75) * r;

      final fadeIn = (phase / 0.15).clamp(0.0, 1.0);
      final fadeOut = ((1 - phase) / 0.12).clamp(0.0, 1.0);
      final alpha = fadeIn * fadeOut;
      final color = _pick(roll);
      final s = radius * (0.5 + 0.5 * (1 - eased));

      // Short motion trail pointing back along the path
      final prevAngle = angle - 0.12;
      final prevR = r + (maxR - innerR) * 0.05;
      final prev =
          c + Offset(math.cos(prevAngle), math.sin(prevAngle) * 0.75) * prevR;
      trail
        ..color = color.withValues(alpha: alpha * 0.35)
        ..strokeWidth = s * 1.2;
      canvas.drawLine(prev, pos, trail);

      dot.color = color.withValues(alpha: alpha);
      canvas.drawCircle(pos, s, dot);
    }
  }

  @override
  bool shouldRepaint(_SuctionPainter old) =>
      old.isDark != isDark || !_sameMix(old.mix, mix);

  static bool _sameMix(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.001) return false;
    }
    return true;
  }
}

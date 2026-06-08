import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<List<Color>> _palette = [
    [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    [Color(0xFF1A1A4E), Color(0xFF3B2667), Color(0xFF0D1B2A)],
    [Color(0xFF0D1B2A), Color(0xFF022F74), Color(0xFF1A1A4E)],
    [Color(0xFF24243E), Color(0xFF302B63), Color(0xFF0F0C29)],
  ];

  static const List<List<Alignment>> _alignments = [
    [Alignment.topLeft,    Alignment.bottomRight],
    [Alignment.topRight,   Alignment.bottomLeft],
    [Alignment.topCenter,  Alignment.bottomCenter],
    [Alignment.centerLeft, Alignment.centerRight],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double t = _controller.value * (_palette.length - 1);
          final int idx = t.floor().clamp(0, _palette.length - 2);
          final double f = Curves.easeInOut.transform(t - idx);

          final colors = List.generate(
            3,
                (i) => Color.lerp(_palette[idx][i], _palette[idx + 1][i], f)!,
          );

          final begin = AlignmentTween(
            begin: _alignments[idx][0],
            end:   _alignments[idx + 1][0],
          ).lerp(f);

          final end = AlignmentTween(
            begin: _alignments[idx][1],
            end:   _alignments[idx + 1][1],
          ).lerp(f);

          return Stack(
            children: [
              // Gradiente base
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: colors,
                  ),
                ),
              ),
              // Orbe primario
              CustomPaint(
                painter: _OrbPainter(
                  progress: _controller.value,
                  color: const Color(0xFF6366F1),
                ),
                child: const SizedBox.expand(),
              ),
              // Orbe secundario (desfasado)
              CustomPaint(
                painter: _OrbPainter(
                  progress: (_controller.value + 0.5) % 1.0,
                  color: const Color(0xFF8B5CF6),
                  scale: 0.6,
                ),
                child: const SizedBox.expand(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double scale;

  const _OrbPainter({
    required this.progress,
    required this.color,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double px = size.width * (0.2 + 0.6 * progress);
    final double py = size.height * _oscillate(progress);
    final double radius = size.width * 0.35 * scale;

    canvas.drawCircle(
      Offset(px, py),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: radius)),
    );
  }

  double _oscillate(double t) =>
      0.25 + 0.5 * (1 - Curves.easeInOut.transform((t * 2 - 1).abs()));

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.progress != progress || old.color != color;
}
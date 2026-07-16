import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Role‑specific design data
// ─────────────────────────────────────────────────────────────────────────────

class _RoleDesign {
  const _RoleDesign({
    required this.gradientStart,
    required this.gradientEnd,
    required this.accentColor,
    required this.headline,
    required this.subhead,
    required this.features,
    required this.icon,
  });
  final Color gradientStart;
  final Color gradientEnd;
  final Color accentColor;
  final String headline;
  final String subhead;
  final List<String> features;
  final IconData icon;
}

_RoleDesign _designFor(UserRole role) => switch (role) {
  UserRole.student => const _RoleDesign(
    gradientStart: Color(0xFF1A1A2E),
    gradientEnd: Color(0xFF2D3A8C),
    accentColor: Color(0xFF6C8CFF),
    headline: 'Your learning,\naccelerated.',
    subhead: 'Smart tools designed to help you master every exam.',
    features: [
      'Adaptive mock tests & analytics',
      'Video lessons with AI summaries',
      'Personalized study plans',
    ],
    icon: Icons.school_rounded,
  ),
  UserRole.teacher => const _RoleDesign(
    gradientStart: Color(0xFF1A1A2E),
    gradientEnd: Color(0xFF1A4A3A),
    accentColor: Color(0xFF6BE8A0),
    headline: 'Teaching operations,\nunified.',
    subhead: 'AI grading, classrooms, and student readiness in one workspace.',
    features: [
      'AI‑powered grading & feedback',
      'Classroom & syllabus management',
      'Real‑time student readiness',
    ],
    icon: Icons.co_present_rounded,
  ),
  UserRole.partner => const _RoleDesign(
    gradientStart: Color(0xFF1A1A2E),
    gradientEnd: Color(0xFF3D1A5C),
    accentColor: Color(0xFFBB86FC),
    headline: 'Manage your\norganization.',
    subhead: 'Enrollment, analytics, and admin tools at institutional scale.',
    features: [
      'Bulk enrollment & cohort management',
      'Organization‑wide analytics',
      'Streamlined admin controls',
    ],
    icon: Icons.business_rounded,
  ),
  UserRole.admin => const _RoleDesign(
    gradientStart: Color(0xFF1A1A2E),
    gradientEnd: Color(0xFF5C1A1A),
    accentColor: Color(0xFFFF6B6B),
    headline: 'Admin Control\nCenter.',
    subhead: 'Platform configuration and system‑wide analytics overview.',
    features: [
      'User & role management',
      'System‑wide analytics',
      'Platform configuration',
    ],
    icon: Icons.admin_panel_settings_rounded,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// AuthRoleChip — redesigned as informative mini‑card
// ─────────────────────────────────────────────────────────────────────────────

class AuthRoleChip extends StatefulWidget {
  const AuthRoleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<AuthRoleChip> createState() => _AuthRoleChipState();
}

class _AuthRoleChipState extends State<AuthRoleChip>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel
                ? OseeTheme.primary.withValues(alpha: 0.06)
                : _hovered
                    ? OseeTheme.surfaceVariant
                    : OseeTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel
                  ? OseeTheme.primary
                  : _hovered
                      ? OseeTheme.textMuted.withValues(alpha: 0.4)
                      : OseeTheme.border,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: OseeTheme.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sel
                      ? OseeTheme.primary
                      : OseeTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: sel ? Colors.white : OseeTheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? OseeTheme.primary : OseeTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: OseeTheme.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Particles — animated decorative background
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 2 + rng.nextDouble() * 4,
        speed = 0.15 + rng.nextDouble() * 0.35,
        opacity = 0.08 + rng.nextDouble() * 0.18;
  double x, y, radius, speed, opacity;
}

class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key, required this.color, this.count = 30});
  final Color color;
  final int count;

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(widget.count, (_) => _Particle(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            color: widget.color,
            progress: _ctrl.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.progress,
  });
  final List<_Particle> particles;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final x = p.x + math.sin(y * math.pi * 2 + p.speed * 10) * 0.03;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.radius,
        Paint()..color = color.withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Role‑specific Illustrations via CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, required this.role, this.size = 220});
  final UserRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: switch (role) {
          UserRole.student => _StudentIllustrationPainter(),
          UserRole.teacher => _TeacherIllustrationPainter(),
          UserRole.partner => _InstitutionIllustrationPainter(),
          UserRole.admin => _AdminIllustrationPainter(),
        },
      ),
    );
  }
}

// --- Student: Open book + graduation cap + progress chart
class _StudentIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = const Color(0xFF6C8CFF);
    final accentLight = accent.withValues(alpha: 0.3);

    // --- Open book ---
    final bookPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final bookShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Book shadow
    final shadowPath = Path()
      ..moveTo(w * 0.15, h * 0.52)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.85, h * 0.52)
      ..lineTo(w * 0.85, h * 0.82)
      ..lineTo(w * 0.5, h * 0.76)
      ..lineTo(w * 0.15, h * 0.82)
      ..close();
    canvas.drawPath(shadowPath, bookShadow);

    // Left page
    final leftPage = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..lineTo(w * 0.50, h * 0.42)
      ..lineTo(w * 0.50, h * 0.74)
      ..lineTo(w * 0.18, h * 0.80)
      ..close();
    canvas.drawPath(leftPage, bookPaint);

    // Right page
    final rightPage = Path()
      ..moveTo(w * 0.50, h * 0.42)
      ..lineTo(w * 0.82, h * 0.50)
      ..lineTo(w * 0.82, h * 0.80)
      ..lineTo(w * 0.50, h * 0.74)
      ..close();
    canvas.drawPath(rightPage, bookPaint);

    // Book spine
    canvas.drawLine(
      Offset(w * 0.50, h * 0.42),
      Offset(w * 0.50, h * 0.74),
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );

    // Lines on left page
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      final y = h * (0.52 + i * 0.055);
      canvas.drawLine(
        Offset(w * 0.24, y),
        Offset(w * 0.46, y - (i * 0.01) * h),
        linePaint,
      );
    }

    // --- Graduation cap (top) ---
    final capPaint = Paint()..color = accent;
    // Cap top (diamond shape)
    final capPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.50, h * 0.30)
      ..lineTo(w * 0.28, h * 0.22)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Cap brim
    final brimPath = Path()
      ..moveTo(w * 0.28, h * 0.22)
      ..lineTo(w * 0.50, h * 0.30)
      ..lineTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.28, h * 0.26)
      ..close();
    canvas.drawPath(
      brimPath,
      Paint()..color = accent.withValues(alpha: 0.7),
    );

    final brimPath2 = Path()
      ..moveTo(w * 0.50, h * 0.30)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.72, h * 0.26)
      ..lineTo(w * 0.50, h * 0.34)
      ..close();
    canvas.drawPath(
      brimPath2,
      Paint()..color = accent.withValues(alpha: 0.5),
    );

    // Tassel
    canvas.drawLine(
      Offset(w * 0.72, h * 0.22),
      Offset(w * 0.78, h * 0.32),
      Paint()
        ..color = const Color(0xFFFFC107)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.33),
      3,
      Paint()..color = const Color(0xFFFFC107),
    );

    // --- Progress bars (bottom-right) ---
    final barBg = Paint()..color = Colors.white.withValues(alpha: 0.15);
    final barFill = Paint()..color = accentLight;
    for (int i = 0; i < 3; i++) {
      final y = h * (0.86 + i * 0.035);
      final barW = w * (0.15 + i * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.60, y, w * 0.25, 4),
          const Radius.circular(2),
        ),
        barBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.60, y, barW, 4),
          const Radius.circular(2),
        ),
        barFill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Teacher: Dashboard / whiteboard + AI brain symbol
class _TeacherIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = const Color(0xFF6BE8A0);
    final accentDim = accent.withValues(alpha: 0.4);

    // --- Whiteboard / Monitor ---
    final boardPaint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final boardBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.20, w * 0.70, h * 0.45),
      const Radius.circular(6),
    );
    canvas.drawRRect(boardRect, boardPaint);
    canvas.drawRRect(boardRect, boardBorder);

    // Stand
    canvas.drawLine(
      Offset(w * 0.45, h * 0.65),
      Offset(w * 0.45, h * 0.72),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(w * 0.55, h * 0.65),
      Offset(w * 0.55, h * 0.72),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(w * 0.35, h * 0.72),
      Offset(w * 0.65, h * 0.72),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );

    // --- Chart bars inside board ---
    final barColors = [
      accent.withValues(alpha: 0.7),
      accent.withValues(alpha: 0.5),
      accent,
      accent.withValues(alpha: 0.6),
      accent.withValues(alpha: 0.85),
    ];
    final barHeights = [0.18, 0.12, 0.28, 0.15, 0.22];
    for (int i = 0; i < 5; i++) {
      final x = w * (0.24 + i * 0.11);
      final barH = h * barHeights[i];
      final barY = h * 0.58 - barH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, barY, w * 0.07, barH),
          const Radius.circular(2),
        ),
        Paint()..color = barColors[i],
      );
    }

    // --- AI Brain icon (top-left) ---
    final brainCenter = Offset(w * 0.25, h * 0.10);
    // Outer glow
    canvas.drawCircle(
      brainCenter,
      18,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      brainCenter,
      12,
      Paint()..color = accent.withValues(alpha: 0.25),
    );
    // Brain nodes
    final nodePaint = Paint()..color = accent;
    final nodePositions = [
      Offset(w * 0.25, h * 0.06),
      Offset(w * 0.30, h * 0.09),
      Offset(w * 0.20, h * 0.09),
      Offset(w * 0.28, h * 0.14),
      Offset(w * 0.22, h * 0.14),
    ];
    final linePaint = Paint()
      ..color = accentDim
      ..strokeWidth = 1;
    for (int i = 0; i < nodePositions.length; i++) {
      for (int j = i + 1; j < nodePositions.length; j++) {
        canvas.drawLine(nodePositions[i], nodePositions[j], linePaint);
      }
    }
    for (final pos in nodePositions) {
      canvas.drawCircle(pos, 3, nodePaint);
    }

    // --- Checkmarks (bottom) ---
    final checkPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final cx = w * (0.30 + i * 0.16);
      final cy = h * 0.82;
      // Checkbox
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 8, cy - 8, 16, 16),
          const Radius.circular(3),
        ),
        Paint()
          ..color = i < 2
              ? accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill,
      );
      if (i < 2) {
        final path = Path()
          ..moveTo(cx - 4, cy)
          ..lineTo(cx - 1, cy + 3)
          ..lineTo(cx + 5, cy - 4);
        canvas.drawPath(path, checkPaint);
      }
      // Label line
      canvas.drawLine(
        Offset(cx + 14, cy),
        Offset(cx + 14 + w * 0.08, cy),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Institution: Building + analytics chart + network nodes
class _InstitutionIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = const Color(0xFFBB86FC);
    final accentDim = accent.withValues(alpha: 0.3);

    // --- Building ---
    final buildingPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    final buildingBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Main building
    final mainBuilding = Rect.fromLTWH(w * 0.30, h * 0.25, w * 0.40, h * 0.50);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mainBuilding, const Radius.circular(4)),
      buildingPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mainBuilding, const Radius.circular(4)),
      buildingBorder,
    );

    // Roof triangle
    final roofPath = Path()
      ..moveTo(w * 0.25, h * 0.25)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.75, h * 0.25)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = accent.withValues(alpha: 0.3));
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Windows grid (3x3)
    final windowPaint = Paint()..color = accent.withValues(alpha: 0.35);
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final wx = w * (0.36 + col * 0.11);
        final wy = h * (0.32 + row * 0.13);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(wx, wy, w * 0.07, h * 0.08),
            const Radius.circular(2),
          ),
          windowPaint,
        );
      }
    }

    // Door
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.44, h * 0.60, w * 0.12, h * 0.15),
        const Radius.circular(2),
      ),
      Paint()..color = accent.withValues(alpha: 0.5),
    );

    // --- Network nodes (right side) ---
    final nodePositions = [
      Offset(w * 0.82, h * 0.20),
      Offset(w * 0.90, h * 0.35),
      Offset(w * 0.78, h * 0.45),
      Offset(w * 0.88, h * 0.55),
    ];
    final nodeConnections = [
      [0, 1],
      [1, 2],
      [2, 3],
      [0, 2],
      [1, 3],
    ];
    for (final conn in nodeConnections) {
      canvas.drawLine(
        nodePositions[conn[0]],
        nodePositions[conn[1]],
        Paint()
          ..color = accentDim
          ..strokeWidth = 1,
      );
    }
    for (int i = 0; i < nodePositions.length; i++) {
      canvas.drawCircle(
        nodePositions[i],
        i == 0 ? 6 : 4,
        Paint()..color = accent.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        nodePositions[i],
        i == 0 ? 6 : 4,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // --- Mini chart (bottom-left) ---
    final chartPoints = [
      Offset(w * 0.08, h * 0.88),
      Offset(w * 0.14, h * 0.82),
      Offset(w * 0.20, h * 0.85),
      Offset(w * 0.26, h * 0.78),
    ];
    final chartPath = Path()..moveTo(chartPoints[0].dx, chartPoints[0].dy);
    for (final pt in chartPoints.skip(1)) {
      chartPath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      chartPath,
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final pt in chartPoints) {
      canvas.drawCircle(pt, 3, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Admin: Shield + gear + system graph
class _AdminIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = const Color(0xFFFF6B6B);

    // Shield
    final shieldPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.72, h * 0.22)
      ..quadraticBezierTo(w * 0.70, h * 0.55, w * 0.50, h * 0.68)
      ..quadraticBezierTo(w * 0.30, h * 0.55, w * 0.28, h * 0.22)
      ..close();
    canvas.drawPath(
      shieldPath,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Gear inside shield
    final gearCenter = Offset(w * 0.50, h * 0.38);
    canvas.drawCircle(
      gearCenter,
      14,
      Paint()..color = accent.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      gearCenter,
      8,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Gear teeth
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        Offset(
          gearCenter.dx + math.cos(angle) * 10,
          gearCenter.dy + math.sin(angle) * 10,
        ),
        Offset(
          gearCenter.dx + math.cos(angle) * 16,
          gearCenter.dy + math.sin(angle) * 16,
        ),
        Paint()
          ..color = accent
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // System graph bars (bottom)
    for (int i = 0; i < 5; i++) {
      final x = w * (0.25 + i * 0.11);
      final barH = h * (0.08 + (i % 3) * 0.04);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.82 - barH, w * 0.07, barH),
          const Radius.circular(2),
        ),
        Paint()..color = accent.withValues(alpha: 0.3 + (i % 3) * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Bullet — list item for brand panel
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.text, required this.accentColor});
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.check_rounded, size: 14, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthBrandPanel — premium gradient panel with illustration & features
// ─────────────────────────────────────────────────────────────────────────────

class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final design = _designFor(role);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [design.gradientStart, design.gradientEnd],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: design.gradientEnd.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Floating particles background
            Positioned.fill(
              child: FloatingParticles(color: design.accentColor),
            ),

            // Decorative gradient orb (top-right)
            Positioned(
              top: -40,
              right: -40,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      design.accentColor.withValues(alpha: 0.15),
                      design.accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: design.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: design.accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: design.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'OSEE',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),

                  // Center: Headline + Illustration + Features
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Illustration
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        ),
                        child: AuthIllustration(
                          key: ValueKey('illust_${role.name}'),
                          role: role,
                          size: 200,
                        ),
                      ),

                      const SizedBox(height: Spacing.xl),

                      // Headline
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey('text_${role.name}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              design.headline,
                              style: GoogleFonts.inter(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              design.subhead,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: Spacing.lg),

                            // Feature bullets
                            ...design.features.map(
                              (f) => _FeatureBullet(
                                text: f,
                                accentColor: design.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Footer
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 2,
                        decoration: BoxDecoration(
                          color: design.accentColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Official ETS Test Center since 2014',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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

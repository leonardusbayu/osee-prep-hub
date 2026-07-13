import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// OSEE shared UI components — Editorial SaaS Design System.
///
/// Design principles:
/// - Cards: radius 2, stark 1px border, completely flat (no shadow).
/// - Aesthetic: High-end education magazine / Enterprise SaaS.
/// - Spacing: Generous padding, strict grid (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48).
/// - Typography: Heavy contrast. Thick headings, tracking-wide uppercase labels.

// ---------- Spacing ----------

class Spacing {
  const Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ---------- Custom Buttons ----------

/// Sharp, flat, starkly contrasted button for Editorial SaaS aesthetic.
class SolidEditorialButton extends StatefulWidget {
  const SolidEditorialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = OseeTheme.primary,
    this.textColor = Colors.white,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final bool isFullWidth;

  @override
  State<SolidEditorialButton> createState() => _SolidEditorialButtonState();
}

class _SolidEditorialButtonState extends State<SolidEditorialButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDisabled 
                ? OseeTheme.border 
                : _isPressed 
                    ? widget.color.withValues(alpha: 0.8)
                    : _isHovered 
                        ? widget.color.withValues(alpha: 0.9)
                        : widget.color,
            borderRadius: BorderRadius.circular(2), // Sharp edges
            border: Border.all(
              color: isDisabled ? OseeTheme.border : widget.color, 
              width: 1
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: isDisabled ? OseeTheme.textMuted : widget.textColor,
                  size: 18,
                ),
                const SizedBox(width: Spacing.sm),
              ],
              Text(
                widget.label.toUpperCase(), // Force uppercase for editorial buttons
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDisabled ? OseeTheme.textMuted : widget.textColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Page structure ----------

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.color = OseeTheme.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(Spacing.xl), // Extra generous padding
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OseeTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.lg),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? OseeTheme.surface,
        borderRadius: BorderRadius.circular(2), // Sharp editorial style
        border: Border.all(color: borderColor ?? OseeTheme.border, width: 1),
        // Completely flat, no shadows.
      ),
      child: child,
    );
  }
}

// ---------- Section header ----------

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for magazine look
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Signature magazine kicker line
                Container(width: 32, height: 2, color: OseeTheme.danger),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: OseeTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ---------- Stat card ----------

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = OseeTheme.primary,
    this.trend,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OseeTheme.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: OseeTheme.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: OseeTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      trend!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              value,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: OseeTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Empty state ----------

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: OseeTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: OseeTheme.border),
              ),
              child: Icon(icon, size: 32, color: OseeTheme.textMuted),
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OseeTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (action != null) ...[
              const SizedBox(height: Spacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Error state ----------

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: OseeTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: OseeTheme.danger.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.error_outline,
                color: OseeTheme.danger,
                size: 24,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: OseeTheme.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Spacing.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RETRY'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Action tile (Flat, Hover-sensitive) ----------

class ActionTile extends StatefulWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = OseeTheme.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: _isHovered ? OseeTheme.surfaceVariant : OseeTheme.surface,
            border: Border.all(
              color: _isHovered ? OseeTheme.textMuted : OseeTheme.border,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title, 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              Icon(
                Icons.arrow_forward,
                color: _isHovered ? widget.color : OseeTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Loading state ----------

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OseeTheme.surface,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: OseeTheme.border),
            ),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: OseeTheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: Spacing.lg),
            Text(
              message!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- Info row ----------

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

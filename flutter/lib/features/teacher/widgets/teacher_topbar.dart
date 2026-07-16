import 'package:flutter/material.dart';

import '../teacher_theme.dart';

/// Teacher top bar — 76h, white, bottom border.
/// Contains: page title, optional search, New Upload CTA, notification +
/// message icons, avatar + dropdown, plus optional page [actions].
class TeacherTopbar extends StatelessWidget {
  const TeacherTopbar({
    super.key,
    this.onMenuTap,
    this.title = 'My Schedule',
    this.actions,
    this.bottom,
  });

  final VoidCallback? onMenuTap;
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isCompact = w < 840;
    final showSearch = w >= 1200;
    final showUploadBtn = w >= 840;
    final showNotifMsg = w >= 600;

    return Container(
      decoration: const BoxDecoration(
        color: TeacherTheme.surface,
        border: Border(bottom: BorderSide(color: TeacherTheme.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: TeacherSpacing.topbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TeacherSpacing.md,
              ),
              child: Row(
                children: [
                  if (isCompact)
                    IconButton(
                      icon: const Icon(Icons.menu_rounded,
                          color: TeacherTheme.textSecondary),
                      onPressed: onMenuTap,
                    ),
                  // Title left-aligned
                  Expanded(
                    child: Text(
                      title,
                      style: TeacherTheme.pageTitle(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  if (showSearch) ...[
                    const _SearchField(),
                    const SizedBox(width: 12),
                  ],
                  if (showUploadBtn) ...[
                    const _NewUploadButton(),
                    const SizedBox(width: 12),
                  ],
                  if (actions != null) ...[
                    ...actions!,
                    const SizedBox(width: 12),
                  ],
                  if (showNotifMsg) ...[
                    const _IconBadge(
                      icon: Icons.notifications_none_rounded,
                      count: 3,
                    ),
                    const SizedBox(width: 12),
                    const _IconBadge(icon: Icons.chat_bubble_outline_rounded),
                    const SizedBox(width: 12),
                  ],
                  const _ProfileChip(),
                ],
              ),
            ),
          ),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 38,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TeacherTheme.searchPlaceholder(),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: TeacherTheme.textMuted),
          filled: true,
          fillColor: const Color(0xFFF5F6FA),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TeacherTheme.radiusInput),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TeacherTheme.radiusInput),
            borderSide: const BorderSide(color: TeacherTheme.primaryBlue),
          ),
        ),
      ),
    );
  }
}

class _NewUploadButton extends StatelessWidget {
  const _NewUploadButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TeacherTheme.primaryBlueSoft,
      borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded,
                  size: 16, color: TeacherTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(
                'New',
                style: TeacherTheme.userName(TeacherTheme.primaryBlue)
                    .copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatefulWidget {
  const _IconBadge({required this.icon, this.count});
  final IconData icon;
  final int? count;

  @override
  State<_IconBadge> createState() => _IconBadgeState();
}

class _IconBadgeState extends State<_IconBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: TeacherTheme.animFast,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _hovered ? TeacherTheme.hoverBg : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(widget.icon, size: 22, color: TeacherTheme.textSecondary),
            if (widget.count != null)
              Positioned(
                right: 2,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: TeacherTheme.badgeDanger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatefulWidget {
  const _ProfileChip();

  @override
  State<_ProfileChip> createState() => _ProfileChipState();
}

class _ProfileChipState extends State<_ProfileChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
          child: AnimatedContainer(
            duration: TeacherTheme.animFast,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered ? TeacherTheme.backgroundSecondary : Colors.transparent,
              borderRadius: BorderRadius.circular(TeacherTheme.radiusButton),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: TeacherTheme.primaryBlueSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'JC',
                    style: TextStyle(
                      color: TeacherTheme.primaryBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: TeacherTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
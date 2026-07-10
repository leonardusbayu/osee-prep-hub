import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

export 'tokens.dart';
export 'typography.dart';

/// MagazineMasthead — title banner with gold rule + date.
/// Used at the top of pages to anchor them in the magazine aesthetic.
class MagazineMasthead extends StatelessWidget {
  const MagazineMasthead({
    super.key,
    required this.title,
    this.subtitle,
    this.date,
    this.kicker,
  });

  final String title;
  final String? subtitle;
  final String? date;
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MagazineSpacing.sm),
            child: Text(kicker!.toUpperCase(), style: magazineOverline()),
          ),
        Text(title, style: magazineDisplay()),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: MagazineSpacing.sm),
            child: Text(subtitle!, style: magazineBody()),
          ),
        const SizedBox(height: MagazineSpacing.md),
        Container(height: 1.5, color: MagazineColors.mastheadGold),
        if (date != null)
          Padding(
            padding: const EdgeInsets.only(top: MagazineSpacing.sm),
            child: Text(date!, style: magazineCaption()),
          ),
      ],
    );
  }
}

/// MagazineDropCap — first letter of a paragraph as a large drop cap.
class MagazineDropCap extends StatelessWidget {
  const MagazineDropCap({super.key, required this.text, this.capColor});

  final String text;
  final Color? capColor;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final firstChar = text.characters.first;
    final rest = text.substring(firstChar.length);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: firstChar,
            style: const TextStyle(
              fontSize: 56,
              height: 1.0,
              fontWeight: FontWeight.w800,
              fontFamily: 'Georgia',
              color: MagazineColors.mastheadGold,
            ).copyWith(color: capColor),
          ),
          TextSpan(text: ' ', style: const TextStyle(fontSize: 1)),
          TextSpan(
            text: rest,
            style: magazineBody(),
          ),
        ],
      ),
    );
  }
}

/// MagazineStat — large number + label (e.g., "2.3×", "completion rate").
class MagazineStat extends StatelessWidget {
  const MagazineStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: magazineDisplay()),
        const SizedBox(height: MagazineSpacing.xs),
        Text(label.toUpperCase(), style: magazineOverline()),
      ],
    );
  }
}

/// MagazineCard — content card with title, kicker, body.
class MagazineCard extends StatelessWidget {
  const MagazineCard({
    super.key,
    required this.title,
    required this.body,
    this.kicker,
    this.onTap,
    this.footer,
  });

  final String title;
  final String body;
  final String? kicker;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MagazineSpacing.base),
        decoration: BoxDecoration(
          color: MagazineColors.paperCream,
          borderRadius: BorderRadius.circular(MagazineRadius.none),
          border: Border.all(color: MagazineColors.mastheadGold.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kicker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: MagazineSpacing.sm),
                child: Text(kicker!.toUpperCase(), style: magazineOverline()),
              ),
            Text(title, style: magazineTitle()),
            const SizedBox(height: MagazineSpacing.sm),
            Text(body, style: magazineBody()),
            if (footer != null) ...[
              const SizedBox(height: MagazineSpacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

/// MagazineSectionRule — horizontal gold rule with optional label.
class MagazineSectionRule extends StatelessWidget {
  const MagazineSectionRule({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Container(height: 1.5, color: MagazineColors.mastheadGold);
    }
    return Row(
      children: [
        Container(width: 32, height: 1.5, color: MagazineColors.mastheadGold),
        const SizedBox(width: MagazineSpacing.sm),
        Text(label!.toUpperCase(), style: magazineOverline()),
        const SizedBox(width: MagazineSpacing.sm),
        const Expanded(child: Divider(color: MagazineColors.mastheadGold, thickness: 1.5, height: 1.5)),
      ],
    );
  }
}

/// MagazinePublishStamp — "APPROVED" / "DRAFT" stamp rotated 12°.
class MagazinePublishStamp extends StatelessWidget {
  const MagazinePublishStamp({
    super.key,
    required this.label,
    this.color,
    this.rotated = true,
  });

  final String label;
  final Color? color;
  final bool rotated;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotated ? 0.21 : 0, // ~12 degrees
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: MagazineSpacing.md, vertical: MagazineSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? MagazineColors.accentRed, width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'Georgia',
            color: color ?? MagazineColors.accentRed,
          ),
        ),
      ),
    );
  }
}

/// MagazineSidebar — vertical nav with serif labels.
class MagazineSidebar extends StatelessWidget {
  const MagazineSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelect,
  });

  final List<MagazineSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: MagazineSpacing.lg),
      decoration: const BoxDecoration(
        color: MagazineColors.paperCream,
        border: Border(right: BorderSide(color: MagazineColors.mastheadGold, width: 1.5)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _SidebarEntry(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onSelect?.call(i),
            ),
        ],
      ),
    );
  }
}

class _SidebarEntry extends StatelessWidget {
  const _SidebarEntry({required this.item, required this.selected, this.onTap});

  final MagazineSidebarItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MagazineSpacing.md, horizontal: MagazineSpacing.base),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(
            color: selected ? MagazineColors.mastheadGold : Colors.transparent,
            width: 3,
          )),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label.toUpperCase(), style: magazineOverline()),
            if (item.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.subtitle!, style: magazineCaption()),
              ),
          ],
        ),
      ),
    );
  }
}

class MagazineSidebarItem {
  const MagazineSidebarItem({required this.label, this.subtitle, this.icon});
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// MagazinePullQuote — large serif quote with rule.
class MagazinePullQuote extends StatelessWidget {
  const MagazinePullQuote({super.key, required this.quote, this.attribution});

  final String quote;
  final String? attribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MagazineSpacing.lg, horizontal: MagazineSpacing.base),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: MagazineColors.mastheadGold, width: 1.5),
          bottom: BorderSide(color: MagazineColors.mastheadGold, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            '"$quote"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 32 / 24,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
              color: MagazineColors.inkBlack,
            ),
          ),
          if (attribution != null)
            Padding(
              padding: const EdgeInsets.only(top: MagazineSpacing.md),
              child: Text(attribution!.toUpperCase(), style: magazineOverline()),
            ),
        ],
      ),
    );
  }
}

/// MagazineNumberBadge — circled number for step indicators.
class MagazineNumberBadge extends StatelessWidget {
  const MagazineNumberBadge({super.key, required this.number, this.size = 28});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: MagazineColors.mastheadGold, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          fontFamily: 'Georgia',
          color: MagazineColors.inkBlack,
        ),
      ),
    );
  }
}
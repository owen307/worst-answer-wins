import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class PartyBackground extends StatelessWidget {
  const PartyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PartyColors.cream,
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -70,
            child: _Blob(color: Color(0xFFFFD38A), size: 230),
          ),
          const Positioned(
            bottom: -110,
            left: -80,
            child: _Blob(color: Color(0xFFFFC1CC), size: 280),
          ),
          const Positioned(
            top: 220,
            left: -50,
            child: _Blob(color: Color(0xFFC8F6EF), size: 140),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: PartyColors.ink, width: 3),
        ),
      ),
    );
  }
}

class PartyMark extends StatelessWidget {
  const PartyMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 112,
      width: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _MarkCard(angle: -0.14, color: PartyColors.sun),
          _MarkCard(angle: 0.08, color: PartyColors.coral, label: '?!'),
        ],
      ),
    );
  }
}

class _MarkCard extends StatelessWidget {
  const _MarkCard({required this.angle, required this.color, this.label});

  final double angle;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: PartyColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: PartyColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: label == null
            ? null
            : Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

class PartyButton extends StatelessWidget {
  const PartyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = PartyColors.coral,
    this.foreground = Colors.white,
    this.busy = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final fill = outlined ? Colors.white : color;
    final textColor = outlined ? PartyColors.ink : foreground;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: enabled
            ? const [BoxShadow(color: PartyColors.ink, offset: Offset(4, 4))]
            : const [],
      ),
      child: Material(
        color: enabled ? fill : fill.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: PartyColors.ink, width: 3),
        ),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: textColor,
                        ),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: enabled
                              ? textColor
                              : textColor.withValues(alpha: 0.7),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PromptCard extends StatelessWidget {
  const PromptCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: PartyColors.grape,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PartyColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: PartyColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class CodeTiles extends StatelessWidget {
  const CodeTiles({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final letters = code.split('');
    return Semantics(
      label: 'Room code $code',
      child: Row(
        children: [
          for (final letter in letters)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AspectRatio(
                  aspectRatio: 0.86,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: PartyColors.ink, width: 3),
                      boxShadow: const [
                        BoxShadow(color: PartyColors.ink, offset: Offset(3, 3)),
                      ],
                    ),
                    child: FittedBox(
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({
    super.key,
    required this.name,
    required this.color,
    this.score,
    this.host = false,
    this.connected = true,
    this.badge,
  });

  final String name;
  final Color color;
  final int? score;
  final bool host;
  final bool connected;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final initial = _initial(name);
    return Opacity(
      opacity: connected ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PartyColors.ink, width: 3),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: PartyColors.ink, width: 3),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (host)
                    const Text(
                      'Host',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PartyColors.tangerine,
                      ),
                    ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              _Chip(label: badge!, color: PartyColors.cream),
            ],
            if (score != null) ...[
              const SizedBox(width: 8),
              _Chip(label: '$score', color: PartyColors.sun),
            ],
          ],
        ),
      ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PartyColors.ink, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.text,
    this.yours = false,
    this.selected = false,
    this.authorName,
    this.votes,
    this.highlight = false,
    this.onTap,
  });

  final String text;
  final bool yours;
  final bool selected;
  final String? authorName;
  final int? votes;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = highlight
        ? PartyColors.sun
        : selected
        ? const Color(0xFFE7FBF6)
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: PartyColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: selected ? PartyColors.mint : PartyColors.ink,
              width: 3,
            ),
          ),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  },
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlight && (votes ?? 0) > 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Crown this one',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (yours)
                          const _Chip(label: "That's yours", color: Color(0xFFE4DCFF)),
                        if (selected)
                          const _Chip(label: 'Your vote', color: PartyColors.mint),
                        if (authorName != null)
                          Text(
                            'by $authorName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (votes != null)
                          _Chip(
                            label: votes == 1 ? '+1 point' : '+$votes points',
                            color: PartyColors.sun,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartyColors.ink, width: 3),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class PhaseTitle extends StatelessWidget {
  const PhaseTitle({
    super.key,
    required this.kicker,
    required this.title,
  });

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PartyColors.tangerine,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

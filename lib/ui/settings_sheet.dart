import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// يسأل عن هدف اللعبة ومهلة الدور. يرجع null عند الإلغاء.
Future<GameSettings?> showGameSettingsSheet(
  BuildContext context, {
  required String confirmLabel,
}) {
  return showModalBottomSheet<GameSettings>(
    context: context,
    backgroundColor: AppColors.feltDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SettingsSheet(confirmLabel: confirmLabel),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.confirmLabel});
  final String confirmLabel;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  var _settings = const GameSettings();

  Widget _chips<T>({
    required String title,
    required List<T> values,
    required T current,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(label(v)),
                selected: v == current,
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(
                  color: v == current ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) => onSelected(v),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chips<int>(
            title: 'هدف اللعبة',
            values: const [51, 101],
            current: _settings.targetScore,
            label: (v) => '$v نقطة',
            onSelected: (v) => setState(() => _settings = _settings.copyWith(targetScore: v)),
          ),
          const SizedBox(height: 20),
          _chips<int>(
            title: 'مهلة كل دور',
            values: const [0, 15, 20, 30],
            current: _settings.turnSeconds,
            label: (v) => v == 0 ? 'بدون مؤقت' : '$v ثانية',
            onSelected: (v) => setState(() => _settings = _settings.copyWith(turnSeconds: v)),
          ),
          const SizedBox(height: 6),
          const Text(
            'لو انتهت مهلتك يلعب عنك البوت تلقائياً حتى ترجع تلعب.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 22),
          GoldButton(
            label: widget.confirmLabel,
            onPressed: () => Navigator.pop(context, _settings),
          ),
        ],
      ),
    );
  }
}

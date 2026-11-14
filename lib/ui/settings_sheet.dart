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
  bool _customTurn = false;
  bool _customMatch = false;

  Widget _stepper({
    required int value,
    required int minVal,
    required int maxVal,
    required int step,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withAlpha(110)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > minVal
                ? () => onChanged((value - step).clamp(minVal, maxVal))
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.goldLight),
          ),
          Text(
            '$value $unit',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.goldLight,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < maxVal
                ? () => onChanged((value + step).clamp(minVal, maxVal))
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.goldLight),
          ),
        ],
      ),
    );
  }

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(140),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _chips<int>(
              title: 'هدف اللعبة',
              values: const [51, 101],
              current: _settings.targetScore,
              label: (v) => '$v نقطة',
              onSelected: (v) => setState(() => _settings = _settings.copyWith(targetScore: v)),
            ),
            const SizedBox(height: 16),
            _chips<int>(
              title: 'مهلة كل دور',
              values: const [0, 15, 20, 30, -1],
              current: _customTurn ? -1 : _settings.turnSeconds,
              label: (v) => v == -1
                  ? 'مخصص'
                  : (v == 0 ? 'بدون مؤقت' : '$v ثانية'),
              onSelected: (v) => setState(() {
                if (v == -1) {
                  _customTurn = true;
                  if (_settings.turnSeconds == 0) {
                    _settings = _settings.copyWith(turnSeconds: 25);
                  }
                } else {
                  _customTurn = false;
                  _settings = _settings.copyWith(turnSeconds: v);
                }
              }),
            ),
            if (_customTurn)
              _stepper(
                value: _settings.turnSeconds == 0 ? 25 : _settings.turnSeconds,
                minVal: 5,
                maxVal: 90,
                step: 5,
                unit: 'ثانية',
                onChanged: (v) =>
                    setState(() => _settings = _settings.copyWith(turnSeconds: v)),
              ),
            const SizedBox(height: 16),
            _chips<int>(
              title: 'وقت المباراة',
              values: const [0, 5, 10, 15, -1],
              current: _customMatch ? -1 : _settings.matchMinutes,
              label: (v) {
                if (v == -1) return 'مخصص';
                if (v == 0) return 'مفتوح';
                return v <= 10 ? '$v دقائق' : '$v دقيقة';
              },
              onSelected: (v) => setState(() {
                if (v == -1) {
                  _customMatch = true;
                  if (_settings.matchMinutes == 0) {
                    _settings = _settings.copyWith(matchMinutes: 7);
                  }
                } else {
                  _customMatch = false;
                  _settings = _settings.copyWith(matchMinutes: v);
                }
              }),
            ),
            if (_customMatch)
              _stepper(
                value: _settings.matchMinutes == 0 ? 7 : _settings.matchMinutes,
                minVal: 1,
                maxVal: 120,
                step: 1,
                unit: 'دقيقة',
                onChanged: (v) =>
                    setState(() => _settings = _settings.copyWith(matchMinutes: v)),
              ),
            const SizedBox(height: 16),
            _chips<BotDifficulty>(
              title: 'مستوى البوتات',
              values: BotDifficulty.values,
              current: _settings.botDifficulty,
              label: (v) => v == BotDifficulty.pro ? 'محترف' : 'عادي',
              onSelected: (v) =>
                  setState(() => _settings = _settings.copyWith(botDifficulty: v)),
            ),
            const SizedBox(height: 6),
            const Text(
              'لو انتهت مهلتك يلعب عنك البوت تلقائياً حتى ترجع تلعب، ويمكنك إيقافه في أي لحظة.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            GoldButton(
              label: widget.confirmLabel,
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.pop(context, _settings),
            ),
          ],
        ),
      ),
    );
  }
}

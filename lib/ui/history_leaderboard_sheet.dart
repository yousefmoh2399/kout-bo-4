import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/connectivity_service.dart';
import '../core/theme.dart';
import '../data/stats_repository.dart';
import 'widgets.dart';

/// يعرض نافذة سجل المباريات السابقة المسجلة في قاعدة البيانات.
Future<void> showMatchHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.feltDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => const _MatchHistorySheet(),
  );
}

/// يعرض نافذة لوحة المتصدرين الحية من السيرفر.
Future<void> showLeaderboardSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.feltDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => const _LeaderboardSheet(),
  );
}

// ───────────────────────── سجل المباريات ─────────────────────────

class _MatchHistorySheet extends StatefulWidget {
  const _MatchHistorySheet();

  @override
  State<_MatchHistorySheet> createState() => _MatchHistorySheetState();
}

class _MatchHistorySheetState extends State<_MatchHistorySheet> {
  late Future<List<MatchHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatsRepository>().getMatchHistory(limit: 30);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, color: AppColors.goldLight, size: 22),
              SizedBox(width: 8),
              Text(
                'سجل المباريات المسجلة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!ConnectivityService.instance.isOnline)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33F59E0B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(140),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFFBBF24),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أنت في وضع الأوفلاين • سجل المباريات السحابي غير متصل، ومبارياتك الفردية تُحفظ محلياً.',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<MatchHistoryItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports_outlined, size: 48, color: Colors.white30),
                        SizedBox(height: 12),
                        Text(
                          'لا يوجد مباريات مسجلة بعد.\nالعب مباراة وستُحفظ نتيجتها تلقائياً في قاعدة البيانات!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final isWon = m.won;
                    final isOnline = m.gameMode == 'online';

                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isWon
                                  ? const Color(0x3348BB78)
                                  : const Color(0x33E53E3E),
                              border: Border.all(
                                color: isWon
                                    ? const Color(0xFF48BB78)
                                    : const Color(0xFFE53E3E),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isWon ? 'فوز' : 'خسارة',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isWon
                                    ? const Color(0xFF68D391)
                                    : const Color(0xFFFC8181),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOnline ? AppColors.gold.withAlpha(40) : Colors.white12,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOnline ? AppColors.gold.withAlpha(120) : Colors.white24,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isOnline ? 'أونلاين (${m.roomCode})' : 'ضد البوتات',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isOnline ? AppColors.goldLight : Colors.white70,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(m.createdAt),
                                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'فريقكم: ${m.scoreUs}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: isWon ? AppColors.goldLight : Colors.white70,
                                      ),
                                    ),
                                    const Text('  -  ', style: TextStyle(color: Colors.white30)),
                                    Text(
                                      'الخصوم: ${m.scoreThem}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: !isWon ? AppColors.danger : Colors.white70,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${m.rounds} جولات',
                                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── لوحة المتصدرين ─────────────────────────

class _LeaderboardSheet extends StatefulWidget {
  const _LeaderboardSheet();

  @override
  State<_LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<_LeaderboardSheet> {
  late Future<List<LeaderboardItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatsRepository>().getLeaderboard(limit: 50);
  }

  Widget _rankBadge(int rank) {
    if (rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 22));
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.goldLight, size: 24),
              SizedBox(width: 8),
              Text(
                'لوحة المتصدرين (Live)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!ConnectivityService.instance.isOnline)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33F59E0B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(140),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFFBBF24),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أنت في وضع الأوفلاين • لوحة المتصدرين الحية تتطلب اتصالاً بالإنترنت.',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<LeaderboardItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.leaderboard_outlined, size: 48, color: Colors.white30),
                        SizedBox(height: 12),
                        Text(
                          'لا يوجد متصدرين مسجلين بعد.\nكن أول من يفوز بمباراة ليتصدر القائمة!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final rank = i + 1;
                    final isTop3 = rank <= 3;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isTop3 ? AppColors.gold.withAlpha(20) : Colors.black.withAlpha(60),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isTop3 ? AppColors.gold.withAlpha(140) : Colors.white12,
                          width: isTop3 ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          _rankBadge(rank),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: isTop3 ? AppColors.goldLight : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'لعب ${item.gamesPlayed} • نسبة الفوز ${item.winRate}%',
                                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.wins} فوز',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF48BB78),
                                ),
                              ),
                              Text(
                                '${item.totalPoints} نقطة',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

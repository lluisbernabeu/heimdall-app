import 'package:flutter/material.dart';
import '../theme.dart';

/// Tarjeta de carrera — usada en home (pestaña Carreras) y pantalla Carreras.
/// Rediseño v10: logo del coche grande, badge de posición P#, etiquetas
/// RATING/SR y borde con color según resultado.
/// v17: semáforo de resultado — verde (buena), roja (mala), azul (neutra) —
/// según posiciones ganadas/perdidas, incidencias y abandono. El borde y el
/// chip de la tarjeta usan ese color; el badge P# conserva oro/cian para podio.
class RaceCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onTap;
  const RaceCard({super.key, required this.r, required this.onTap});

  /// Color del semáforo según el resultado de la carrera.
  /// 🟢 Verde: ganó >= 2 posiciones con <= 4 incidencias, o podio (<=3) con <= 6.
  /// 🔴 Roja: DNF/DSQ/DNS, perdió >= 2 posiciones, o >= 10 incidencias.
  /// 🔵 Azul: resto (carrera neutra).
  Color get resultColor {
    final gain = positionGain;
    final inc = (r['incidents'] as num?)?.toInt() ?? 0;
    final pos = r['finish_pos'] as num?;
    if (r['dnf'] == true || r['dsq'] == true || r['dns'] == true) {
      return AppColors.red;
    }
    if (gain <= -2 || inc >= 10) return AppColors.red;
    if (gain >= 2 || (pos != null && pos <= 3 && inc <= 6)) {
      return AppColors.green;
    }
    return AppColors.blue;
  }

  /// Posiciones netas ganadas (+ = adelantó). LFM no rellena position_gain,
  /// se calcula de start_pos - finish_pos.
  int get positionGain {
    final s = r['start_pos'] as num?;
    final f = r['finish_pos'] as num?;
    if (s == null || f == null) return 0;
    return s.toInt() - f.toInt();
  }

  /// Texto corto que explica el color del semáforo.
  String get resultLabel {
    final gain = positionGain;
    final inc = (r['incidents'] as num?)?.toInt() ?? 0;
    final pos = r['finish_pos'] as num?;
    if (r['dnf'] == true) return 'DNF';
    if (r['dsq'] == true) return 'DSQ';
    if (r['dns'] == true) return 'DNS';
    if (gain >= 2) return '+$gain 🏁';
    if (gain <= -2) return '$gain 🏁';
    if (inc >= 10) return '💥 $inc';
    if (pos != null && pos <= 3) return 'P$pos 🏆';
    return 'P$pos';
  }

  @override
  Widget build(BuildContext context) {
    final pos = r['finish_pos'];
    final Color posColor = pos == 1
        ? AppColors.gold
        : pos <= 3
            ? AppColors.cyan
            : AppColors.text;
    final rc = (r['rating_change'] as num?)?.toDouble();
    final sc = (r['sr_change'] as num?)?.toDouble();
    final bow = r['best_of_week'] == true;
    final logo = r['car_logo'] as String?;
    final rcColor = (rc ?? 0) >= 0 ? AppColors.green : AppColors.red;
    final scColor = (sc ?? 0) >= 0 ? AppColors.green : AppColors.red;
    final semaforo = resultColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              semaforo.withValues(alpha: 0.14),
              AppColors.surface,
            ],
            stops: const [0.0, 0.6],
          ),
          border: Border.all(
              color: semaforo.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          // Badge de posición P#
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  posColor.withValues(alpha: 0.30),
                  posColor.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                  color: posColor.withValues(alpha: 0.55), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('P',
                    style: TextStyle(
                        color: posColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1)),
                Text('$pos',
                    style: TextStyle(
                        color: posColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Logo del coche, grande
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: logo != null
                ? Image.network(logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(Icons.directions_car,
                        color: AppColors.textDim, size: 32))
                : Icon(Icons.directions_car,
                    color: AppColors.textDim, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(r['track_name']?.toString() ?? '',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (bow) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: AppColors.gold, size: 20),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.flag_outlined,
                        color: AppColors.gold, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          '${r['event_name']} · ${fmtDate(r['race_date'])}',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  // Chip de resultado (semáforo) — explica el color de la tarjeta
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: semaforo.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: semaforo.withValues(alpha: 0.45),
                          width: 1),
                    ),
                    child: Text(
                      resultLabel,
                      style: TextStyle(
                          color: semaforo,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('RATING',
                style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            Text(
                rc == null
                    ? '—'
                    : (rc > 0 ? '+${rc.toStringAsFixed(0)}' : rc.toStringAsFixed(0)),
                style: TextStyle(
                    color: rcColor, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('SR',
                style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            Text(
                sc == null
                    ? ''
                    : (sc > 0 ? '+${sc.toStringAsFixed(2)}' : sc.toStringAsFixed(2)),
                style: TextStyle(
                    color: scColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

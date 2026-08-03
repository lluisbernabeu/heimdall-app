import 'package:flutter/material.dart';
import '../theme.dart';

/// GLOSARIO — qué significa cada término de LFM.
/// Pantalla propia (antes era un ExpansionTile escondido en Perfil)
/// para que sea descubrible desde Explorar.
class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  static const List<(String, String)> _terms = [
    ('Rating (ELO)',
        'Tu nivel general. Sube al quedar por delante de pilotos con más rating que tú y baja al quedar por detrás de los que tienen menos. Empieza en 1500.'),
    ('SR (Safety Rating)',
        'Tu nota de seguridad. Sube con carreras limpias (pocos incidentes) y baja con choques, salidas de pista y sanciones. Determina tu licencia.'),
    ('Incidentes',
        'Lo que LFM registra: C = cut (cortaste la pista y la vuelta no cuenta), D = contacto/daño, O = fuera de pista, R = relaunch (te reiniciaste en la pista). Menos es siempre mejor.'),
    ('Split',
        'Grupo de pilotos de nivel parecido en una misma carrera. Los splits se numeran: split 1 = los más rápidos.'),
    ('Sectores S1/S2/S3',
        'El circuito se divide en 3 tramos. Tu vuelta perfecta es la suma de tu mejor S1 + S2 + S3. Ahí se gana o se pierde el tiempo.'),
    ('SOF (Strength of Field)',
        'El rating medio de los pilotos de tu carrera. Ganar en un SOF alto da más puntos y rating.'),
    ('Best of Week (BOW)',
        'Tu mejor resultado de la semana según LFM. Buen ritmo cuando todo sale limpio.'),
    ('Percentil SR',
        'El % de pilotos de LFM a los que superas en Safety Rating. Cuanto más alto, más seguro que el resto.'),
    ('Récord / vuelta perfecta',
        'Tu mejor vuelta válida en un circuito. La vuelta perfecta suma tus mejores sectores, aunque nunca los hayas enlazado en una sola vuelta.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glosario')),
      body: RuneBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const Text(
              'Todo lo que significa cada cifra de Heimdall, en cristiano.',
              style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            for (final (term, def) in _terms)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceAlt),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(term,
                      style: const TextStyle(color: AppColors.gold, fontSize: 13.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(def,
                      style: const TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/settings_screen.dart

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/abono_entry.dart';
import '../providers/ponto_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickAbono(
    BuildContext context,
    PontoProvider provider,
  ) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    DateTime dataEscolhida = DateTime.now();
    final horasCtrl = TextEditingController(text: '8');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Novo abono'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dia em que você faltou e as horas foram abonadas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: dataEscolhida,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    locale: const Locale('pt', 'BR'),
                  );
                  if (d != null) setLocal(() => dataEscolhida = d);
                },
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(DateFormat('EEE, d MMM yyyy', 'pt_BR')
                    .format(dataEscolhida)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: horasCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Horas abonadas',
                  hintText: 'Ex.: 8 ou 7,5',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) {
      horasCtrl.dispose();
      return;
    }

    final texto =
        horasCtrl.text.trim().replaceAll(',', '.').replaceAll(' ', '');
    horasCtrl.dispose();
    final horasDec = double.tryParse(texto);
    if (horasDec == null || horasDec <= 0 || horasDec > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe entre 0 e 24 horas (ex.: 8 ou 7.5).'),
        ),
      );
      return;
    }

    await provider.adicionarAbono(
      dataEscolhida,
      Duration(minutes: (horasDec * 60).round()),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abono registrado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Configurações',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Consumer<PontoProvider>(
        builder: (context, provider, _) {
          final ordenados = [...provider.abonos]
            ..sort((a, b) => b.data.compareTo(a.data));

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              Text(
                'Meta semanal',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Padrão: 20 horas. Usada no progresso da semana e no banco de horas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: provider.metaSemanalHorasValor.clamp(1, 60),
                      min: 1,
                      max: 60,
                      divisions: 118,
                      label: '${provider.metaSemanalHorasTexto} h',
                      onChanged: (v) => provider.definirMetaSemanalHoras(v),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${provider.metaSemanalHorasTexto} h',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Abonos',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickAbono(context, provider),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Horas creditadas em dias sem batidas (ex.: falta justificada). '
                'Entram no saldo do dia, da semana e do mês.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              if (ordenados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhum abono cadastrado',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ),
                )
              else
                ...ordenados.map((a) => _AbonoTile(
                      entry: a,
                      onDelete: () => provider.removerAbono(a.id),
                      theme: theme,
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _AbonoTile extends StatelessWidget {
  final AbonoEntry entry;
  final VoidCallback onDelete;
  final ThemeData theme;

  const _AbonoTile({
    required this.entry,
    required this.onDelete,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final dataStr = DateFormat('EEE, d MMM yyyy', 'pt_BR').format(entry.data);
    final horasStr = PontoProvider.formatarDuracao(entry.horas);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded,
                color: cs.primary.withOpacity(0.85)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dataStr.replaceFirst(dataStr[0], dataStr[0].toUpperCase()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$horasStr abonadas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remover',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            ),
          ],
        ),
      ),
    );
  }
}

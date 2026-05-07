// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../providers/ponto_provider.dart';
import '../../models/ponto_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PontoProvider>().carregarTodos();
    });
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
          'Histórico',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Consumer<PontoProvider>(
        builder: (context, provider, _) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator());
          }

          final historico = provider.historico;
          if (historico.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64,
                      color: cs.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum registro ainda',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          // Agrupar por dia
          final grupos = _agruparPorDia(historico);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: grupos.length,
            itemBuilder: (context, i) {
              final grupo = grupos[i];
              return _GrupoDia(
                data: grupo.key,
                pontos: grupo.value,
                provider: provider,
                theme: theme,
              );
            },
          );
        },
      ),
    );
  }

  List<MapEntry<DateTime, List<Ponto>>> _agruparPorDia(List<Ponto> pontos) {
    final Map<String, List<Ponto>> mapa = {};
    for (final p in pontos) {
      final chave = DateFormat('yyyy-MM-dd').format(p.dataHora);
      mapa.putIfAbsent(chave, () => []).add(p);
    }

    return mapa.entries
        .map((e) => MapEntry(DateTime.parse(e.key), e.value))
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));
  }
}

class _GrupoDia extends StatelessWidget {
  final DateTime data;
  final List<Ponto> pontos;
  final PontoProvider provider;
  final ThemeData theme;

  const _GrupoDia({
    required this.data,
    required this.pontos,
    required this.provider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final horas = provider.calcularHoras(pontos);
    final horasStr = PontoProvider.formatarDuracao(horas);
    final dataStr = DateFormat('EEE, d MMM', 'pt_BR').format(data);
    final hoje = DateTime.now();
    final eHoje = data.year == hoje.year &&
        data.month == hoje.month &&
        data.day == hoje.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    dataStr.replaceFirst(
                        dataStr[0], dataStr[0].toUpperCase()),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: eHoje ? cs.primary : null,
                    ),
                  ),
                  if (eHoje)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'hoje',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                horasStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        ...pontos.map((p) => _ItemHistorico(
              ponto: p,
              provider: provider,
              theme: theme,
            )),
      ],
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  final Ponto ponto;
  final PontoProvider provider;
  final ThemeData theme;

  const _ItemHistorico({
    required this.ponto,
    required this.provider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final hora = DateFormat('HH:mm').format(ponto.dataHora);
    final cor = _corTipo(ponto.tipo, cs);

    return Dismissible(
      key: Key('ponto_${ponto.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_rounded, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Excluir registro?'),
            content: const Text(
                'Esta ação não pode ser desfeita.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Excluir',
                    style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => provider.deletarPonto(ponto.id!),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_iconeTipo(ponto.tipo), color: cor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelTipo(ponto.tipo),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ponto.nome != null && ponto.nome!.isNotEmpty)
                      Text(
                        ponto.nome!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                    if (ponto.nsr != null && ponto.nsr!.isNotEmpty)
                      Text(
                        'NSR: ${ponto.nsr}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                  ],
                ),
              ),
              // Foto miniatura
              if (ponto.fotoPath != null) ...[
                GestureDetector(
                  onTap: () => _verFoto(context, ponto.fotoPath!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      File(ponto.fotoPath!),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                // Botão para adicionar foto depois
                GestureDetector(
                  onTap: () => provider.adicionarFotoAoPonto(ponto.id!),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.outline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: cs.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      size: 16,
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                hora,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verFoto(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Color _corTipo(String tipo, ColorScheme cs) {
    switch (tipo) {
      case 'entrada':
      case 'retorno':
        return cs.primary;
      case 'saida':
        return cs.error;
      case 'pausa':
        return cs.tertiary;
      default:
        return cs.secondary;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'entrada':
        return 'Entrada';
      case 'saida':
        return 'Saída';
      case 'pausa':
        return 'Pausa';
      case 'retorno':
        return 'Retorno';
      default:
        return tipo;
    }
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'entrada':
        return Icons.login_rounded;
      case 'saida':
        return Icons.logout_rounded;
      case 'pausa':
        return Icons.coffee_rounded;
      case 'retorno':
        return Icons.keyboard_return_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }
}

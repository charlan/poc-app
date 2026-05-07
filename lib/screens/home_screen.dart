// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:io';

import '../providers/ponto_provider.dart';
import '../../models/ponto_model.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PontoProvider>().carregarTodos();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
          'Meu Ponto',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<PontoProvider>(
        builder: (context, provider, _) {
          if (provider.carregando && provider.pontosDoDia.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: provider.carregarTodos,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _DataAtual(theme: theme),
                  const SizedBox(height: 28),
                  _BotaoRegistrar(
                    provider: provider,
                    pulseAnim: _pulseAnim,
                    onRegistrar: () => _registrarPonto(context, provider),
                  ),
                  const SizedBox(height: 32),
                  _CardResumoHoje(provider: provider, theme: theme),
                  const SizedBox(height: 16),
                  _ProgressoSemanal(provider: provider, theme: theme),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CardMetrica(
                          titulo: 'No Mês',
                          valor: PontoProvider.formatarDuracao(
                              provider.horasMes),
                          icone: Icons.calendar_month_rounded,
                          cor: cs.tertiary,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CardBancoHoras(
                            provider: provider, theme: theme),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _PontosDeHoje(provider: provider, theme: theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Lógica do botão principal ─────────────────────────────────────
  Future<void> _registrarPonto(
      BuildContext context, PontoProvider provider) async {
    HapticFeedback.mediumImpact();

    // Primeiro teste: apenas verificar permissão
    final permissaoConcedida = await provider.testarPermissaoCamera();
    if (!context.mounted) return;

    if (!permissaoConcedida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão da câmera negada')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permissão concedida! Agora testando câmera...')),
    );

    // Segundo teste: capturar comprovante
    final comprovante = await provider.capturarComprovante();
    if (!context.mounted) return;

    if (comprovante == null) {
      // Mostrar erro se houver
      final erro = provider.ultimaMensagemErro;
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro)),
        );
      }
      return;
    }

    _showDialogComprovante(context, provider, comprovante);
  }

  void _showDialogComprovante(
    BuildContext context,
    PontoProvider provider,
    ComprovanteData comprovante,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ComprovanteBottomSheet(
        provider: provider,
        comprovante: comprovante,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _DataAtual extends StatelessWidget {
  final ThemeData theme;
  const _DataAtual({required this.theme});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final diaSemana = DateFormat('EEEE', 'pt_BR').format(agora);
    final dataCompleta = DateFormat('d \'de\' MMMM', 'pt_BR').format(agora);
    final hora = DateFormat('HH:mm').format(agora);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diaSemana.replaceFirst(
                  diaSemana[0], diaSemana[0].toUpperCase()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
            Text(
              dataCompleta,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            hora,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Botão Principal ───────────────────────────────────────────────────────────
class _BotaoRegistrar extends StatelessWidget {
  final PontoProvider provider;
  final Animation<double> pulseAnim;
  final VoidCallback onRegistrar;

  const _BotaoRegistrar({
    required this.provider,
    required this.pulseAnim,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final aberto = provider.pontoAberto;
    final cor = aberto ? cs.error : cs.primary;
    final label = _labelTipo(provider.proximoTipo);
    final icone = _iconeTipo(provider.proximoTipo);

    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: aberto ? pulseAnim.value : 1.0,
          child: child,
        ),
        child: GestureDetector(
          onTap: onRegistrar,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor,
              boxShadow: [
                BoxShadow(
                  color: cor.withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: Colors.white, size: 44),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (aberto)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'em andamento',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'entrada':
        return 'Bater Entrada';
      case 'saida':
        return 'Bater Saída';
      case 'pausa':
        return 'Iniciar Pausa';
      case 'retorno':
        return 'Retornar';
      default:
        return 'Registrar';
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
        return Icons.fingerprint_rounded;
    }
  }
}

// ── Card Resumo do Dia ────────────────────────────────────────────────────────
class _CardResumoHoje extends StatelessWidget {
  final PontoProvider provider;
  final ThemeData theme;
  const _CardResumoHoje({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final horas = PontoProvider.formatarDuracao(provider.horasHoje);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.today_rounded,
                color: cs.onPrimaryContainer, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoje',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
                Text(
                  horas,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${PontoProvider.formatarDuracao(provider.saldoHoje)} hoje',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: provider.saldoHoje.isNegative
                        ? cs.error
                        : cs.secondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.pontosDoDia.length} registros',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              if (provider.pontoAberto)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '● ABERTO',
                    style: TextStyle(
                      color: cs.onErrorContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Progresso Semanal ─────────────────────────────────────────────────────────
class _ProgressoSemanal extends StatelessWidget {
  final PontoProvider provider;
  final ThemeData theme;
  const _ProgressoSemanal({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final progresso = provider.progressoSemanal.clamp(0.0, 1.0);
    final cs = theme.colorScheme;
    final horas = PontoProvider.formatarDuracao(provider.horasSemana);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Semana Atual',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$horas / 20h',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearPercentIndicator(
            lineHeight: 12,
            percent: progresso,
            backgroundColor: cs.outline.withOpacity(0.15),
            progressColor:
                progresso >= 1.0 ? cs.secondary : cs.primary,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
            animation: true,
            animationDuration: 800,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progresso * 100).toInt()}% da meta semanal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Métrica Genérico ─────────────────────────────────────────────────────
class _CardMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;
  final ThemeData theme;

  const _CardMetrica({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(height: 10),
          Text(titulo,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
          const SizedBox(height: 2),
          Text(
            valor,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Banco de Horas ───────────────────────────────────────────────────────
class _CardBancoHoras extends StatelessWidget {
  final PontoProvider provider;
  final ThemeData theme;
  const _CardBancoHoras({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final saldo = provider.bancoDaSemanaSaldo;
    final positivo = !saldo.isNegative;
    final cs = theme.colorScheme;
    final cor = positivo ? cs.secondary : cs.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positivo
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: cor,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Banco de Horas',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withOpacity(0.5)),
          ),
          const SizedBox(height: 2),
          Text(
            PontoProvider.formatarDuracao(saldo),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de Pontos do Dia ────────────────────────────────────────────────────
class _PontosDeHoje extends StatelessWidget {
  final PontoProvider provider;
  final ThemeData theme;
  const _PontosDeHoje({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final pontos = provider.pontosDoDia;
    if (pontos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Nenhum ponto registrado hoje',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Registros de Hoje',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...pontos.reversed.map((p) => _ItemPonto(ponto: p, theme: theme)),
      ],
    );
  }
}

class _ItemPonto extends StatelessWidget {
  final Ponto ponto;
  final ThemeData theme;
  const _ItemPonto({required this.ponto, required this.theme});

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final hora = DateFormat('HH:mm').format(ponto.dataHora);
    final cor = _corTipo(ponto.tipo, cs);
    final label = _labelTipo(ponto.tipo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cor.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconeTipo(ponto.tipo), color: cor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (ponto.observacao != null)
                    Text(ponto.observacao!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.5),
                        )),
                ],
              ),
            ),
            Text(
              hora,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (ponto.fotoPath != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(ponto.fotoPath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 24),
                ),
              ),
            ],
          ],
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

// ── Bottom Sheet de Comprovante ───────────────────────────────────────────
class _ComprovanteBottomSheet extends StatefulWidget {
  final PontoProvider provider;
  final ComprovanteData comprovante;

  const _ComprovanteBottomSheet({
    required this.provider,
    required this.comprovante,
  });

  @override
  State<_ComprovanteBottomSheet> createState() => _ComprovanteBottomSheetState();
}

class _ComprovanteBottomSheetState extends State<_ComprovanteBottomSheet> {
  late final TextEditingController _nomeController;
  late final TextEditingController _dataController;
  late final TextEditingController _horaController;
  late final TextEditingController _nsrController;
  late final TextEditingController _observacaoController;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.comprovante.nome);
    _dataController = TextEditingController(text: widget.comprovante.data);
    _horaController = TextEditingController(text: widget.comprovante.hora);
    _nsrController = TextEditingController(text: widget.comprovante.nsr);
    _observacaoController = TextEditingController(text: widget.comprovante.textoOCR);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dataController.dispose();
    _horaController.dispose();
    _nsrController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Confirmar Comprovante',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.comprovante.fotoPath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Nome',
              controller: _nomeController,
              hint: 'Nome no comprovante',
            ),
            _buildField(
              label: 'Data',
              controller: _dataController,
              hint: 'DD/MM/AAAA',
            ),
            _buildField(
              label: 'Hora',
              controller: _horaController,
              hint: 'HH:MM',
            ),
            _buildField(
              label: 'NSR',
              controller: _nsrController,
              hint: 'Número sequencial',
            ),
            const SizedBox(height: 12),
            Text(
              'Texto detectado (OCR)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.comprovante.textoOCR.isEmpty
                    ? 'Nenhum texto reconhecido.'
                    : widget.comprovante.textoOCR,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.75),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _salvando ? null : _salvarComprovante,
                child: _salvando
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Salvar ponto'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _salvarComprovante() async {
    setState(() => _salvando = true);
    await widget.provider.registrarPontoComComprovante(
      nome: _nomeController.text.trim(),
      data: _dataController.text.trim(),
      hora: _horaController.text.trim(),
      nsr: _nsrController.text.trim(),
      fotoPath: widget.comprovante.fotoPath,
      observacao: _observacaoController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (widget.provider.erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.provider.erro!)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ponto salvo com sucesso.')),
    );
    Navigator.pop(context);
  }
}

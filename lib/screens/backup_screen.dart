// lib/screens/backup_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ponto_provider.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _exportar(BuildContext context) async {
    final provider = context.read<PontoProvider>();
    final ok = await provider.exportarECompartilharBackup();
    if (!context.mounted) return;
    final msg = provider.erro;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok && msg == null
              ? 'Compartilhe ou salve o arquivo JSON quando o sistema abrir.'
              : (msg ?? 'Não foi possível exportar.'),
        ),
      ),
    );
  }

  Future<void> _importar(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (!context.mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível ler o arquivo.')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Substituir todos os dados?'),
        content: const Text(
          'Os registros atuais serão apagados e substituídos pelo backup. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Importar',
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final provider = context.read<PontoProvider>();
    final n = await provider.importarBackupSubstituindo(path);
    if (!context.mounted) return;
    final erro = provider.erro;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n != null
              ? 'Importados $n registro(s).'
              : (erro ?? 'Falha na importação.'),
        ),
      ),
    );
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
          'Backup',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Consumer<PontoProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 22,
                          color: cs.primary.withOpacity(0.85),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Exporte um arquivo JSON com todos os pontos e fotos dos comprovantes. '
                            'Na outra instalação do app, use importar para restaurar.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withOpacity(0.75),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: provider.carregando ? null : () => _exportar(context),
                  icon: provider.carregando
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(
                      provider.carregando ? 'Gerando…' : 'Exportar todos os dados'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed:
                      provider.carregando ? null : () => _importar(context),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Importar backup (.json)'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

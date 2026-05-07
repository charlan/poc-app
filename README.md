# Meu Ponto — Guia de Configuração

## Estrutura do Projeto

```
lib/
├── main.dart                    # Entrada, tema, Provider
├── models/
│   └── ponto_model.dart         # Modelo de dados (Ponto, PeriodoTrabalhado)
├── database/
│   └── db_helper.dart           # SQLite — queries e schema
├── providers/
│   └── ponto_provider.dart      # Toda a lógica de negócio + estado
└── screens/
    ├── home_screen.dart         # Tela principal
    └── history_screen.dart      # Histórico completo
```

---

## 1. Schema do Banco de Dados (SQLite)

```sql
-- Tabela principal
CREATE TABLE pontos (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  dataHora   TEXT    NOT NULL,   -- ISO-8601, ex: "2025-06-10T08:02:15.000"
  tipo       TEXT    NOT NULL,   -- 'entrada' | 'saida' | 'pausa' | 'retorno'
  fotoPath   TEXT,               -- caminho local absoluto da foto (nullable)
  observacao TEXT                -- nota livre (nullable)
);

CREATE INDEX idx_pontos_dataHora ON pontos(dataHora);
```

**Por que SQLite local?**
- Zero latência — sem chamadas de rede
- Funciona offline 100%
- `sqflite` é madura e estável no Flutter
- Para backup, use a solução de exportação opcional descrita abaixo

---

## 2. Instalação das Dependências

```bash
flutter pub get
```

---

## 3. Permissões Android

Adicione em `android/app/src/main/AndroidManifest.xml` dentro de `<manifest>`:

```xml
<!-- Câmera -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />

<!-- Armazenamento (necessário para Android 12 ou inferior) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />
```

E dentro de `<application>`:

```xml
<!-- Necessário para image_picker no Android 11+ -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

Crie o arquivo `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache" path="." />
</paths>
```

### minSdkVersion

Em `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21   // mínimo para sqflite + image_picker
        targetSdkVersion 34
    }
}
```

---

## 4. Permissões iOS (se necessário no futuro)

Em `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Usado para fotografar o comprovante do ponto</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Acessar fotos dos comprovantes</string>
```

---

## 5. Executar

```bash
flutter run
```

---

## 6. Lógica de Cálculo de Horas

| Situação                        | Como é calculado                                  |
|--------------------------------|---------------------------------------------------|
| Horas de hoje                  | Σ(saída−entrada) pares do dia; se aberto → agora  |
| Horas da semana                | Mesmo algoritmo, pontos seg→dom                   |
| Meta semanal                   | 20h (constante `PontoProvider.metaSemanal`)        |
| Banco de horas (semana)        | `horasSemana − 20h`                               |
| Banco de horas (mês)           | `horasMes − (semanas_no_mês × 20h)`               |

---

## 7. Backup Opcional — Google Drive

Para não perder dados, adicione exportação periódica:

```dart
// Exportar banco SQLite para o Drive (adicionar pacote googleapis)
// 1. Copie o arquivo .db para um arquivo ZIP ou CSV
// 2. Faça upload via googleapis ou google_sign_in + drive API
// 3. Execute automaticamente 1x/semana via WorkManager
```

Pacotes sugeridos para backup:
- `googleapis: ^13.0.0` — API oficial do Google
- `google_sign_in: ^6.0.0` — autenticação
- `workmanager: ^0.5.0` — tarefas em background

---

## 8. Customizações Rápidas

| O que mudar                 | Onde                              |
|-----------------------------|-----------------------------------|
| Meta semanal (20h → outra)  | `ponto_provider.dart` linha ~18   |
| Cor principal do app        | `main.dart` → `seedColor`         |
| Tipos de ponto              | `proximoTipo` no provider         |
| Horário de notificação      | Adicionar `flutter_local_notifications` |

---

## 9. Próximos Passos Sugeridos

- [ ] Notificação lembrando de bater o ponto de saída
- [ ] Widget na tela inicial do Android
- [ ] Exportar relatório em PDF/CSV por período
- [ ] Sincronização com Google Sheets via API

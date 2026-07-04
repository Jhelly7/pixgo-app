# Pixgo — App Flutter (Android)

Conversão do site Pixgo (Next.js) para Flutter/Dart, mantendo design, cores,
fluxos e arquitectura de dados idênticos ao original.

## Estrutura

```
lib/
  core/           theme.dart (cores exactas de globals.css), router.dart (go_router), chacha20.dart
  models/         modelos de dados (User, Plan, ContentItem, ChannelItem, DownloadItem)
  services/       api_client.dart (Dio + refresh de token), downloads_service.dart, decrypt_proxy_server.dart
  providers/      auth_provider.dart (Riverpod, equivalente a store/auth.ts), locale_provider.dart
  screens/        um ecrã por rota do site original (auth/, main/)
  widgets/        content_card.dart
  l10n/           app_localizations.dart (lê assets/i18n/{pt,en,es}.json — os MESMOS do site)
android/          projeto Android nativo (gradle, manifest, ícones)
.github/workflows/build_apk.yml   compila o APK automaticamente
```

## Mapeamento de rotas (Next.js → Flutter/go_router)

| Site (Next.js)              | Flutter                          |
|---|---|
| `/auth/login`                | `/auth/login`                    |
| `/auth/register`             | `/auth/register`                 |
| `/main`                      | `/main` (HomeScreen)              |
| `/main/catalog`              | `/main/catalog`                  |
| `/main/channels`             | `/main/channels`                 |
| `/main/mylist`                | `/main/mylist`                   |
| `/main/search`                | `/main/search`                   |
| `/main/account`               | `/main/account`                  |
| `/main/downloads`             | `/main/downloads`                |
| `/main/plans`                 | `/main/plans`                    |
| `/main/plans/checkout`        | `/main/plans/checkout`           |
| `/main/content/[id]`          | `/main/content/:id`              |
| `/main/watch/[id]`            | `/main/watch/:id` (fullscreen, sem bottom nav) |

## Decisões técnicas importantes

### 1. ChaCha20 (`lib/core/chacha20.dart`)
Port **linha-a-linha** do `chacha20-stream.worker.js` v9.1 (incluindo a
correcção da ronda diagonal). Mesmo protocolo binário chunk-v2. Testado
apenas por revisão manual — **recomendo correr um teste de decriptação real
contra um segmento .bin conhecido antes de confiares 100%** (não tenho
Flutter/Dart SDK neste ambiente para correr testes automatizados).

### 2. Player de vídeo (`lib/services/decrypt_proxy_server.dart` + `watch_screen.dart`)
O site usa `hls.js` com um *custom loader* que intercepta `.bin` e decripta
via Web Worker antes de entregar ao MSE do browser. O Flutter (`video_player`
→ ExoPlayer no Android) **não suporta custom loaders**, por isso a solução
foi:

1. Sobe um **servidor HTTP local** (`127.0.0.1:porta_aleatória`, via `shelf`)
2. Esse servidor busca o `master.m3u8` remoto, reescreve todos os URIs de
   segmento (`.bin`, incluindo o `#EXT-X-MAP` do init segment) para apontar
   para si mesmo
3. Em cada pedido de segmento, busca o `.bin` original, decripta com
   `ChaCha20.decryptSegment()`, devolve o fMP4 puro
4. `video_player`/`Chewie` consome `http://127.0.0.1:porta/master.m3u8`
   como um HLS normal — não sabe que existe encriptação por trás

**⚠️ Isto ainda precisa de validação contra o backend real.** Assumi o
contrato de `contentApi.getStream(id)` que vi em `ShakaPlayer.tsx`:
```
{ drmKeyHex, masterUrl, noncesUrl?, segExt: 'bin'|'ts', quality }
```
Se os nomes dos campos JSON forem diferentes, ajusta em `watch_screen.dart`
(`_init()`) — são 3 linhas.

### 3. Downloads offline (`lib/services/downloads_service.dart`)
O site usa IndexedDB (metadata + segmentos). Aqui uso `sqflite` para
metadata e ficheiros no filesystem (`ApplicationDocumentsDirectory`) para os
segmentos já decriptados — equivalente funcional.

### 4. i18n
Não usei `easy_localization` — implementei um delegate leve
(`lib/l10n/app_localizations.dart`) que lê **os mesmos ficheiros JSON do
site** (`pt.json`, `en.json`, `es.json`, copiados para `assets/i18n/`), com
`context.t('auth.signIn')`.

### 5. Estado (Zustand → Riverpod)
`store/auth.ts` → `lib/providers/auth_provider.dart`. Mesma lógica de
refresh automático de token em 401 (ver `ApiClient._req` em `api_client.dart`).

## O que está completo
- Estrutura completa do projeto Android (gradle, manifest, ícones)
- Tema com as cores exactas do site (`--color-primary: #e50914`, etc.)
- Autenticação (login/registo) com as mesmas validações client-side
- Navegação principal (bottom nav, 5 abas)
- Home, Catálogo, TV ao vivo, Minha Lista, Busca, Conta, Downloads, Planos, Checkout USDT, Detalhe de conteúdo
- Player com pipeline de decriptação ChaCha20 (arquitectura completa, ver nota acima)
- GitHub Actions workflow pronto a compilar o APK

## O que precisa da tua atenção antes do primeiro build real
1. **Confirma o contrato exacto de `GET /content/:id/stream`** (nomes de campos) e ajusta `watch_screen.dart` se necessário
2. **`API_BASE_URL`**: definido em `lib/services/api_client.dart` como `String.fromEnvironment`, passado no CI via `--dart-define`. Configura a variável de repositório `API_BASE_URL` no GitHub (Settings → Secrets and variables → Actions → Variables)
3. **Teste a decriptação ChaCha20** contra um segmento `.bin` real (não tive Dart SDK disponível para correr testes automatizados aqui)
4. **Assinatura do APK**: sem `key.properties`, o build assina em modo debug (funciona para testes/side-load). Para produção, adiciona os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` no repositório

## Como compilar
Basta fazer push para o `main` (ou correr manualmente via *workflow_dispatch*)
— o GitHub Actions (`.github/workflows/build_apk.yml`) trata de tudo e
publica o APK como artefacto + Release, exactamente como no teu pipeline
StreamVault.

Localmente (se tiveres Flutter instalado):
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.pixgo.frii.site
```

# App TagFind (Flutter)

Scanner BLE colaborativo e gerenciamento de tags com Supabase.

## Requisitos

- Flutter SDK 3.16+ (Dart ≥ 3.2)
- Android Studio (SDK 21+) ou Xcode 15+
- Dispositivo físico com BLE (emuladores **não** suportam BLE real)

## Setup

1. Instale o Flutter: https://docs.flutter.dev/get-started/install

2. Crie o scaffold do projeto Flutter nesta pasta (caso ainda não exista):

```bash
cd mobile
flutter create . --org com.tagfind --project-name tagfind
```

3. Copie as permissões do `AndroidManifest.xml` gerado em `android/app/src/main/` e mescle as entradas de `ios/Runner/Info.plist.tagfind` no seu `Info.plist`.

4. Instale as dependências:

```bash
flutter pub get
```

5. Execute no dispositivo:

```bash
flutter run
```

## Estrutura do Projeto

```
mobile/
├── lib/
│   ├── main.dart                          # Entry point
│   └── src/
│       ├── config/
│       │   ├── constants.dart             # Supabase URL, BLE Company ID
│       │   └── theme.dart                 # Design System (Dark + Amber)
│       ├── models/
│       │   ├── tag.dart                   # Model da tabela `tags`
│       │   └── ble_advertisement.dart     # Dados parseados do pacote BLE
│       ├── providers/
│       │   └── providers.dart             # Riverpod (tags, BLE scan, sightings)
│       ├── services/
│       │   ├── ble_service.dart           # Scan + parse do advertising 6 bytes
│       │   ├── supabase_service.dart      # CRUD na tabela `tags`
│       │   └── location_service.dart      # GPS + permissões
│       └── views/
│           ├── home_page.dart             # Tab "Minhas Tags" + navegação
│           ├── tag_detail_page.dart        # Edição de mensagem, telefone, toggle perdido
│           └── scanner_page.dart          # Scanner BLE em tempo real
├── android/
│   └── app/src/main/AndroidManifest.xml   # Permissões BLE + Location
├── ios/
│   └── Runner/Info.plist.tagfind          # Entradas de permissão iOS
├── pubspec.yaml                           # Dependências Flutter
└── analysis_options.yaml                  # Lint rules
```

## Payload BLE (6 bytes)

O ESP32-C3 transmite pacotes de Manufacturer Data com `Company ID = 0xFFFF`:

| Byte | Campo       | Descrição                          |
|------|-------------|------------------------------------|
| 0    | ID low      | Device ID (16-bit little-endian)   |
| 1    | ID high     |                                    |
| 2    | Status      | Bit 0: lost, Bit 1: low battery   |
| 3    | Battery     | Porcentagem de bateria             |
| 4    | Energy Mode | 0x00=Normal, 0x01=ECO, 0x02=SOS   |
| 5    | CRC-8       | CRC dos bytes 0–4                  |

## Stack

| Camada            | Tecnologia           |
|-------------------|----------------------|
| Framework         | Flutter (Dart)       |
| Estado            | Riverpod             |
| BLE               | flutter_blue_plus    |
| Backend           | supabase_flutter     |
| Localização       | geolocator           |
| Permissões        | permission_handler   |

Emuladores **não** possuem rádio BLE. Use um telefone real para testar o scan.

# App TagFind (React Native)

Scanner BLE em segundo plano e sincronização com Supabase.

## Requisitos

- Node.js 20+
- Android Studio (SDK + emulador) ou dispositivo físico com BLE
- Projeto Expo / React Native (scaffold abaixo)

## Configuração

1. Copie `.env.example` para `.env` (quando o app for gerado) e preencha:

```
EXPO_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

2. Instale dependências após criar o projeto RN/Expo nesta pasta (`mobile/`).

```bash
cd mobile
npx expo start
```

No Android físico: BLE scan exige permissões `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` e localização.

## O que o `src/` faz

| Módulo | Papel |
| --- | --- |
| `screens/HomeScreen.js` | Lista pings recentes |
| `ble/scanner.js` | Observa manufacturer `0xFFFF` e decodifica 6 bytes |
| `lib/supabase.js` | Cliente e insert em `sightings` |

Emuladores **não** têm BLE confiável. Use um telefone real para testar a tag.

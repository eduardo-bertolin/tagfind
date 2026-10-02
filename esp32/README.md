# Firmware TagFind (ESP32-C3)

Firmware connectionless: advertising BLE de 6 bytes e deep sleep.

## Requisitos

- [PlatformIO](https://platformio.org/) (CLI ou extensão VS Code / Cursor)
- Placa **ESP32-C3 SuperMini** (ou DevKit equivalente)
- Cabo USB com dados

## Compilar e gravar

```bash
cd esp32
pio run -t upload
pio device monitor
```

Altere o ID da tag em `platformio.ini`:

```
-DTAG_DEVICE_ID=0x0002
```

## Validação

1. Abra o **nRF Connect** no celular.
2. Procure manufacturer data `0xFFFF`.
3. Confira os 6 bytes conforme `docs/payload-spec.md`.

A tag não aceita conexão GATT. Se o scanner pedir pairing, ignore.

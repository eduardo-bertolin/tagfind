# Payload BLE — 6 bytes

O anúncio usa **Manufacturer Specific Data** (AD Type `0xFF`). Company ID reservado para o projeto: `0xFFFF` (teste / não atribuído). Substitua por um ID Bluetooth SIG em produção.

## Layout (little-endian)

| Offset | Tamanho | Campo | Descrição |
| --- | --- | --- | --- |
| 0–1 | 2 | `device_id` | ID da tag (`0x0001` … `0xFFFF`) |
| 2 | 1 | `status` | Flags de estado (ver abaixo) |
| 3 | 1 | `battery` | Nível 0–100 (%) |
| 4 | 1 | `energy_mode` | Modo de energia |
| 5 | 1 | `crc8` | CRC-8 (polinômio `0x07`, init `0x00`) dos bytes 0–4 |

Tamanho total do manufacturer data = 2 (company id) + 6 (payload) = 8 bytes no PDU de advertising.

## `status` (bitmask)

| Bit | Nome | Significado |
| --- | --- | --- |
| 0 | `LOST` | Dono marcou como perdido (espelhado na nuvem; a tag pode forçar via GPIO) |
| 1 | `LOW_BATT` | Bateria abaixo do limiar (~20%) |
| 2 | `MOTION` | Movimento recente (se IMU presente) |
| 3–7 | reservado | Deve ser `0` |

## `energy_mode`

| Valor | Nome | Intervalo típico de advertising |
| --- | --- | --- |
| `0x00` | `NORMAL` | 1 s acordado / longo sleep |
| `0x01` | `ECO` | Menos bursts, sleep mais longo |
| `0x02` | `SOS` | Advertising mais frequente (objeto perdido) |

## Exemplo

Tag `0x0001`, status `0`, bateria `87%`, modo `NORMAL`:

```
01 00 00 57 00 <crc8>
```

No nRF Connect: procure manufacturer `0xFFFF` e os 6 bytes acima.

## Decodificação (JS)

```js
function decodePayload(bytes) {
  const deviceId = bytes[0] | (bytes[1] << 8);
  return {
    deviceId,
    hexId: "0x" + deviceId.toString(16).padStart(4, "0").toUpperCase(),
    status: bytes[2],
    battery: bytes[3],
    energyMode: bytes[4],
    crc8: bytes[5],
  };
}
```

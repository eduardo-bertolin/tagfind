# Arquitetura — Connectionless Communication

O TagFind usa **comunicação BLE sem conexão**. A tag nunca estabelece GATT, pairing nem sessão. Ela apenas anuncia um pacote curto; qualquer aparelho próximo pode observá-lo.

```
┌─────────────┐     BLE Adv (6 B)      ┌──────────────────┐
│  ESP32-C3   │ ─────────────────────► │  App (scanner)   │
│  Tag        │   connectionless ping  │  Android/iOS     │
└─────────────┘                        └────────┬─────────┘
                                                │ GPS + tag_id
                                                ▼
                                       ┌──────────────────┐
                                       │  Supabase        │
                                       │  (PostgreSQL)    │
                                       └────────┬─────────┘
                                                │
                    NFC / QR ───────────────────┼───► Página /web
                    (resgate sem app)           │
```

## Por que connectionless

- **Energia:** advertising + deep sleep gasta milhares de vezes menos que uma conexão persistente.
- **Privacidade da malha:** o observador não se identifica para a tag. A rede é colaborativa e anônima no rádio.
- **Alcance da descoberta:** qualquer telefone com o app (ou um scanner BLE) pode reportar um ping.

## Ciclo da tag

1. Acorda do deep sleep.
2. Monta o payload de 6 bytes (ver [payload-spec.md](./payload-spec.md)).
3. Transmite N advertisements no intervalo configurado.
4. Volta a dormir.

Não há ACK no ar. A confirmação de “visto” só existe na nuvem, quando um scanner envia geolocalização.

## Papel de cada camada

| Camada | Função |
| --- | --- |
| Firmware (`/esp32`) | Beacon BLE 5.0, bateria, modo de energia, Device ID |
| Mobile (`/mobile`) | Scan em segundo plano, decode do manufacturer data, sync GPS |
| Web (`/web`) | Resgate público via `?id=0xNNNN` (NFC/QR) |
| Database (`/database`) | Tags, estado de perda, mensagens, last-seen |

## Identificadores

O Device ID de 16 bits no rádio (`0x0001`, `0x0002`, …) é a chave pública da tag. NFC e QR apontam para a mesma página web com esse ID, para quem encontrou o objeto não precisar do app.

# TagFind — Sistema de Rastreamento BLE Inteligente

Projeto de rastreamento de baixo consumo baseado no microcontrolador **ESP32-C3**, focado em comunicação sem conexão (*Connectionless Communication*), rede colaborativa anônima e resgate universal via **NFC / QR Code**.

## Arquitetura do Sistema

- **ESP32-C3 (Firmware):** Transmite pacotes BLE Advertising customizados (6 bytes) contendo Status, Nível de Bateria, Modo de Energia e Device ID.
- **Mobile (App):** Realiza o BLE Observing/Scanning em segundo plano, detecta pings e sincroniza geolocalização com a nuvem.
- **Web (`/web`):** Página leve em HTML/JS hospedada na Vercel para resgate de objetos sem necessidade de instalação de app.
- **Database (`/database`):** PostgreSQL/Supabase armazenando a relação de tags, status de perda, mensagens e coordenadas GPS.

## Tecnologias Utilizadas

- **Microcontrolador:** ESP32-C3 SuperMini (C++ / BLE 5.0)
- **Banco de Dados:** Supabase (PostgreSQL)
- **Hospedagem Web:** Vercel / GitHub Pages
- **Scanner/Testes:** nRF Connect for Mobile

## Estrutura do repositório

```
tagfind/
├── .github/workflows/   # Deploy da página /web (GitHub Pages)
├── docs/                # Arquitetura, spec do payload e imagens
├── esp32/               # Firmware PlatformIO (ESP32-C3)
├── mobile/              # App (scanner BLE + Supabase)
├── web/                 # Página de resgate NFC/QR
└── database/            # schema.sql e seeds.sql
```

## Instalação rápida

1. **Banco:** no SQL Editor do Supabase, rode `database/schema.sql` e em seguida `database/seeds.sql`.
2. **Web:** em `web/app.js`, preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY`. Abra `web/index.html` ou faça o deploy.
3. **Firmware:** `cd esp32 && pio run -t upload` (veja `esp32/README.md`).
4. **App:** siga `mobile/README.md` em um Android com BLE.

## Como testar o protótipo web sem hardware

1. Execute o script `database/schema.sql` na sua instância do Supabase.
2. Abra o arquivo `web/index.html` ou acesse o link de deploy.
3. Teste os cenários passando parâmetros pela URL:
   - **Tag Normal:** `https://seu-deploy.vercel.app/?id=0x0001`
   - **Tag Perdida:** `https://seu-deploy.vercel.app/?id=0x0002`

Documentação técnica: [docs/architecture.md](docs/architecture.md) e [docs/payload-spec.md](docs/payload-spec.md).

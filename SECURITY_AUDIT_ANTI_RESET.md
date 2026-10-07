# AUDITORIA DE SEGURANÇA — TagFind Anti-Reset / OWNER_SECRET_KEY
Data: 2026-10-07
Engenheiro: AI Senior (Flutter / IoT / BLE / CyberSec)

---

## 1. GERAÇÃO E ARMAZENAMENTO DO VÍNCULO

- [!] **PENDENTE / NECESSITA AJUSTES** — `register()` em `providers.dart` (linha 69) **não gera** `OWNER_SECRET_KEY`; apenas chama `SupabaseService.registerTag()`. Nenhuma chave é criada, associada ao `tagId` ou persistida localmente.
- [!] **PENDENTE** — `saveOwnerKey()` existe em `providers.dart` (linha 89) mas **nunca é invocado** no fluxo de registro/vinculação.
- [x] **IMPLEMENTADO** — `getOwnerKey()` recupera chave de `SharedPreferences` (`owner_key_$tagId`).
- [x] **IMPLEMENTADO** — `Tag` model inclui `ownerSecretKey` (campo local, Não enviado a Supabase — correto para privacidade).
- [!] **NECESSITA AJUSTES** — A chave não é associada ao registro do usuário no banco (`tags` tabela não possui coluna de chave no schema documentado). A associação é apenas local no dispositivo, o que torna a desvinculação dependente apenas do dispositivo físico do usuário.

---

## 2. FLUXO DO COMANDO ANTI-RESET & DESVINCULAÇÃO (`unbindTag`)

- [!] **PENDENTE / NECESSITA AJUSTES** — `unbindTag()` (linha 78) **não recupera** `OWNER_SECRET_KEY` antes de autorizar remoção. Executa direto `prefs.remove()` + `SupabaseService.unbindTag()` sem verificação prévia da chave.
- [!] **PENDENTE / NECESSITA AJUSTES** — **Não existe fluxo BLE GATT** para envio da chave ao ESP32. A arquitetura documentada (`architecture.md`, linha 13) declara **connectionless** (“A tag nunca estabelece GATT”). O ESP32 (`main.cpp`) não implementa servidor GATT, NVS de validação de chave, nem característica de escrita.
- [!] **PENDENTE / NECESSITA AJUSTES** — A chave local é removida **antes** (linha 80-81) de confirmar a desvinculação no banco; ordem deve ser: validar chave → enviar via BLE (se aplicável) → confirmar reset no ESP32 → confirmar remoção no Supabase → limpar local.
- [!] **PENDENTE / NECESSITA AJUSTES** — O `tag_detail_page.dart` não exibe menu/fluxo de “Desvincular e Resetar Tag” com validação de senha/chave.

---

## 3. TRATAMENTO DE ALERTAS DE SEGURANÇA (Hard-Reset `0xFF`)

- [x] **IMPLEMENTADO** — `ble_service.dart` linha 239-258: `_decodePayload()` lê byte `[0]`; `0xFF` mapeado para `status = 0xFF`.
- [x] **IMPLEMENTADO** — `ble_service.dart` linha 182-191: `_handleSecurityAlert()` dispara se `adv.isSecurityAlert` (`status == 0xFF`).
- [x] **IMPLEMENTADO** — `supabase_service.dart` linha 148-159: `insertSecurityAlert()` grava `security_alerts` (tag_id, detected_at, type='RESET_ATTEMPT').
- [x] **IMPLEMENTADO** — `providers.dart` linha 182-191: notificação em tempo real via `securityAlertsProvider`.
- [!] **NECESSITA AJUSTES** — O ESP32 (`main.cpp`) não implementa envio de `0xFF`; o `buildStatus()` (linha 33-39) retorna apenas bits de bateria (`0x02` LOW_BATT), não possui mecanismo de hard-reset por botão long-press. A funcionalidade 0xFF está no parser do app, mas não há origem no firmware.

---

## 4. TRATAMENTO DE EXCEÇÕES & CASOS DE BORDA

- [!] **PENDENTE / NECESSITA AJUSTES** — `unbindTag()` não impede execução caso `getOwnerKey()` retorne `null`. Deveria bloquear e exigir digitação/validação da chave antes de prosseguir.
- [!] **PENDENTE / NECESSITA AJUSTES** — Nenhuma proteção contra sobrescrita maliciosa de tag já vinculada a outro usuário. `registerTag()` usa `upsert()` sem verificação de proprietário existente.
- [!] **PENDENTE / NECESSITA AJUSTES** — Nenhum mecanismo anti-replay para comando de reset (não há nonce / timestamp / hash HMAC no fluxo).

---

## 5. OBSERVações ARQUITETURAIS (ESP32 / Firmwares / Spec)

- [!] **NECESSITA AJUSTES — ESP32 (`main.cpp`)**: Firmware não possui GATT; não implementa `NVS` para `OWNER_SECRET_KEY`; não tem característica de escrita; não implementa `crc8` no payload de 6 bytes conforme especificado no `ble_service.dart` (o CRC existe no parser do app, mas o `main.cpp` usa `crc8` apenas para integridade do payload, não para validação de chave); payload layout não corresponde ao documento `payload-spec.md` (bytes estão em ordem diferente do spec solicitado pelo usuário: status/bateria/contador/modo/ID).
- [!] **NECESSITA AJUSTES — `payload-spec.md`**: Verificar se a ordem dos bytes no ESP32 corresponde ao `ble_service.dart` (atualmente: payload[0]=ID low, payload[1]=ID high, payload[2]=status, payload[3]=battery, payload[4]=mode, payload[5]=crc — ordem inversa do spec solicitado pelo usuário).

---

## RESUMO — STATUS GERAL

| Item | Status | Ação Recomendada |
|---|---|---|
| 1. Geração chave no registro | [!] PENDENTE | Implementar `generateSecretKey()` em `register()`; salvar em `SharedPreferences`; associar ao registro Supabase |
| 2. Fluxo anti-reset via GATT | [!] PENDENTE / BLOCKED | Arquitetura é connectionless; requer decisão de design: (a) manter connectionless e aceitar risco; (b) adicionar GATT temporário apenas para reset, com impacto de bateria |
| 3. `unbindTag` valida chave | [!] PENDENTE | Adicionar `if (key == null) throw` no início; ordenar: validar → reset ESP32 → remover Supabase → limpar local |
| 4. Alerta 0xFF | [x] OK | Implementado no app; **falta origem no ESP32** |
| 5. Guards anti-malicious | [!] PENDENTE | Adicionar `upsert` com verificação de usuário proprietário; adicionar HMAC/nonce se GATT for implementado |

---

*Arquivo gerado para auditoria de segurança. Nenhuma correção aplicada automaticamente no ESP32 (requer reflashing de firmware); correções móveis foram aplicadas em arquivos Flutter (ver commits anteriores).*
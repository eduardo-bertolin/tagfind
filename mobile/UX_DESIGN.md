# UX Redesign Plan — TagFind Mobile (HIGH)

Status: **APROVADO** (`proceed` recebido do usuário)
Commit referência design: `3d6d2b7`

## Fase 1 — Entendimento

- **Tier:** HIGH
- **App:** TagFind (Flutter, BLE, Supabase, dark + amber)
- **Telas analisadas:** HomePage (tags + scanner tabs), ScannerPage (BLE feed), TagDetailPage (configuração + resgate)
- **Problemas detectados:** Hierarquia confusa, status por cor apenas, falta de recuperação clara, slider sem rótulos acessíveis

## Fase 2 — Design

### Princípios (7 max)
1. P0 visível sem scroll (status, instrução, CTA)
2. Recuperação em todo estado (erro → retry, vazio → vincular)
3. Tokens antes de valores arbitrários
4. Acessibilidade obrigatória (semântico, contraste, foco)
5. Sem linguagem vaga ("moderno", "premium") — comportamentos concretos
6. Status por texto + cor (não só cor)
7. Redução de movimento respeitada

### Hierarquia (P0→P3)
- P0: Título, status (texto + cor), instrução, CTA, botão quick action
- P1: Explicação de energia, aviso de segurança
- P2: Chips informativos (bateria, distância), breakdown de modo
- P3: Recuperação (unbind, erro)

### Estados (10 max)
Initial / Empty / Ready / In progress / Lost / Normal / Error / Offline / Locked / Permission denied
- Todo estado tem recuperação definida
- Perda: ativação requer confirmação (dialog)
- Unbind: loading dialog com explicação (3-5s, requer proximidade)

### Interações (8 max)
- ToggleLostMode: confirma quando ativa; desativa direto
- SaveContactInfo: salva com spinner; preserva texto em falha
- StartScan: FAB toggle; banner animado com pulso
- OpenRescuePage: botão externo + URL selecionável; não navega sem ação

### Layout responsivo
- Small compact (≤374pt): CTA acima da dobra, bottom sheet ≤85% altura
- Standard (375-430pt): layout padrão
- Large (430pt+): margens maiores, opcional painel lado

### Wireframes
3 telas principais com blocos rotulados, prioridades P0/P1, sticky nav, scroll list, bottom sheet.

### Design Visual
- **Mood:** Calmo e confiável — superfície escura (`#121212`), superfície elevada (`#252525`), uma cor de destaque (âmbar `#FFC700`) exclusivamente para CTAs primárias
- **Cor:** Action primary (`amber`), state error (`danger`), state success (`success`), muted (`onSurfaceVariant`)
- **Tipo:** Inter, títulos SemiBold 20pt, corpo Regular 14pt
- **Ícones:** 20px outline; decorativo escondido do screen reader
- **Cards:** radius 16pt, borda 1px (`cardBorder`), elevação 0
- **Espaçamento:** token `spacing.md` (8pt) / `spacing.lg` (16pt)
- **Evitar:** ilustração que empurre CTA abaixo da dobra; animação decorativa em loop

### Movimento
- Bottom sheet: short (180ms) fade + translateY
- Spinner: contínuo sutil
- Confirmação sucesso: short (150ms) + texto
- Erro: sem shake; snackbar específico

### Acessibilidade (MUST/MUST NOT)
- MUST: label semântico no CTA (descreve resultado, não apenas visual)
- MUST: conteúdo bloqueado/perdido comunicado por texto, não só ícone
- MUST: erro específico + recuperação
- MUST: ícones decorativos escondidos (`Semantics(hidden: true)`)
- MUST: aviso crítico não só por cor
- MUST: fonte escala sem clip ou ação oculta
- MUST: targets mínimos (plataforma / WCAG 2.5.8)
- MUST: controles desativados explicam por que
- MUST: ordem de foco lógica; re-gerenciado após modal/sheet
- MUST: mudança de estado com anúncio
- MUST: movimento reduzível; nunca obrigatório

### Token & Component Spec
- Background: `color.background.canvas` (`#121212`)
- Surface container low: `surfaceContainerLow` (`#252525`)
- Elevated surface: `card` (`#1C1C1C`)
- CTA: `color.action.primary` (`#FFC700`), `radius.md`
- Text secondary: `color.text.secondary` (`#A3A3A3` — `onSurfaceVariant`)
- Icon: `size.icon.md` (20pt), `color.icon.muted`
- Card: `radius.lg`, `border.width 1px`, `surface` token
- Sem token encontrado: `No token found — Recommend adding [token]`

### Microcópia (exemplos-chave)
- Título: "TagFind" (P0)
- Status: "NORMAL — Seu item está seguro" / "PERDIDO — Item perdido"
- CTA: "Ativar Modo Perda" / "Desativar Modo Perda" / "Salvar alterações"
- Recuperação: "+ Vincular Nova Tag" (vazio) / "Tentar novamente" (erro)
- Confirmação: lista de passos + tempo estimado (3-5s) + URL
- Sem jargão; sem culpa ao usuário; sem promessas indisponíveis

### Condições de Parada
Nenhuma acionada no projeto. Todos os objetivos claros, recuperação definida, sistema de tokens existente.

### Implementação Handoff
- Componentes reutilizados: `AppScaffold`, `NavigationBar`, `Card`, `ElevatedButton`, `SnackBar`, `BottomSheet`
- Acessibilidade: `Semantics` adicionados; `semanticsLabel` em status, chips, botões; `excludeSemantics` em decorativo
- Localização: chaves sugeridas (`journey.locked.title`, etc.); ARB não implementado ainda
- Análise: `flutter analyze`
- Visual QA: necessário em dispositivo real (emulador sem BLE real); screenshots antes/depois

### Plano de Usabilidade
5 testes: identificar propósito, primeira ação, recuperação de erro, texto grande (200%), identificação de ícone.

### Verificação (comandos)
- `flutter analyze` + `flutter test`
- `rg` para busca de componentes
- Preview visual: compacto pequeno (CTA visível), padrão, grande (sem esticamento)
- Se screenshot indisponível: `Visual QA não disponível — requer revisão manual antes do merge.`

### Approval Gate
- Tarefa HIGH ✅
- Afeta navegação/comportamento central ✅
- Tela sensível (religiosa/viagem/cultural) ✅
- Requer novos componentes do sistema ❌ (reutiliza tokens/componentes existentes)
- Afeta confiança/dados (resgate público, contato) ✅
- Nenhuma condição de parada não resolvida ✅
- Aprovação solicitada: `proceed` recebida ✅

---
Arquivo: `UX_DESIGN.md`
Base: `C:\Users\User\.config\opencode\skills\mobile-ui-ux-designer`
Estado: IMPLEMENTADO PARCIALMENTE (tema + home_page corrigidos; design completo documentado)
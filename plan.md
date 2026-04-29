# Plan: Canasta Uruguaya — MVP Móvil 2v2 con IA y FX Balatro

## TL;DR
Construir desde cero un juego 2v2 de Canasta Uruguaya en Godot 4.6 Mobile (Android), con FSM determinista para reglas, fanning paramétrico, IA heurística para bots, multiplayer LAN host-autoritativo (ENet) y un subset cuidado de FX inspirados en Balatro (hover oscilador + tilt fake_3D, fanning sine-breath, dissolve, squishy UI, level-up popup, loading fluid). Entregable en 9 fases (F1–F9) verificables independientemente, sin infraestructura remota: matchmaking por código de sala vía UDP broadcast en LAN, reconexión y perfil persistidos en `user://`.

## Decisiones tomadas (de la entrevista)
- **Sin infra remota** → host-autoritativo en LAN; un teléfono = peer 1.
- **Transporte**: ENetMultiplayerPeer (UDP) en LAN, puerto 8910 por defecto. Discovery via UDP broadcast (PacketPeerUDP) en puerto 8911 + “código de sala” de 6 chars que codifica IP+puerto+token.
- **Alcance MVP**: 2v2 (4 jugadores en equipos). Mezcla humano/bot por slot vacío.
- **IA heurística** desde MVP (tutorial + práctica + relleno de slots).
- **Backend = cero infra**: cuenta anónima en `user://profile.cfg` (UUID + nickname), matchmaking por código de sala LAN, snapshot de partida en `user://saves/<match_id>.bin` para reconexión.
- **Assets de cartas**: generación procedural a partir de SVG paramétrico (palo + rango compuestos en runtime, atlas en build).
- **Balatro scope**: REUTILIZAR hover oscilador + fake_3D, fanning sine-breath, dissolve. ADAPTAR squishy toggle, level-up popup, loading_fluid. DESCARTAR vhs.gdshader y oil.gdshader (coste GPU móvil prohibitivo).
- **Tests**: GdUnit4 (mejor soporte async/multiplayer que GUT).
- **Limitación de seguridad documentada**: el host es jugador → puede teóricamente alterar RNG / ver manos rivales. Aceptable solo para partidas privadas con conocidos. Para producción comercial competitiva habría que añadir Fase 10 (servidor neutral). Se dejará la capa de red abstraída detrás de `INetworkAuthority` para migrar sin reescribir el rules engine.

---

## Estado actual del repo (verificado)

| Área | Hallazgo | Evidencia |
|---|---|---|
| Project | Godot 4.6 Mobile, Jolt Physics, sin scenes/ ni autoloads | `project.godot:13-21` |
| Código del juego | **Inexistente**: no hay scripts, escenas, resources. Solo `icon.svg` | `list_dir` raíz |
| Docs | Architecture doc completo y autoritativo (FSM, fanning, RPCs) | `docs/arquitectura-canasta-uruguaya.md` |
| Convenciones | Resource Cards, FSM Game Loop + CardUI, drag&drop táctil, mobile flags | `CLAUDE.md:25-50` |
| Addon MCP | Activo, 169 herramientas (play_scene, simulate_action, capture_frames, watch_signals, run_test_scenario, assert_node_state, get_performance_monitors). Crítico para QA | `addons/godot_mcp/skills.es.md:60-180` |
| Balatro refs | 11 carpetas, 4 shaders propios + 3 shared. Marcadas con `.gdignore` en `medias/` | `docs/balatro/scenes/*` |

---

## Mapeo Balatro → Canasta Uruguaya

| Recurso Balatro | Ruta clave | Mecánica Canasta destino | Decisión | Coste GPU móvil |
|---|---|---|---|---|
| `card.gd` (oscilador, hover scale, click drag, shadow parallax) | `docs/balatro/scenes/balatro/scripts/card.gd:36-145` | `CardUI` Hovered/Dragging states; sombra dinámica relativa al centro de la mesa | **REUTILIZAR** core; portar `_on_gui_input` a `InputEventScreenDrag` y reemplazar `_on_button_down` por `_get_drag_data` | Bajo |
| `fake_3D.gdshader` (perspectiva por uniform x/y_rot) | `docs/balatro/scenes/shared/shaders/fake_3D.gdshader` | Tilt 3D al hover sobre carta; rotación al “bajar” canasta | **REUTILIZAR** tal cual | Bajo (matriz 3x3 + un sample) |
| `dissolve.gdshader` + tween destruir | `docs/balatro/scenes/shared/shaders/dissolve.gdshader` + `card.gd:43-49` | Descarte al pozo (carta se disuelve hacia el pozo); cierre de mano | **REUTILIZAR**, requiere noise texture en atlas | Bajo |
| `drawn_cards.gd` (fanning + sine breathing + tween rot) | `docs/balatro/scenes/balatro/scripts/drawn_cards.gd:1-90` | `HandLayout` paramétrico; soporta 20+ cartas tras robo doble | **REUTILIZAR** matemática (`lerp_angle`, `position.y += sin(...)`); refactor a método `relayout(num_cards)` y aceptar cartas dinámicas | Bajo |
| `squishy_toggle.gd` (TRANS_ELASTIC squash + color tween) | `docs/balatro/scenes/squishy_toggle/squishy_toggle.gd:34-95` | Toggle de settings (sonido, vibración) y botón “cerrar mano” con confirmación | **ADAPTAR** | Cero |
| `level_up.gd` (count-up + particles + scale-in card) | `docs/balatro/scenes/level_up/level_up.gd:18-63` | **Score popup post-mano** (pure/impure/aces canasta bonuses, treses rojos, total mano) | **ADAPTAR** | Bajo (GPUParticles2D <100 partículas) |
| `loading_fluid.gdshader` (sine-wave progress) | `docs/balatro/scenes/loading_fluid/loading_fluid.gdshader` | Pantalla de transición entre manos / “mezclando mazo” | **ADAPTAR** | Bajo |
| `button_fill_animate.gd` (slide color hover) | `docs/balatro/scenes/button_fill_animate/button_fill_animate.gd` | Botones de menú principal y “robar / capturar pozo / descartar” | **ADAPTAR** | Cero |
| `cards_stack.gd` (deck stack + flick gesture) | `docs/balatro/scenes/cards_stack/scripts/cards_stack.gd` | Visualización del **mazo de robo**; flick = robo doble obligatorio | **ADAPTAR** matemática del stack; sustituir gesto velocity-based por tap (móvil) | Bajo |
| `vhs.gdshader` (warp+aberration+grille+noise full-screen) | `docs/balatro/scenes/balatro/shaders/vhs.gdshader:90-200` | — | **DESCARTAR** (10+ samples/pixel + 4 trig fns; mata gama media) | Alto |
| `oil.gdshader` (FBM 6 octavas full-screen) | `docs/balatro/scenes/balatro/shaders/oil.gdshader` | — | **DESCARTAR** | Alto |
| `wrip.gdshader` (radial twist) | `docs/balatro/scenes/balatro/shaders/wrip.gdshader` | Quedó fuera del alcance del usuario | **DESCARTAR del MVP** (re-evaluar como FX puntual de “pozo cruzado” en Fase 10) | Medio |
| `noise_move.gdshader` | `docs/balatro/scenes/balatro/shaders/noise_move.gdshader` | Trivial — no aporta | **DESCARTAR** | — |

---

## Arquitectura objetivo

### Estructura de carpetas
```
res://
├── autoloads/
│   ├── game_config.gd            # constants, enums, opening thresholds
│   ├── rng_service.gd            # seeded RandomNumberGenerator
│   ├── network_authority.gd      # interface + ENet impl
│   ├── audio_bus.gd              # SFX/Music/UI bus controller
│   └── profile_store.gd          # user://profile.cfg
├── resources/
│   ├── card.gd                   # class_name Card extends Resource
│   ├── card.tres                 # 108 instancias generadas por tool script
│   ├── match_config.gd           # class_name MatchConfig (n_players, target_score)
│   ├── rule_set.gd               # class_name RuleSet (thresholds, bonuses)
│   └── team_state.gd             # class_name TeamState (score, opened, has_canasta)
├── core/
│   ├── deck.gd                   # build_108(), shuffle(seed), draw(n)
│   ├── hand.gd                   # add/remove/find natural matches
│   ├── meld.gd                   # class_name Meld + MeldType enum + validators
│   ├── score_calculator.gd      # canasta bonuses, red threes, penalties
│   ├── opening_threshold.gd      # static fn(team_score) -> int
│   ├── pozo_controller.gd        # taponado/cruzado state, top card peek
│   └── rules_engine.gd           # high-level validators usado por servidor
├── fsm/
│   ├── state.gd                  # base state
│   ├── state_machine.gd          # generic FSM
│   └── states/                   # State_InitMatch, _SetupPozo, _DrawPhase, _PlayPhase, _DiscardPhase, _RoundEnd, _MatchEnd
├── ai/
│   ├── ai_player.gd              # interface
│   └── heuristic_bot.gd          # turn evaluator (decide robar/capturar, qué bajar, qué descartar)
├── network/
│   ├── i_network_authority.gd    # interface (host_authoritative API)
│   ├── enet_authority.gd         # ENetMultiplayerPeer impl
│   ├── lan_discovery.gd          # UDP broadcast advertise/scan + room codes
│   ├── rpc_router.gd             # request_* server-side validation hub
│   ├── snapshot.gd               # serialize/deserialize match state
│   └── reconnection.gd           # save/load + replay missed events
├── scenes/
│   ├── Main.tscn                 # entry (loading_fluid → menu)
│   ├── Menu.tscn                 # main menu, settings (squishy_toggle)
│   ├── Lobby.tscn                # crear/unirse por código + slots bot/humano
│   ├── Match.tscn                # mesa 2v2 (4 manos) + pozo + mazo
│   └── tutorial/                 # escenas guiadas paso a paso
├── ui/
│   ├── card_ui.tscn / .gd        # FSM Idle/Hover/Drag/Released
│   ├── hand_layout.gd            # fanning paramétrico + sine breathing
│   ├── remote_hand.tscn          # cartas dorso (opponent_card_count)
│   ├── drop_zone.tscn / .gd      # _can_drop_data, _drop_data
│   ├── melds_table.tscn          # canastas en mesa por equipo
│   ├── score_popup.tscn          # adapt level_up.gd
│   ├── pozo_view.tscn            # top card + estado taponado/cruzado
│   ├── deck_view.tscn            # adapt cards_stack
│   └── transitions/              # loading_fluid wrappers
├── shaders/
│   ├── fake_3d.gdshader          # copy from balatro/shared
│   ├── dissolve.gdshader         # idem
│   └── loading_fluid.gdshader    # idem
├── fx/
│   ├── card_hover_oscillator.gd  # extraído de card.gd Balatro
│   ├── confetti.tscn             # GPUParticles2D para canasta
│   └── screen_shake.gd           # Camera2D shake controller
├── tools/
│   └── generate_card_atlas.gd    # @tool: SVG → AtlasTexture 108 cartas
└── tests/                        # GdUnit4
    ├── unit/                     # rules_engine, score_calculator, opening_threshold
    ├── fsm/                      # state transitions
    └── integration/              # 2v2 simulada headless
```

### Resources / clases clave

| Clase | Tipo | Campos principales |
|---|---|---|
| `Card` | Resource | `suit: Suit`, `rank: Rank`, `point_value: int`, `is_wildcard: bool`, `is_red_three: bool`, `is_black_three: bool`, `id: int` (única) |
| `Meld` | Resource | `rank: Rank`, `cards: Array[Card]`, `naturals: int`, `wilds: int`, `is_canasta: bool`, `is_pure: bool`, `team_id: int` |
| `MatchConfig` | Resource | `n_players: 4`, `teams: 2`, `target_score: 7000`, `seed: int` |
| `RuleSet` | Resource | bonos canastas, umbrales apertura, penalizaciones |
| `TeamState` | Resource | `score`, `cum_score`, `opened: bool`, `melds: Array[Meld]` |
| `MatchSnapshot` | Resource | mazo, pozo, manos privadas (cifradas por peer), turn_idx |

### Componentes principales

| Componente | Responsabilidad | Ejecución |
|---|---|---|
| `GameStateMachine` | FSM Game Loop (5 estados núcleo + Round/Match end) | **Solo en host** |
| `RulesEngine` | Validar capturar pozo, bajar combinación, abrir, cerrar | **Solo en host** |
| `RpcRouter` | Recibe `request_*`, llama a RulesEngine, ejecuta o rechaza, difunde | **Solo en host** |
| `NetworkAuthority` (ENet) | Crear servidor, conectar peer, MultiplayerSynchronizer per-hand visibility | Host + clientes |
| `HeuristicBot` | Decide acciones; expone misma API que un cliente humano (envía `request_*`) | Host (en proceso del peer 1) |
| `CardUI` + `HandLayout` | UI fanning, drag&drop, FSM por carta | Cada cliente |
| `RemoteHand` | Renderiza N cartas dorso por peer remoto | Cada cliente |
| `ScoreCalculator` | Sumar canastas + treses + penalizaciones al `State_RoundEnd` | Host |

---

## Plan por fases

### F1 — Fundaciones (paralelizable: parcial)
**Objetivo**: proyecto listo para escribir lógica con autoloads, mazo determinista y settings móviles.

- Configurar `project.godot`: `display/window/handheld/orientation=portrait`, `input_devices/pointing/emulate_touch_from_mouse=true`, `display/window/vsync/vsync_mode=2` (mailbox), `application/run/main_scene=res://scenes/Main.tscn`.
- Autoloads: `GameConfig`, `RngService`, `ProfileStore`.
- `resources/card.gd` (class_name Card) + `tools/generate_card_atlas.gd` (@tool, genera 108 .tres con seed).
- `core/deck.gd` con `build_standard_108()`, `shuffle(rng)`, `draw_n(n)`.
- Carpeta `tests/unit/` y `gdunit4` instalado vía AssetLib.
- **Archivos**: `autoloads/*.gd`, `resources/card.gd`, `core/deck.gd`, `tools/generate_card_atlas.gd`, `project.godot`.
- **Criterios de aceptación**:
  - `godot --headless` arranca sin errores.
  - Test unitario: `Deck.build_standard_108()` devuelve 108 cartas con composición exacta (4 jokers, 8 doses, 8 ases, etc.).
  - `Deck.shuffle(rng_seed=42)` es reproducible.
  - 108 atlas cards se ven en preview de inspector.

### F2 — Core rules engine offline (depende de F1)
**Objetivo**: motor de reglas auditable con cobertura de tests; juega solo, sin UI.

- `core/meld.gd`, `core/score_calculator.gd`, `core/opening_threshold.gd`, `core/pozo_controller.gd`, `core/rules_engine.gd`.
- `fsm/states/state_init_match.gd`, `state_setup_pozo.gd`, `state_draw_phase.gd`, `state_play_phase.gd`, `state_discard_phase.gd`, `state_round_end.gd`, `state_match_end.gd`.
- Validadores:
  - Captura pozo: ≥2 naturales del rango del top + cumple umbral si no abrió.
  - Pozo taponado (Tres Negro top): zona deshabilitada → forzar robo doble.
  - Pozo cruzado (comodín top): no se permite usar comodines en la captura, sólo emparejamiento natural exacto.
  - Bajada: rango uniforme; ratio comodines (≤3 por meld de 4+ naturales).
  - Cierre: ≥1 canasta pura **y** ≥1 impura del equipo.
  - Treses rojos: auto-roban reemplazo, +100 c/u, +800 si los 4; invertidos a negativo si equipo cierra sin canastas.
  - Penalización 4 Treses Negros al cierre: −500.
  - Robo fuera de orden: −100.
- **Archivos**: `core/*.gd`, `fsm/**/*.gd`, `tests/unit/`, `tests/fsm/`.
- **Criterios de aceptación**:
  - Cobertura GdUnit4 ≥85% en `core/`.
  - Test integración headless: simular partida 2v2 con `RngService(seed=1)` que termina con un equipo ≥7000 puntos en ≤N rondas.
  - Test: pozo taponado deshabilita captura para el siguiente turno.
  - Test: cierre rechazado si solo hay canasta impura.
  - Test: cuatro treses rojos invertidos cuando equipo no tiene canastas.

### F3 — UI base móvil (paralelizable con F2)
**Objetivo**: una mano humana se ve, se ordena, se arrastra. Sin red.

- `ui/card_ui.tscn/.gd` con FSM (Idle/Hover/Drag/Released) — **portar `card.gd` Balatro**.
- `ui/hand_layout.gd` — **portar `drawn_cards.gd`**: parametrizar para n cartas, animación re-layout en `Tween` cuando hay add/remove.
- `ui/drop_zone.tscn/.gd` — sobreescribir `_can_drop_data` / `_drop_data`.
- `ui/melds_table.tscn`, `ui/pozo_view.tscn`, `ui/deck_view.tscn` (adapt cards_stack).
- `scenes/Match.tscn` modo offline (hot-seat 4 humanos para QA visual).
- **Archivos**: `ui/**`, `scenes/Match.tscn`.
- **Criterios de aceptación**:
  - 20 cartas en mano sin solapamiento ilegible (fanning ≤±25°, espaciado dinámico).
  - Drag&drop con touch responde <50ms (medido con `get_performance_monitors`).
  - Re-layout tras add/remove dura 0.3s sin “salto”.
  - Drop sobre meld inválida → carta vuelve con tween_back, sin warning de consola.

### F4 — Capa visual Balatro-like (depende de F3)
**Objetivo**: aplicar el subset aprobado de FX, manteniendo presupuesto GPU móvil.

- Copiar `fake_3D.gdshader`, `dissolve.gdshader`, `loading_fluid.gdshader` a `shaders/`.
- `fx/card_hover_oscillator.gd` (extraer del Balatro card.gd: spring/damp + velocity).
- `ui/score_popup.tscn` adaptado de `level_up.gd`: count-up por bonus (pura 500, impura 200, comodines 2000/3000, ases 800/500, treses rojos, penalizaciones).
- `scenes/Menu.tscn` con `squishy_toggle` para settings (vibración, sonido).
- `ui/transitions/loading_fluid.tscn` entre `State_RoundEnd` y siguiente mano.
- `fx/screen_shake.gd` corto (0.2s) para canastrón.
- **Criterios de aceptación**:
  - 60fps sostenido en device target (Pixel 4a / similar gama media) con 4 manos visibles, fanning + tilt activos. Verificar con `get_performance_monitors` (`time/process`, `render/total_objects_drawn`).
  - Drawcalls totales <120 en `Match.tscn`.
  - Transición loading_fluid <600ms.

### F5 — Multiplayer LAN host-autoritativo (depende de F2)
**Objetivo**: dos teléfonos en la misma WiFi juegan 1v1; preparado para 2v2.

- `network/i_network_authority.gd` (interface).
- `network/enet_authority.gd`: `MultiplayerPeer` ENet, `create_server(8910)`, `create_client(ip, 8910)`.
- `network/lan_discovery.gd`: `PacketPeerUDP` broadcast en :8911 anunciando `{room_code, host_ip, n_players}`. Código sala = base32(SHA1(ip+token)[0..30 bits]) → 6 chars.
- `scenes/Lobby.tscn`: crear sala / scan / unir por código.
- `network/rpc_router.gd` con métodos `@rpc("any_peer","call_local","reliable")`:
  - `request_capture_pozo()`, `request_meld(card_ids, meld_id)`, `request_discard(card_id)`, `request_close_hand()`.
  - Server-side: validar via `RulesEngine`, mutar estado, difundir.
- `MultiplayerSynchronizer` por mano con `set_visibility_for(peer_id, owner_only)`. `RemoteHand` recibe sólo `opponent_card_count: int`.
- `network/snapshot.gd` + `reconnection.gd`: host serializa snapshot tras cada `State_DiscardPhase`. Si peer reconecta, host reenvía último snapshot + diff.
- **Criterios de aceptación**:
  - Dos clientes ENet en LAN sincronizan correctamente una partida 1v1 completa.
  - Cliente “tramposo” que invoque RPC con `card_ids` que no posee recibe rechazo y log auditable en host (`get_editor_errors`).
  - `RemoteHand` jamás contiene IDs reales de carta del oponente (verificable con `get_game_node_properties`).
  - Reconexión: matar cliente y volver a conectar → estado idéntico al snapshot del host en ≤2s.

### F6 — IA heurística (paralelizable con F5 desde F2)
**Objetivo**: bots que rellenan slots vacíos en 2v2 y juegan tutorial.

- `ai/ai_player.gd` interface.
- `ai/heuristic_bot.gd`:
  - Decisión robar/capturar: capturar si ≥2 naturales del rango top + suma cumple umbral; si no, robar doble.
  - Bajadas: priorizar canastas casi completas (≥6 cartas mismo rango). Limitar uso de comodines a ratio 3:4.
  - Descarte: minimizar info leak (descartar rango con menor probabilidad de ser perseguido); evitar dar pozo si rival está cerca de cierre.
  - Cierre: solo si tiene ≥1 pura + ≥1 impura y suma estimada > esperanza de pozo.
- Bot corre en host, dispara `request_*` igual que humano (zero special path → menos código y testeable).
- **Criterios de aceptación**:
  - Bot completa una mano sin invocar acciones inválidas en 100 simulaciones headless.
  - 2 bots vs 2 bots: partidas terminan (un equipo ≥7000) en ≤30 manos en mediana.
  - Logs de decisión exportables para análisis.

### F7 — Optimización móvil + accesibilidad táctil (depende de F4, F5)
**Objetivo**: 60fps estables, APK <50MB.

- Atlas único de cartas (uso `tools/generate_card_atlas.gd`).
- Pooling de `CardUI` (10 nodos reutilizables por mano).
- Batching: cartas del mismo padre → un solo `CanvasItem` draw.
- Tween reducer: agrupar tweens de re-layout en uno solo con `set_parallel`.
- Reducir GPUParticles2D a 80 partículas en score_popup.
- Hitboxes de drag agrandadas (×1.5) para dedos (referencia: Apple HIG mínimo 44pt).
- Vibración háptica en drop válido (`Input.vibrate_handheld(40)`).
- **Criterios de aceptación**:
  - 60fps medido con `get_performance_monitors` durante 3 min de juego activo en device gama media.
  - Memoria <250MB.
  - APK release <50MB.
  - Test de “gordura de dedo”: simular touch a ±20px del centro de carta → drag inicia.

### F8 — Testing & QA automatizado (depende de F2-F7, paralelizable por capa)
**Objetivo**: suite ejecutable en CI local + smoke E2E vía MCP.

- GdUnit4 unit tests (`tests/unit/`).
- FSM transition tests (`tests/fsm/`): cubrir cada arista del grafo.
- Integration: 2 instancias Godot headless interconectadas via ENet (`scripts/run_integration.sh`).
- E2E vía godot_mcp: scripts JSON de `run_test_scenario` que abren `Match.tscn`, simulan acciones (`simulate_action`), validan con `assert_node_state` y `compare_screenshots`.
- **Criterios de aceptación**:
  - `godot --headless --script tests/run_all.gd` retorna exit 0.
  - 3 escenarios E2E críticos automatizados vía MCP: (1) abrir + capturar pozo, (2) cerrar mano válido, (3) intento de cierre inválido rechazado.
  - Cobertura líneas en `core/` ≥85%.

### F9 — Build & release Android (depende de todas)
**Objetivo**: AAB firmado listo para Internal Testing en Play Console.

- Export preset Android (Gradle build, target SDK 34, min SDK 24).
- Permisos: `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE` (broadcast LAN), `VIBRATE`.
- Firma release con keystore en `~/.config/godot/keystores/canasta.jks` (NO commitear).
- Pantalla de splash + icono adaptativo.
- ProGuard/R8 reglas mínimas para Godot.
- `godot --path . --headless --export-release "Android" ./builds/canasta-uruguaya-v0.1.aab`.
- Checklist Play Store: política, edad, screenshots, descripción ES.
- **Criterios de aceptación**:
  - AAB instalable vía `bundletool` en device físico.
  - Inicio frío <3s en Pixel 4a.
  - LAN multiplayer funciona entre 2 dispositivos físicos en la misma WiFi.

---

## Riesgos y decisiones abiertas

| # | Riesgo | Probabilidad | Mitigación |
|---|---|---|---|
| R1 | Host puede manipular RNG/ver manos rivales | Alta (por diseño LAN) | Documentar limitación; abstraer `INetworkAuthority` para migrar a server neutral en Fase 10 sin reescribir reglas |
| R2 | Drag&drop táctil con 20+ cartas se siente “pegajoso” | Media | Hitboxes ×1.5, `Input.use_accumulated_input=false`, evaluar `_unhandled_input` vs `_gui_input` en device |
| R3 | UDP broadcast LAN bloqueado por router/AP isolation | Media | Fallback: input manual de IP del host en lobby |
| R4 | IA heurística predecible y aburrida | Media | F10 post-MVP: añadir capa MCTS/expectimax sobre la heurística existente |
| R5 | 2v2 implica 4 manos visibles → drawcalls disparados | Media | Pooling + atlas + reducir tilt 3D a la mano local solamente; oponentes con shader simplificado |
| R6 | Reconexión deja estado inconsistente si host crashea | Alta | F2 ya define `MatchSnapshot`; persistir post cada `State_DiscardPhase`. Si host muere, partida se cancela (aceptar limitación MVP) |
| R7 | Generación procedural de 108 cartas SVG → tiempo de build largo | Baja | Generar atlas una vez en build (`@tool`), cachear `.import` |
| R8 | Diferencias entre `InputEventScreenTouch` y mouse en debug | Baja | Tests siempre en device físico vía `adb` + MCP; no confiar en `emulate_touch_from_mouse` para QA final |

### Decisiones que requieren tu confirmación

| # | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| D1 | ¿Cuántas cartas reparte 2v2? El doc dice 11 c/u (`arquitectura:tabla 2.0`); confirmar | (A) 11 (estándar federación) / (B) 13 (variante doméstica) | **A** |
| D2 | ¿Target score MVP? | (A) 5000 rápida / (B) 7000 estándar / (C) configurable en lobby | **C** con default 7000 |
| D3 | ¿Valor del As? Doc menciona 15 o 20 según variante | (A) 15 / (B) 20 / (C) lobby option | **A** (más estándar) |
| D4 | ¿Treses Rojos `+100` o `+200` cuando ya hay canasta? | Doc dice 100; alguna variante 200 | **100** (FEFARA) |
| D5 | ¿Versión idiomática? | (A) ES-only / (B) ES + EN | **A** para MVP, i18n preparado vía `tr()` |
| D6 | ¿El bot puede abandonar humano? Si humano se desconecta y no reconecta en 60s, ¿bot toma su control? | (A) Sí (recomendado para que la partida termine) / (B) No, partida se anula | **A** |
| D7 | ¿Vibración háptica activa por defecto? | (A) On / (B) Off | **A** con toggle en settings |

---

## Plan de verificación

### Automatizado
- **Unit (GdUnit4)**: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit` → exit 0, cobertura ≥85% en `core/`.
- **FSM**: tests por estado en `tests/fsm/`. Cubrir todas las transiciones legales/ilegales.
- **Integración multiplayer**: `scripts/run_integration.sh` lanza 2 instancias headless, simula partida 1v1 hasta `State_MatchEnd`. Comparar `MatchSnapshot` final.
- **E2E vía MCP**: `run_test_scenario` con secuencia (open Match → simulate_action capture_pozo → assert_node_state pozo.empty=true → simulate_action discard → ...).
- **Visual regression**: `compare_screenshots` en pantallas clave (lobby, mesa 2v2 inicial, score popup) — usar archivos no base64.

### Manual
- Sesión QA en device físico (Pixel 4a + un emulador) por 30min cubriendo:
  - Capturar pozo abierto / taponado / cruzado.
  - Bajar canasta pura, impura, ases, comodines.
  - Cerrar mano válido / inválido (sin canastas).
  - Reconexión por desconexión WiFi (modo avión 5s).
  - Vibración + sonido.
  - Drag con dedos grandes (sticker en pantalla simulando dedo).
- Comprobar `get_performance_monitors` en device durante stress test (run_stress_test del MCP).

---

## Checklist de “listo para producción”

### Rendimiento
- [ ] 60fps mediana, 50fps p99 en device gama media (3 min juego activo).
- [ ] Drawcalls <120 en `Match.tscn`.
- [ ] Memoria pico <250MB.
- [ ] APK release <50MB.
- [ ] Inicio frío <3s.

### Seguridad
- [ ] Toda mutación de `Deck_Array`, `Discard_Pile_Array`, manos privadas ocurre **únicamente** en host (auditado vía `find_nodes_by_script` en cliente).
- [ ] RPCs server validan: turno, propiedad de cartas, umbral apertura, pozo state.
- [ ] `MultiplayerSynchronizer` con visibility por peer en cada mano.
- [ ] `RemoteHand` solo expone count.
- [ ] Rate limiting de RPC cliente (>10/s = kick).
- [ ] No hay claves/secretos en repo (verificar con `git secrets`).
- [ ] Limitación host-as-player documentada en README.
- [ ] Logs auditables en host (acciones rechazadas, peers conectados/desconectados).

### Accesibilidad táctil
- [ ] Hitboxes ≥44pt.
- [ ] Vibración háptica en drop.
- [ ] Modo daltónico (palos con símbolos diferenciables, no solo color).
- [ ] Tamaño de fuente escalable (≥14sp default).

### Build Android
- [ ] AAB firmado release.
- [ ] Permisos mínimos justificados.
- [ ] Splash + icon adaptive.
- [ ] Internal testing track en Play Console.

### Antifraude (en el alcance LAN)
- [ ] Server validation 100% de acciones.
- [ ] Snapshot determinista verificable (hash) entre host y client.
- [ ] Detección de RPC con frecuencia anómala.

### Observabilidad
- [ ] Logs locales rotativos en `user://logs/match_<id>.log`.
- [ ] Estadísticas de partida (duración, manos, errores) en `user://stats.json`.
- [ ] (Post-MVP) opt-in telemetría a backend si en algún momento existe.

---

## Preguntas pendientes
Las decisiones D1–D7 arriba. Si confirmas las recomendaciones, queda cerrado.

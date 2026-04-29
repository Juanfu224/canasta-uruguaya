# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

Juego de **Canasta Uruguaya** para móvil desarrollado en **Godot 4.6** (renderer: Mobile). El código está escrito en GDScript.

## Comandos comunes

```bash
# Abrir el proyecto en el editor de Godot
godot --path .

# Ejecutar el proyecto directamente (sin editor)
godot --path . --main-scene res://scenes/Main.tscn

# Ejecutar en modo headless (servidor dedicado)
godot --path . --headless

# Exportar para Android (requiere plantillas exportación instaladas)
godot --path . --export-release "Android" ./builds/canasta-uruguaya.apk
```

El addon `godot_mcp` expone un servidor WebSocket en el editor para inspección e interacción con la escena en tiempo real.

## Arquitectura de tres capas

### 1. Capa de lógica central (Rules Engine)

- Cada carta es un `Resource` personalizado con propiedades inmutables: palo, rango, valor en puntos.
- El flujo de partida se implementa como una **FSM** con estados: `State_InitMatch` → `State_SetupPozo` → `State_DrawPhase` → `State_PlayPhase` → `State_DiscardPhase`. Cada estado expone `_enter_state`, `_process_state`, `_exit_state`.
- La lógica de validación **solo corre en el servidor**; los clientes nunca mutan el estado global directamente.

**Reglas críticas a tener en cuenta:**
- Robo obligatorio de **dos cartas** por turno (no una, como en la canasta estándar). Esto hace que las manos crezcan a 20+ cartas.
- El pozo puede estar *taponado* (Tres Negro descartado) o *cruzado* (comodín descartado); cada estado cambia los requisitos para robarlo.
- Umbral de apertura dinámico según puntuación acumulada del equipo: `< 0 pts → 15`, `0–1495 → 50`, `1500–2995 → 90`, `≥ 3000 → 120`.
- Para cerrar la mano se requieren **al menos una canasta pura y una impura** en mesa.

### 2. Capa de interfaz móvil (UI)

- La disposición de cartas en mano usa **fanning paramétrico** (abanico): coordenadas X/Y/rotación calculadas con `normalized_x = float(i) / max(1, n-1)` más una curva cuadrática para el eje Y. Las posiciones se recalculan en cada inserción/remoción via `Tween`.
- Drag & Drop se implementa sobreescribiendo `_get_drag_data`, `_can_drop_data` y `_drop_data` en los nodos `Control`.
- Cada `CardUI` tiene su propia FSM: `Idle_State` → `Hovered_State` → `Dragging_State` → `Released_State`.
- Configuración requerida en el proyecto para móvil: `emulate_touch_from_mouse = true` (debug), `Input.use_accumulated_input = false`, VSync en `VSYNC_MAILBOX`.

### 3. Capa de red (Multiplayer autoritativo)

- Topología: **Servidor dedicado autoritativo**. El peer 1 (host) conserva el único estado verídico (`Deck_Array`, `Discard_Pile_Array`, manos privadas).
- Las acciones del cliente son **solicitudes RPC** al servidor (`rpc_id(1, "request_...")`). El servidor valida, ejecuta o rechaza y luego re-difunde con `MultiplayerSynchronizer`.
- Visibilidad selectiva: cada `MultiplayerSynchronizer` de la mano de un jugador solo se sincroniza a ese peer. El oponente recibe únicamente `opponent_card_count` para renderizar cartas-dorso (`RemoteHand`).
- Esto previene cheating por introspección de memoria o sniffing de paquetes.

## Referencia de reglas

| Tipo de canasta | Composición | Bono |
|---|---|---|
| Pura | 7 naturales | 500 |
| Impura | 4 naturales + hasta 3 comodines | 200 |
| Comodines impura | 7 comodines (Jokers + Doses mezclados) | 2.000 |
| Comodines pura | 7 Jokers o 7 Doses | 3.000 |
| Ases pura | 7 Ases naturales | 800 |
| Ases impura | 7 Ases con comodines | 500 |

**Penalizaciones:** robo fuera de orden −100; cuatro Treses Negros al cierre −500.
**Treses Rojos:** +100 c/u; los cuatro juntos = 800. Se invierten a negativos si el equipo termina sin canastas.

El documento de arquitectura completo está en `docs/arquitectura-canasta-uruguaya.md`.

# Arquitectura y Diseño de Sistemas para Canasta Uruguaya en Godot

> Integración Algorítmica de Reglas y Desarrollo de Aplicación Móvil

---

## Tabla de contenidos

1. [Introducción al Sistema de Lógica y Motor de Juego](#1-introducción-al-sistema-de-lógica-y-motor-de-juego)
2. [Formalización Matemática del Modelo de Reglas](#2-formalización-matemática-del-modelo-de-reglas-de-la-canasta-uruguaya)
   - [Tipología y valoración de las cartas](#21-tipología-estructural-y-valoración-analítica-de-las-cartas)
   - [Sistemas dinámicos del pozo y regla "Robar Dos"](#22-sistemas-dinámicos-del-pozo-y-la-regla-exclusiva-robar-dos)
   - [Requisitos algorítmicos de apertura continua](#23-requisitos-algorítmicos-de-apertura-continua)
   - [Parametrización de canastas y condiciones de cierre](#24-parametrización-de-canastas-y-condiciones-restrictivas-de-cierre)
3. [Ingeniería de la Lógica Central mediante FSM](#3-ingeniería-de-la-lógica-central-mediante-máquinas-de-estados-finitos-fsm)
   - [FSM del Game Loop](#31-arquitectura-de-la-máquina-de-estados-del-flujo-de-partida-game-loop-fsm)
   - [FSM de las cartas (CardUI)](#32-máquina-de-estados-micro-transaccional-de-las-cartas-visuales-cardui-fsm)
4. [Interfaz y UX para Entornos Móviles](#4-desarrollo-arquitectónico-de-la-interfaz-y-ux-para-entornos-móviles)
   - [Drag and Drop táctil](#41-paradigmas-de-interacción-táctil-y-la-api-dinámica-de-arrastre-drag-and-drop)
   - [Disposición radial (Card Fanning)](#42-matemáticas-paramétricas-para-la-disposición-radial-de-la-mano-card-fanning)
5. [Sincronización en Red y Servidor Autoritativo](#5-arquitectura-de-sincronización-en-red-y-modelo-servidor-autoritativo)
   - [Aislamiento del estado global](#51-el-prisma-autoritativo-y-el-aislamiento-restrictivo-del-estado-global)
   - [Validación procedural y RPCs](#52-validación-procedural-y-secuencias-de-comando-remoto-rpc)
6. [Conclusiones Integrales](#6-conclusiones-integrales-y-síntesis-arquitectónica-y-metodológica)
7. [Obras citadas](#obras-citadas)

---

## 1. Introducción al Sistema de Lógica y Motor de Juego

La adaptación de juegos de naipes tradicionales de alta complejidad a entornos digitales móviles requiere una transcripción algorítmica rigurosa de sus normativas, sumada a una arquitectura de software capaz de gestionar interacciones táctiles y sincronización multijugador segura. La **Canasta Uruguaya**, una derivación evolutiva sudamericana del Rummy tradicional, presenta un nivel de complejidad sistémica notablemente superior al de las variantes clásicas o modernas estandarizadas. Esta complejidad algorítmica radica en sus dinámicas únicas de robo múltiple de cartas, las estrategias de bloqueo del pozo mediante naipes de restricción y las fluctuaciones drásticas de puntuación que están directamente condicionadas por el estado global matemático de la partida.[^1] Desarrollar un simulador digital fiel y competitivo para este juego exige mucho más que una simple representación gráfica; requiere el establecimiento de un motor de reglas determinista.

El desarrollo de este sistema utilizando el motor de código abierto **Godot 4.x** proporciona un marco de trabajo excepcionalmente adecuado debido a la naturaleza orientada a objetos de sus nodos y a sus capacidades inherentes para la manipulación de estados.[^3] La creación de una aplicación móvil para la Canasta Uruguaya exige una planificación estructurada que divida el proyecto en tres capas arquitectónicas fundamentales:

1. **Capa de lógica central de reglas** — procesa y valida todas las operaciones matemáticas y lógicas del juego.
2. **Capa de interfaz de usuario móvil** — debe lidiar con las limitaciones físicas del tamaño de pantalla y la fluidez de las interacciones táctiles.[^4]
3. **Capa de red multijugador** — emplea los sincronizadores de estado de Godot para establecer un modelo de servidor autoritativo capaz de prevenir vulnerabilidades de seguridad cibernética e interceptación de datos.[^6]

El presente informe detalla de manera exhaustiva las normativas de la Canasta Uruguaya y establece un marco arquitectónico completo para su implementación técnica en un aplicativo móvil utilizando Godot, garantizando fluidez, seguridad algorítmica y estricta fidelidad a las regulaciones de la federación.

---

## 2. Formalización Matemática del Modelo de Reglas de la Canasta Uruguaya

Para poder programar el modelo de datos subyacente del juego, resulta un requisito imperativo estructurar matemáticamente todas las reglas de la Canasta Uruguaya. A diferencia de las versiones clásicas, esta variante introduce mecánicas de aceleración de mano y bloqueos tácticos que alteran fundamentalmente el flujo del árbol de decisiones, impactando el diseño de cualquier inteligencia artificial o del validador maestro de un servidor dedicado.

La meta algorítmica principal del juego consiste en acumular un volumen predeterminado de puntos a través de la ejecución de múltiples rondas sucesivas (manos). Las directrices de puntuación estipulan:

- **Partida rápida:** finaliza al alcanzar o superar **5.000 puntos**.
- **Partida estándar / torneo:** finaliza al alcanzar o superar **7.000 puntos**.[^2]

La versatilidad de la Canasta Uruguaya permite acomodar diversas configuraciones de jugadores, lo cual obliga al sistema de reparto a ser altamente paramétrico:[^8]

| Configuración | Modalidad | Cartas iniciales por jugador |
| --- | --- | --- |
| 2 jugadores | Individual | 15 |
| 3 jugadores | Individual | 13 |
| 4 jugadores | Equipos (2v2) | 11 |
| 6 jugadores | Equipos (3v3) | 11 |

El **mazo global** se compone de **dos barajas inglesas completas con sus comodines**, totalizando **108 cartas**.[^9]

### 2.1 Tipología Estructural y Valoración Analítica de las Cartas

Cada carta debe instanciarse como un `Resource` personalizado en Godot, almacenando propiedades inmutables (palo, rango, valor en puntos). Esta estructuración orientada a datos facilita el cálculo automático de sumatorias durante las bajadas y el conteo final.

| Clasificación | Identificador (Rango) | Valor | Rol funcional |
| --- | --- | --- | --- |
| Comodín Mayor | Joker | 50 | Variable dinámica; sustituye cualquier carta natural.[^10] |
| Comodín Menor | Dos (2) | 20 | Sustituye cartas naturales en matrices de evaluación.[^10] |
| Naturales Altas | As (A) | 15 (20 en algunas variantes) | Esencial para canastas específicas de alto valor.[^10] |
| Naturales Medias | K, Q, J, 10, 9, 8 | 10 | Conformación de canastas comunes.[^10] |
| Naturales Bajas | 7, 6, 5, 4 | 5 | Volumen para canastas.[^10] |
| Bonificación | Tres Rojo (♥, ♦) | 100 (bonificable) | Disparan robo automático asíncrono al ingresar a la mano.[^10] |
| Restricción | Tres Negro (♠, ♣) | 100 (penalización) | Bloqueador lógico del pozo; no se combinan excepto al cierre.[^10] |

### 2.2 Sistemas Dinámicos del Pozo y la Regla Exclusiva "Robar Dos"

El elemento de mayor divergencia arquitectónica de la Canasta Uruguaya respecto de la canasta moderna estándar es la mecánica de robo y la utilización del pozo. Al inicio de su turno, el jugador activo enfrenta una **bifurcación lógica estricta**:

**Rama A — Capturar el pozo:** El cliente debe demostrar tener en mano un mínimo de **dos cartas naturales** que empaten exactamente con el rango de la carta del tope del pozo.[^1] Además, los valores sumados (incluyendo cualquier bajada acompañante) deben satisfacer o exceder la barrera de apertura del equipo, si aún no han abierto.[^1]

**Rama B — Robo forzado de DOS cartas (regla uruguaya):** Si el jugador no puede o no quiere capturar el pozo, el algoritmo le obliga a extraer **dos cartas consecutivas** de la cabecera del mazo de reservas.[^1] Tras evaluar y bajar combinaciones, debe finalizar el turno descartando exactamente **una** carta al pozo.[^1]

> **Implicación de UI:** Esta regla acelera el crecimiento de las manos, exigiendo que la interfaz móvil maneje volúmenes elevados de cartas concurrentes (≥ 20).

**Estados del pozo:**

- **Pozo taponado** — al descartar un Tres Negro, un booleano marca el pozo como clausurado; el motor inhabilita la zona de captura para el siguiente jugador, forzando la ruta del robo doble.[^1]
- **Pozo cruzado/castigado/vulnerado** — al descartar un comodín horizontal/ortogonal; endurece los requisitos para futuros robos, exigiendo emparejamientos naturales precisos sin asistencia de comodines.[^2]

### 2.3 Requisitos Algorítmicos de Apertura Continua

La primera bajada del equipo (apertura) debe superar un umbral aritmético dinámico que se ajusta en función de la puntuación acumulada del equipo:[^2]

| Estado de puntuación acumulativa del equipo | Barrera de apertura |
| --- | --- |
| Puntuación deficitaria (< 0) | 15 puntos (sin barrera efectiva) |
| Fase inicial (0 – 1.495) | 50 puntos |
| Fase intermedia (1.500 – 2.995) | 90 puntos |
| Fase avanzada/terminal (≥ 3.000) | 120 puntos |

El controlador de lógica debe iterar el conjunto propuesto y calcular la sumatoria antes de enviar la confirmación al servidor. Si la sumatoria es inferior a la barrera, la acción se rechaza y los nodos gráficos se interpolan de regreso a la mano con alertas visuales.[^2]

### 2.4 Parametrización de Canastas y Condiciones Restrictivas de Cierre

Una **canasta** es una colección de **siete cartas del mismo rango**.[^1] El acto de **cortar** (cerrar la mano) exige condiciones estrictas: el equipo debe haber instanciado en mesa **al menos una canasta pura y al menos una impura**.[^10]

**Bonificaciones por canasta:**

| Tipo de canasta | Composición | Bono |
| --- | --- | --- |
| Pura (limpia) | 7 naturales | **500**[^10] |
| Impura (sucia) | 4 naturales + hasta 3 comodines | **200**[^10] |
| Comodines sucia | 7 comodines mezclando Jokers y Doses | **2.000**[^14] |
| Comodines limpia | 7 Jokers o 7 Doses puros | **3.000**[^14] |
| Ases limpia | 7 Ases naturales | **800**[^14] |
| Ases sucia | 7 Ases con comodines | **500**[^14] |

**Canastrón:** posesión concurrente de cinco canastas independientes terminadas; representa multiplicadores adicionales según regulación local.[^2]

**Treses Rojos (resolución postergada):**

- Cada tres rojo expuesto vale **+100** provisionales.
- Exponer los **cuatro** treses rojos otorga **800** puntos totales.[^2]
- Si el equipo termina la mano **sin ninguna canasta**, los treses rojos se **invierten en negativos**.[^2]

**Penalizaciones:**

- Robar fuera de orden: **−100**.
- Retener los cuatro Treses Negros al cierre: **−500** (mitiga tácticas destructivas).[^12]

---

## 3. Ingeniería de la Lógica Central mediante Máquinas de Estados Finitos (FSM)

Implementar un juego de este calibre con cadenas de `if/else` conduce inexorablemente a bases de código inmanejables y condiciones de carrera. El patrón **FSM (Finite State Machine)** es la metodología recomendada para organizar la concurrencia y la lógica de negocio de manera atómica, comprobable y expansible.[^3]

### 3.1 Arquitectura de la Máquina de Estados del Flujo de Partida (Game Loop FSM)

Cada estado expone los métodos `_enter_state`, `_process_state`, `_exit_state`. La jerarquía es administrada por el servidor (o anfitrión).[^17]

1. **`State_InitMatch`** — Bloquea la UI de los clientes, mezcla el mazo de 108 cartas, despacha RPCs para repartir manos según conteo, y establece los multiplicadores de apertura (50/90/120) basados en métricas guardadas.[^1]
2. **`State_SetupPozo`** — Expone las cinco cartas reglamentarias en pozo y "espejo".[^10]
3. **`State_DrawPhase`** — Única entrada admisible: solicitud de captura del pozo *o* confirmación del robo estándar.[^20] Si `pozo_taponado == true`, la zona de captura queda inhabilitada y se fuerza el robo doble.[^1]
4. **`State_PlayPhase`** — Fase prolongada que permite arrastres y bajadas válidas a la matriz pública compartida.[^20] Verificación en tiempo real contra la barrera de apertura y actualización del estatus de pureza.
5. **`State_DiscardPhase`** — Requiere detectar señal de *Dropzone* sobre el pozo;[^21] único disparador permitido para ceder el turno al siguiente jugador en el anillo lógico.[^20]

Este uso disciplinado de estados confinados previene exploits como descartar antes del robo obligatorio o manipular combinaciones fuera de la ventana táctica.[^3]

### 3.2 Máquina de Estados Micro-Transaccional de las Cartas Visuales (CardUI FSM)

Cada nodo `CardUI` implementa su FSM individual para gestionar gestos táctiles y prevenir comportamientos espasmódicos:[^22]

- **`Idle_State`** — Carta anidada en el contenedor de la mano, sometida a la disposición radial.[^22]
- **`Hovered_State`** — Disparado por `mouse_entered` o primer contacto táctil. Aplica multiplicador de escala y altera `z_index` para previsualización.[^22]
- **`Dragging_State`** — Disparado por `InputEventScreenDrag`. Disuelve el enlace jerárquico con la mano y enlaza la posición a `get_global_mouse_position()` con interpolación.[^24]
- **`Released_State`** — Al terminar el contacto. Emite `PhysicsPointQueryParameters2D` con `intersect_point` para detectar la zona subyacente.[^24] Si no hay zona válida, un `Tween` con *easing* devuelve la carta a su posición original.[^26]

---

## 4. Desarrollo Arquitectónico de la Interfaz y UX para Entornos Móviles

La regla del robo dual genera escenarios donde el jugador debe gestionar **20+ cartas simultáneamente** en pantallas reducidas. La UI debe diseñarse para soportar este volumen.

### 4.1 Paradigmas de Interacción Táctil y la API Dinámica de Arrastre (Drag and Drop)

Godot 4.x provee tres funciones virtuales clave en `Control` que deben ser sobrescritas:[^27]

#### `_get_drag_data(at_position: Vector2) -> Variant`
Emite un paquete con los punteros de identidad de la carta. Internamente invoca `set_drag_preview()` para crear un clon translúcido enraizado al pulso del usuario.[^21]

#### `_can_drop_data(at_position: Vector2, data: Variant) -> bool`
Las dropzones (zona de juego, pozo) verifican si `data` corresponde al diccionario estructural esperado. Retornar `true` propicia retroalimentación visual (ej. resaltado).[^21]

#### `_drop_data(at_position: Vector2, data: Variant) -> void`
Ejecuta `remove_child` del contenedor previo y `add_child` al nuevo padre, transmitiendo señales a los oyentes correspondientes.[^21]

**Configuración del proyecto para móvil:**

- Activar `emulate_touch_from_mouse` para depurar.[^4]
- Rastrear explícitamente `InputEventScreenTouch` (en lugar de eventos agnósticos) para evitar falsos negativos.[^4]
- Desactivar `Input.use_accumulated_input` para reducir latencia.[^30]
- Configurar VSync en `VSYNC_MAILBOX` para minimizar latencia táctil.[^30]

### 4.2 Matemáticas Paramétricas para la Disposición Radial de la Mano (Card Fanning)

Un `HBoxContainer` lineal causa aplastamiento y solapamiento ilegible. La técnica canónica es el **fanning** (abanico progresivo).[^5]

Las posiciones se recalculan tras cada inserción/remoción, usando `Curve` para interpolación.[^33] Tres fases:

#### 1) Normalización cartesiana de los índices

```gdscript
var normalized_x = float(i) / max(1, num_cards - 1)
# Acotado en [0.0, 1.0]: 0 = margen izquierdo, 1 = margen derecho
```

#### 2) Modelado paramétrico de los ejes X / Y

```gdscript
# Y descendente arqueado (concavidad gravitatoria)
var y_offset = max_height * (4 * pow(normalized_x - 0.5, 2) - 1)
# X escalonado con diferencial dinámico programable
var x_offset = spacing * i
```

Las cartas en los extremos quedan a cotas inferiores; las del centro al cénit.[^35]

#### 3) Proyección de rotación esférica

```gdscript
card.rotation_degrees = lerp(-max_tilt, max_tilt, normalized_x)
```

La interpolación combinada se vincula a `Tween`s en cascada para evitar transiciones violentas perjudiciales para la inmersión, especialmente cuando el robo dual amplía la mano.[^26]

---

## 5. Arquitectura de Sincronización en Red y Modelo Servidor-Autoritativo

El multijugador competitivo exige neutralizar vectores de fraude (anti-cheat / network integrity).[^7]

Compartir el árbol de escena completo en topología **P2P** es una decisión de ingeniería precaria para juegos de **información imperfecta**.[^7] Ocultar las cartas del rival únicamente con materiales opacos en el cliente es trivial de bypassear con introspección de memoria o sniffers.[^7]

### 5.1 El Prisma Autoritativo y el Aislamiento Restrictivo del Estado Global

El paradigma central es el **Servidor Dedicado Autoritativo**: una entidad centralizada aloja la única versión verídica del estado.[^7]

#### 1) Cámara de almacenamiento de variables (solo en servidor)
Únicamente en la memoria del host se conservan:[^40]

- `Deck_Array` — el mazo real.
- `Discard_Pile_Array` — pila de descartes.
- Las manos confidenciales de cada participante.

#### 2) Mecanismos de visibilidad de red

Godot 4.x incluye `MultiplayerSynchronizer` con **filtros de visibilidad selectiva**.[^6] Mediante filtros booleanos por peer, se determina qué nodos se sincronizan a qué clientes:[^41]

```gdscript
# Player1_Hand sólo se sincroniza al peer del Jugador 1
$Player1_Hand/MultiplayerSynchronizer.set_visibility_for(player1_peer_id, true)
$Player1_Hand/MultiplayerSynchronizer.set_visibility_for(player2_peer_id, false)
```

#### 3) Hologramas / representaciones limitadas del oponente

El servidor emite únicamente una variable entera ligera (ej. `opponent_card_count`) para que el cliente instancie maquetas pasivas (`RemoteHand`) — cartas dorso sin propiedades semánticas. El rival nunca recibe los datos reales de la mano ajena.[^40]

### 5.2 Validación Procedural y Secuencias de Comando Remoto (RPC)

El cliente **nunca** muta el estado global directamente. Todas las acciones son solicitudes al servidor mediante **RPCs**.[^7] Modelo en cuatro capas:

#### 1) Solicitud del cliente
```gdscript
rpc_id(1, "request_take_discard_pile")
```
El servidor (peer 1) recibe la petición.[^39]

#### 2) Validación y arbitraje (server reconciliation)
El servidor congela la iteración y comprueba:[^1][^2]

- Banderas del turno.
- Estado del pozo (taponado/cruzado).
- Existencia de exactamente dos cartas naturales coincidentes en la mano del solicitante.
- Suma total contra la barrera de apertura (50/90/120) si aún no abrió.

#### 3) Ejecución o rechazo
- **Rechazo:** RPC desautorizante; el cliente revierte las cartas a su posición original con `Tween`.
- **Aceptación:** mutación de los arreglos autoritativos (`DiscardPile.clear()`, anexión a `Player1_Hand`).

#### 4) Difusión y recalibración
Pasados ms, los `MultiplayerSynchronizer` re-difunden:
- Al Jugador 1: la información completa del nuevo conjunto adquirido.
- Al Jugador 2: instrucción para vaciar la representación del pozo y aumentar `opponent_card_count` con cartas hologramáticas (dorsos).[^39]

> **Resultado de seguridad:** este blindaje impide que clientes alterados (hacks) reclamen falsamente combinaciones inexistentes (canastas de comodines limpias, premios) para forzar puntuaciones fraudulentas o cierres prematuros.[^14]

---

## 6. Conclusiones Integrales y Síntesis Arquitectónica y Metodológica

La viabilidad de implementar la Canasta Uruguaya en Godot 4.x para móvil descansa sobre tres pilares interdependientes:

1. **Modelo de reglas formalizado:** la regla del robo doble obligatorio acelera el crecimiento de la mano, lo que hace **imprescindible** el sistema de fanning paramétrico para soportar 20+ cartas sin colapso ergonómico.[^35]

2. **Disciplina de FSM:** las dependencias secuenciales (apertura escalada 50/90/120, treses negros como bloqueadores, penalizaciones por orden) requieren máquinas de estados aisladas. Mezclar la lógica de reglas con la de UI mediante condicionales planos resulta en código inmanejable y bugs concurrentes a escala.[^3]

3. **Servidor autoritativo + visibility filters:** dado que es un juego de información imperfecta competitivo, **únicamente** el modelo autoritativo combinado con `MultiplayerSynchronizer` y RPCs validados elimina las superficies de ataque (introspección de memoria, paquetes interceptados, clientes modificados).[^7][^6]

Adoptar estos tres pilares de extremo a extremo —desde el `Resource` de la carta hasta el peer del oponente— produce una base robusta, extensible y segura, lista para desarrollo de cara a producción sobre Godot 4.x.

---

## Obras citadas

[^1]: [LAS REGLAS DEL JUEGO DE CANASTA — CLUB TENIS VALENCIA](https://www.clubdetenisvalencia.es/files.ashx?id=4225ca8c1f7c2776fdd07752e02f2705)
[^2]: [Canasta (juego) — Wikipedia](https://es.wikipedia.org/wiki/Canasta_(juego))
[^3]: [Godot State Machine Complete Tutorial — Generalist Programmer](https://generalistprogrammer.com/tutorials/godot-state-machine-complete-tutorial-game-ai)
[^4]: [Godot 4.5 Touch & Drag Tutorial — YouTube](https://www.youtube.com/watch?v=YGqq58-CN-A)
[^5]: [How can I make a hand of cards look good? — Reddit r/godot](https://www.reddit.com/r/godot/comments/17y7sof/how_can_i_make_a_hand_of_cards_look_good/)
[^6]: [Multiplayer in Godot 4.0: Scene Replication](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/)
[^7]: [The right way to make a multiplayer game with a dedicated server — Godot Forum](https://forum.godotengine.org/t/the-right-way-to-make-a-multiplayer-game-with-a-dedicated-server-in-godot/126207)
[^8]: [CANASTA — Mesas de Billar JRD (PDF)](http://www.mesasdebillarjrd.com/wp-content/uploads/2010/10/CANASTA.pdf)
[^9]: [Reglas del Juego de Canasta Uruguaya — Scribd](https://es.scribd.com/document/312906747/Reglamento-Canasta)
[^10]: [Reglamento de Canasta — FEFARA (PDF)](https://www.fefara.org.ar/wp-content/uploads/2023/08/REGLAMENTO-DE-CANASTA.pdf)
[^11]: [Canasta — Nido de juegos](https://nidodejuegos.wordpress.com/2015/11/12/canasta/)
[^12]: [Cómo jugar a la canasta — Fournier](https://www.nhfournier.es/como-jugar/canasta/)
[^13]: [Playing Canasta: The Special Rules Regarding 3s — Dummies](https://www.dummies.com/article/home-auto-hobbies/games/card-games/general-card-games/playing-canasta-the-special-rules-regarding-3s-193772/)
[^14]: [Reglas del juego de Canasta — Scribd](https://es.scribd.com/document/277255765/Teoria-Del-Juego-de-La-Canasta-completo)
[^17]: [Make a Finite State Machine in Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
[^20]: [Advice for ways to track game state for a card game — Godot Forum](https://forum.godotengine.org/t/advice-for-ways-to-track-game-state-for-a-card-game/95267)
[^21]: [Drag and Drop in Godot 4.x — DEV Community](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13)
[^22]: [Can anyone help me understand state machine for a card game? — Reddit](https://www.reddit.com/r/godot/comments/1jbwrcl/can_anyone_help_me_understand_state_machine_for_a/)
[^24]: [Godot 4 CARD GAME Tutorial #1 Dragging Cards — YouTube](https://www.youtube.com/watch?v=2jMcuKdRh2w)
[^26]: [Godot 4 Drag-and-Drop Tutorial — YouTube](https://www.youtube.com/watch?v=uhgswVkYp0o)
[^27]: [Drag and Drop Send Data Between UI Controls — YouTube](https://www.youtube.com/watch?v=ezMJN1fo7T0)
[^30]: [Drag and drop: balancing responsiveness with smooth animation — Reddit](https://www.reddit.com/r/godot/comments/1qwaba4/drag_and_drop_balancing_responsiveness_with/)
[^33]: [How I Fan 3D Cards in Godot 4 — YouTube](https://www.youtube.com/watch?v=S60pMTsePqI)
[^35]: [How to fan cards help pls — Godot Forum](https://forum.godotengine.org/t/how-to-fan-cards-help-pls/91758)
[^39]: [Client Server architecture for a multiplayer card game — Reddit](https://www.reddit.com/r/godot/comments/9yrhxi/client_server_architecture_for_a_multiplayer_card/)
[^40]: [How To Think About Multiplayer State — Godot Forum](https://forum.godotengine.org/t/how-to-think-about-multiplayer-state/118834)
[^41]: [Godot network visibility is critical to building out your multiplayer worlds — Reddit](https://www.reddit.com/r/godot/comments/180k0b6/godot_network_visibility_is_critical_to_building/)

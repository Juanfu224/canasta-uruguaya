## Descubrimiento LAN por broadcast UDP.
##
## Modos:
##   - HOST (`start_advertising`): emite cada `ADVERTISE_INTERVAL` segundos
##     un paquete con metadatos de la sala. Para detenerlo: `stop`.
##   - CLIENT (`start_scanning`): escucha en el puerto de discovery durante
##     `SCAN_DURATION` segundos y agrega cada anuncio único al diccionario
##     `discovered_rooms`. Emite `room_discovered` por cada nuevo paquete.
##
## Formato del paquete (JSON UTF-8, máx ~512 bytes para evitar fragmentación):
##     {
##       "v": 1,                # schema version
##       "magic": "CANASTA_UY", # filtro contra otras apps en la red
##       "code": "ABC123",      # código de sala
##       "host": "Juan",        # nickname del host
##       "port": 8910,          # puerto del juego
##       "n": 1,                # jugadores actuales
##       "max": 4,              # cupo máximo
##       "started": false       # ya en partida
##     }
##
## Seguridad / robustez:
##   - El parser rechaza paquetes mayores a `MAX_PACKET_BYTES` (defensa vs
##     amplification attacks).
##   - Verifica `magic` y `v` antes de procesar; descarta sin loggear (no
##     queremos fugar info sobre intentos malformados).
##   - Sanea `host` (max 32 chars, sin caracteres de control) antes de
##     mostrar en UI (defensa vs spoof con caracteres ANSI / RTL).
class_name LanDiscovery
extends Node

const _MAGIC: String = "CANASTA_UY"
const _SCHEMA_V: int = 1
const _BROADCAST_ADDR: String = "255.255.255.255"
const _MAX_PACKET_BYTES: int = 512
const _MAX_NICK_LEN: int = 32

## Período entre anuncios del host.
const ADVERTISE_INTERVAL_S: float = 1.0

## Duración por defecto de un escaneo. El cliente puede llamar a `stop` antes.
const SCAN_DURATION_S: float = 5.0

## Tiempo tras el cual una sala "vista" se considera caída si no se reanuncia.
const ROOM_TIMEOUT_S: float = 3.5

signal room_discovered(info: Dictionary)
signal room_lost(code: String)
signal scan_finished()

var _udp: PacketPeerUDP = null
var _is_advertising: bool = false
var _is_scanning: bool = false
var _advertise_payload: PackedByteArray = PackedByteArray()
var _advertise_timer: Timer = null
var _scan_timer: Timer = null
var _expiry_timer: Timer = null

## code → {info: Dictionary, last_seen_msec: int}
var discovered_rooms: Dictionary = {}


func _ready() -> void:
	set_process(false)


# ---------------------------------------------------------------------------
# Host: anuncio
# ---------------------------------------------------------------------------

## Comienza a anunciar la sala. Si ya estaba anunciando, actualiza el payload.
func start_advertising(info: Dictionary) -> int:
	stop()
	_advertise_payload = _build_packet(info)
	if _advertise_payload.size() > _MAX_PACKET_BYTES:
		push_error("LanDiscovery: payload supera %d bytes" % _MAX_PACKET_BYTES)
		return ERR_INVALID_DATA
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	# Bind a puerto efímero para emitir; no necesitamos escuchar en host.
	var err: int = _udp.bind(0)
	if err != OK:
		push_error("LanDiscovery.start_advertising: bind falló (%d)" % err)
		return err
	_udp.set_dest_address(_BROADCAST_ADDR, GameConfig.NET_PORT_DISCOVERY)
	_is_advertising = true
	_advertise_timer = _make_timer(ADVERTISE_INTERVAL_S, _send_advertise, false)
	# Emitir uno inmediato para que el cliente vea la sala enseguida.
	_send_advertise()
	return OK


## Actualiza el payload sin reabrir el socket.
func update_advertise_info(info: Dictionary) -> void:
	if not _is_advertising:
		return
	_advertise_payload = _build_packet(info)


func _send_advertise() -> void:
	if not _is_advertising or _udp == null:
		return
	var err := _udp.put_packet(_advertise_payload)
	if err != OK and err != ERR_BUSY:
		# ERR_BUSY es transitorio en redes saturadas; el resto loggear.
		push_warning("LanDiscovery: put_packet fallo (%d)" % err)


# ---------------------------------------------------------------------------
# Cliente: escaneo
# ---------------------------------------------------------------------------

func start_scanning(duration_s: float = SCAN_DURATION_S) -> int:
	stop()
	_udp = PacketPeerUDP.new()
	var err: int = _udp.bind(GameConfig.NET_PORT_DISCOVERY, "0.0.0.0")
	if err != OK:
		push_error("LanDiscovery.start_scanning: bind %d falló (%d)" %
			[GameConfig.NET_PORT_DISCOVERY, err])
		return err
	_is_scanning = true
	discovered_rooms.clear()
	set_process(true)
	_scan_timer = _make_timer(duration_s, _on_scan_timeout, true)
	_expiry_timer = _make_timer(1.0, _check_expired_rooms, false)
	return OK


func _process(_delta: float) -> void:
	if not _is_scanning or _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _udp.get_packet()
		if bytes.size() == 0 or bytes.size() > _MAX_PACKET_BYTES:
			continue
		var sender_ip: String = _udp.get_packet_ip()
		_handle_incoming(bytes, sender_ip)


func _handle_incoming(bytes: PackedByteArray, sender_ip: String) -> void:
	var raw: String = bytes.get_string_from_utf8()
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if data.get("magic", "") != _MAGIC:
		return
	if int(data.get("v", 0)) != _SCHEMA_V:
		return
	var code: String = String(data.get("code", ""))
	if not RoomCode.is_valid(code):
		return
	var info: Dictionary = {
		"code": code,
		"host_nickname": _sanitize_nickname(String(data.get("host", "?"))),
		"host_ip": sender_ip,
		"port": clampi(int(data.get("port", GameConfig.NET_PORT_GAME)), 1024, 65535),
		"n_players": clampi(int(data.get("n", 0)), 0, 16),
		"max_players": clampi(int(data.get("max", 4)), 1, 16),
		"started": bool(data.get("started", false)),
	}
	var now_msec: int = Time.get_ticks_msec()
	var was_known: bool = discovered_rooms.has(code)
	discovered_rooms[code] = {"info": info, "last_seen_msec": now_msec}
	if not was_known:
		room_discovered.emit(info)


func _check_expired_rooms() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var to_remove: Array[String] = []
	for code in discovered_rooms.keys():
		var entry: Dictionary = discovered_rooms[code]
		if now_msec - int(entry.last_seen_msec) > int(ROOM_TIMEOUT_S * 1000.0):
			to_remove.append(code)
	for code in to_remove:
		discovered_rooms.erase(code)
		room_lost.emit(code)


func _on_scan_timeout() -> void:
	# No cerramos el socket: dejamos el escaneo "pasivo" hasta que el caller
	# llame a `stop`. Solo emitimos `scan_finished` para que la UI cambie.
	scan_finished.emit()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func stop() -> void:
	_is_advertising = false
	_is_scanning = false
	set_process(false)
	if _udp != null:
		_udp.close()
		_udp = null
	if _advertise_timer != null:
		_advertise_timer.queue_free()
		_advertise_timer = null
	if _scan_timer != null:
		_scan_timer.queue_free()
		_scan_timer = null
	if _expiry_timer != null:
		_expiry_timer.queue_free()
		_expiry_timer = null
	discovered_rooms.clear()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _build_packet(info: Dictionary) -> PackedByteArray:
	var payload: Dictionary = {
		"v": _SCHEMA_V,
		"magic": _MAGIC,
		"code": String(info.get("code", "")),
		"host": _sanitize_nickname(String(info.get("host_nickname", "?"))),
		"port": int(info.get("port", GameConfig.NET_PORT_GAME)),
		"n": int(info.get("n_players", 1)),
		"max": int(info.get("max_players", 4)),
		"started": bool(info.get("started", false)),
	}
	return JSON.stringify(payload).to_utf8_buffer()


static func _sanitize_nickname(s: String) -> String:
	var trimmed: String = s.strip_edges()
	if trimmed.length() > _MAX_NICK_LEN:
		trimmed = trimmed.substr(0, _MAX_NICK_LEN)
	# Eliminar caracteres de control y de dirección bidi (anti-spoof RTL).
	var safe := ""
	for ch in trimmed:
		var cp: int = ch.unicode_at(0)
		if cp < 0x20 or cp == 0x7F:
			continue
		# Ignorar marcadores bidi peligrosos: U+202A..U+202E, U+2066..U+2069
		if (cp >= 0x202A and cp <= 0x202E) or (cp >= 0x2066 and cp <= 0x2069):
			continue
		safe += ch
	return safe if not safe.is_empty() else "?"


func _make_timer(secs: float, cb: Callable, one_shot: bool) -> Timer:
	var t := Timer.new()
	t.wait_time = secs
	t.one_shot = one_shot
	t.autostart = false
	add_child(t)
	t.timeout.connect(cb)
	t.start()
	return t

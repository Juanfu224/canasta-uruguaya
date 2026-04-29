## Persistencia atómica de snapshots para reconexión.
##
## Estrategia:
##   - El host serializa `MatchSnapshot` (incluyendo manos privadas) tras
##     cada acción autoritativa exitosa. Throttled a `MIN_SAVE_INTERVAL_MS`.
##   - Save atómico: escribir a `<path>.tmp` + rename. Evita snapshots
##     corruptos si el proceso muere a media escritura.
##   - Si un peer reconecta con un `match_id` conocido, el host carga el
##     snapshot del disco y lo retransmite vía `client_load_snapshot`.
##
## Path: `user://saves/<match_id>.snap` (binario, ResourceSaver).
class_name Reconnection
extends RefCounted

const SAVE_DIR: String = "user://saves"
const MIN_SAVE_INTERVAL_MS: int = 250
const MAX_SAVE_BYTES: int = 256 * 1024  # 256 KB cap defensivo (snap debería ser <10KB)

var _last_save_msec: int = 0


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("Reconnection: no se pudo crear %s (%d)" % [SAVE_DIR, err])


static func _path_for(match_id: String) -> String:
	# Saneo: match_id debería ser alfanumérico (UUID o RoomCode); reforzamos
	# para evitar path traversal si llega algo raro.
	var safe: String = ""
	for ch in match_id:
		var cp: int = ch.unicode_at(0)
		var is_alnum: bool = (cp >= 0x30 and cp <= 0x39) \
			or (cp >= 0x41 and cp <= 0x5A) \
			or (cp >= 0x61 and cp <= 0x7A) \
			or cp == 0x2D or cp == 0x5F  # - _
		if is_alnum:
			safe += ch
	if safe.is_empty():
		safe = "default"
	return "%s/%s.snap" % [SAVE_DIR, safe]


## Guarda atómicamente. Devuelve true si guardó, false si fue throttled.
func save_throttled(snapshot: MatchSnapshot) -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_save_msec < MIN_SAVE_INTERVAL_MS:
		return false
	_last_save_msec = now_msec
	save_now(snapshot)
	return true


static func save_now(snapshot: MatchSnapshot) -> int:
	_ensure_dir()
	var final_path: String = _path_for(snapshot.match_id)
	var tmp_path: String = final_path + ".tmp"
	var err: int = ResourceSaver.save(snapshot, tmp_path)
	if err != OK:
		push_error("Reconnection.save_now: ResourceSaver fallo (%d)" % err)
		return err
	# Rename atómico (DirAccess.rename_absolute si tmp en mismo dir).
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_CANT_OPEN
	if dir.file_exists(final_path):
		dir.remove(final_path)
	err = dir.rename(tmp_path, final_path)
	if err != OK:
		push_error("Reconnection.save_now: rename fallo (%d)" % err)
	return err


## Carga el snapshot persistido. Devuelve null si no existe o es inválido.
static func load(match_id: String) -> MatchSnapshot:
	var path: String = _path_for(match_id)
	if not FileAccess.file_exists(path):
		return null
	var size: int = FileAccess.get_file_as_bytes(path).size()
	if size > MAX_SAVE_BYTES:
		push_error("Reconnection.load: snapshot supera %d bytes (%d)" % [MAX_SAVE_BYTES, size])
		return null
	var res: Resource = ResourceLoader.load(path)
	if res == null or not (res is MatchSnapshot):
		push_error("Reconnection.load: snapshot inválido en %s" % path)
		return null
	return res as MatchSnapshot


## Serializa el snapshot a bytes para envío RPC sin tocar disco.
static func to_bytes(snapshot: MatchSnapshot) -> PackedByteArray:
	# Usamos var_to_bytes_with_objects para preservar Resources internos
	# (TeamState, Meld). El receptor invoca `bytes_to_var_with_objects`.
	# NOTE: with_objects sólo se permite entre peers de confianza (host→client
	# en nuestra arquitectura); el host es la única autoridad que serializa.
	return var_to_bytes_with_objects(snapshot)


static func from_bytes(bytes: PackedByteArray) -> MatchSnapshot:
	if bytes.is_empty() or bytes.size() > MAX_SAVE_BYTES:
		return null
	var v: Variant = bytes_to_var_with_objects(bytes)
	if not (v is MatchSnapshot):
		return null
	return v as MatchSnapshot


static func delete_for(match_id: String) -> void:
	var path: String = _path_for(match_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

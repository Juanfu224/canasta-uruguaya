## Persistencia de perfil anónimo del usuario.
##
## Almacena en `user://profile.cfg`:
##   - `uuid`: identificador anónimo v4 generado localmente.
##   - `nickname`: alias mostrado a los oponentes (sanitizado).
##   - `created_at`: timestamp ISO-8601 UTC.
##   - `settings`: dict con preferencias de UI (sonido, vibración, etc.).
##
## Decisiones de seguridad:
##   - El UUID se genera con `Crypto.generate_random_bytes(16)` y se formatea
##     con bits de versión/variant correctos (RFC 4122 v4). Sin información
##     identificable.
##   - El nickname se sanitiza (longitud y caracteres permitidos) para
##     prevenir inyección en UI/log y abuso por nombres impersonificadores.
##   - El archivo NO se cifra: no contiene secretos. Si en el futuro se
##     agregan tokens de sesión, deben ir a `user://secrets.cfg` cifrados.
extends Node

const PROFILE_PATH: StringName = &"user://profile.cfg"
const SECTION_PROFILE: StringName = &"profile"
const SECTION_SETTINGS: StringName = &"settings"

const NICKNAME_MAX_LEN: int = 20
const NICKNAME_MIN_LEN: int = 2
const NICKNAME_DEFAULT: String = "Jugador"
const NICKNAME_ALLOWED_REGEX: String = "^[A-Za-z0-9 _\\-]{2,20}$"

signal profile_loaded
signal profile_updated

var uuid: String = ""
var nickname: String = NICKNAME_DEFAULT
var created_at: String = ""
var settings: Dictionary = {
	"sfx_volume": 1.0,
	"music_volume": 0.7,
	"vibration": true,
	"reduce_motion": false,
}

var _nickname_re: RegEx = RegEx.new()
var _uuid_re: RegEx = RegEx.new()


func _ready() -> void:
	var compile_err: int = _nickname_re.compile(NICKNAME_ALLOWED_REGEX)
	if compile_err != OK:
		push_error("ProfileStore: no se pudo compilar la regex de nickname")
	# UUID v4: xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx (RFC 4122)
	_uuid_re.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	load_profile()


## Carga el perfil desde disco. Si no existe, crea uno nuevo.
func load_profile() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROFILE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		_create_new_profile()
		return OK
	if err != OK:
		push_error("ProfileStore: error cargando perfil (%d). Recreando." % err)
		_create_new_profile()
		return err

	uuid = cfg.get_value(SECTION_PROFILE, "uuid", "")
	nickname = cfg.get_value(SECTION_PROFILE, "nickname", NICKNAME_DEFAULT)
	created_at = cfg.get_value(SECTION_PROFILE, "created_at", "")
	# Merge settings preservando defaults para nuevas claves añadidas en updates.
	var stored: Dictionary = cfg.get_value(SECTION_SETTINGS, "values", {})
	for key in stored:
		if settings.has(key):
			settings[key] = stored[key]

	# Repair: si el UUID está vacío o es inválido, regenerar conservando settings.
	if uuid.is_empty() or not _is_valid_uuid(uuid):
		uuid = _generate_uuid_v4()
		save_profile()

	profile_loaded.emit()
	return OK


## Persiste el perfil en disco. Atómico: escribe a tmp y renombra.
func save_profile() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION_PROFILE, "uuid", uuid)
	cfg.set_value(SECTION_PROFILE, "nickname", nickname)
	cfg.set_value(SECTION_PROFILE, "created_at", created_at)
	cfg.set_value(SECTION_SETTINGS, "values", settings)

	var tmp_path: String = String(PROFILE_PATH) + ".tmp"
	var err: int = cfg.save(tmp_path)
	if err != OK:
		push_error("ProfileStore: error guardando perfil tmp (%d)" % err)
		return err

	# Rename atómico: en POSIX/Android/iOS `rename()` reemplaza el destino de
	# forma atómica sin ventana de pérdida de datos. NO borrar el archivo
	# existente antes del rename: introduciría una ventana donde el perfil
	# está ausente si el proceso muere entre remove y rename.
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("ProfileStore: no se pudo abrir user:// para rename")
		return ERR_FILE_CANT_OPEN
	var rename_err: int = dir.rename(tmp_path, String(PROFILE_PATH))
	if rename_err != OK:
		push_error("ProfileStore: rename atómico falló (%d)" % rename_err)
		return rename_err

	profile_updated.emit()
	return OK


## Cambia el nickname tras sanitizar. Devuelve true si fue aceptado.
func set_nickname(new_value: String) -> bool:
	var sanitized: String = _sanitize_nickname(new_value)
	if sanitized.is_empty():
		return false
	nickname = sanitized
	save_profile()
	return true


func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		push_warning("ProfileStore: setting desconocido '%s'" % key)
		return
	settings[key] = value
	save_profile()


# ---------------------------------------------------------------------------
# Privados
# ---------------------------------------------------------------------------

func _create_new_profile() -> void:
	uuid = _generate_uuid_v4()
	nickname = NICKNAME_DEFAULT
	created_at = Time.get_datetime_string_from_system(true)
	save_profile()
	profile_loaded.emit()


## RFC 4122 v4 UUID derivado de 16 bytes aleatorios criptográficos.
func _generate_uuid_v4() -> String:
	var crypto: Crypto = Crypto.new()
	var b: PackedByteArray = crypto.generate_random_bytes(16)
	# Set version (4) y variant (10xx) según RFC 4122.
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3],
		b[4], b[5],
		b[6], b[7],
		b[8], b[9],
		b[10], b[11], b[12], b[13], b[14], b[15],
	]


func _is_valid_uuid(s: String) -> bool:
	if s.length() != 36:
		return false
	# Usa _uuid_re compilada una vez en _ready() — sin alloc por llamada.
	return _uuid_re.search(s) != null


func _sanitize_nickname(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.length() < NICKNAME_MIN_LEN or trimmed.length() > NICKNAME_MAX_LEN:
		return ""
	if _nickname_re.search(trimmed) == null:
		return ""
	return trimmed

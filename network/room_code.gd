## Códigos de sala para LAN: alfabeto base32 sin caracteres ambiguos.
##
## El código identifica una sala visible en la red local. Es un identificador
## público — cualquiera con acceso al broadcast UDP lo recibe. Su único
## propósito es ser corto y comunicable verbalmente para que un jugador
## pueda teclearlo si el escaneo automático no encuentra la sala (firewall,
## subred distinta, etc.).
##
## Formato: 6 caracteres del alfabeto Crockford base32 (sin I/L/O/U) en
## mayúsculas. Espacio total: 32^6 ≈ 1.07 mil millones — colisión local
## prácticamente imposible.
##
## Para salas privadas con password, ver F10 (servidor neutral). En F5 LAN
## la "seguridad" la da el aislamiento de la red local.
class_name RoomCode
extends RefCounted

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH: int = 6


## Genera un código aleatorio de 6 caracteres usando bytes criptográficos
## (evita patrones predecibles que ayudarían a un atacante a enumerar
## salas en una red grande).
static func generate() -> String:
	var crypto: Crypto = Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(LENGTH)
	var out := ""
	for i in LENGTH:
		out += ALPHABET[bytes[i] & 0x1F]
	return out


## Valida formato. Devuelve true si `s` tiene exactamente LENGTH chars del
## alfabeto. Util para sanitizar input del usuario en el lobby.
static func is_valid(s: String) -> bool:
	if s.length() != LENGTH:
		return false
	for ch in s:
		if ALPHABET.find(ch) == -1:
			return false
	return true


## Normaliza input: trim + uppercase. NO valida; combinar con `is_valid`.
static func normalize(s: String) -> String:
	return s.strip_edges().to_upper()

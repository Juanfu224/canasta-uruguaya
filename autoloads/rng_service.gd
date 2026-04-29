## Servicio centralizado de aleatoriedad determinista.
##
## Uso:
##   - `RngService.match_rng` se inicializa con `start_match(seed)` y se utiliza
##     para todas las decisiones de partida (mezcla del mazo, bots, etc.).
##   - `RngService.ui_rng` es independiente y se usa para FX visuales no
##     reproducibles (vibración de hover, partículas) sin contaminar la lógica.
##
## En multiplayer la seed la fija el host autoritativo (F5) y se transmite a
## los clientes. Esto garantiza que ningún peer pueda manipular el RNG global,
## ya que solo el host muta `match_rng`.
extends Node

## RNG determinista para lógica de partida. Sembrado por `start_match`.
var match_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## RNG independiente para efectos visuales. No requiere ser reproducible.
var ui_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Última seed usada en `start_match`. Útil para diagnostico/replay.
var current_match_seed: int = 0


func _ready() -> void:
	# UI RNG siempre arranca con seed aleatoria; no afecta a la lógica.
	ui_rng.randomize()


## Inicializa el RNG de partida con una seed explícita (modo determinista).
## Si `seed_value` es 0, genera una seed segura usando `Crypto`.
func start_match(seed_value: int = 0) -> int:
	if seed_value == 0:
		seed_value = _generate_secure_seed()
	current_match_seed = seed_value
	# Asignar seed resetea internamente el estado del RNG de forma determinista.
	# NO tocar `match_rng.state` manualmente: sobreescribiría la secuencia
	# correcta que Godot deriva del seed, alterando el orden de mezcla.
	match_rng.seed = seed_value
	return seed_value


## Genera una seed criptográficamente robusta (8 bytes → int64).
## Evita usar `Time.get_unix_time_from_system()` solo, que puede colisionar
## entre dispositivos sincronizados por NTP.
func _generate_secure_seed() -> int:
	var crypto: Crypto = Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(8)
	var seed_value: int = 0
	for i in range(bytes.size()):
		seed_value = (seed_value << 8) | int(bytes[i])
	# Fuerza a int64 positivo para evitar interpretación negativa accidental.
	return seed_value & 0x7FFFFFFFFFFFFFFF

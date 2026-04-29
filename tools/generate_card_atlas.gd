@tool
## Generador de los 108 .tres canónicos de cartas.
##
## Ejecutar desde el editor (Project → Tools) o vía CLI:
##   `godot --headless --path . --script res://tools/generate_card_atlas.gd`
##
## Crea un archivo `.tres` por carta en `res://resources/cards/` con un
## naming determinista (`card_{id:03d}_{rank}{suit}.tres`). Esto sirve para:
##   1. Verificación visual rápida en el inspector (criterio F1).
##   2. Permitir que escenas referencien cartas por path estable.
##   3. Bootstrap de un futuro pipeline de atlas de texturas (F7).
##
## El paso de generación de atlas de texturas (PNG) queda fuera de F1: se
## activará cuando exista artwork base. Esta tool solo crea los recursos de
## datos.
extends EditorScript

const OUTPUT_DIR: String = "res://resources/cards"

const SUIT_NAMES := {
	GameConfig.Suit.CLUBS: "C",
	GameConfig.Suit.DIAMONDS: "D",
	GameConfig.Suit.HEARTS: "H",
	GameConfig.Suit.SPADES: "S",
	GameConfig.Suit.JOKER: "X",
}

const RANK_NAMES := {
	GameConfig.Rank.ACE: "A",
	GameConfig.Rank.TWO: "02",
	GameConfig.Rank.THREE: "03",
	GameConfig.Rank.FOUR: "04",
	GameConfig.Rank.FIVE: "05",
	GameConfig.Rank.SIX: "06",
	GameConfig.Rank.SEVEN: "07",
	GameConfig.Rank.EIGHT: "08",
	GameConfig.Rank.NINE: "09",
	GameConfig.Rank.TEN: "10",
	GameConfig.Rank.JACK: "J",
	GameConfig.Rank.QUEEN: "Q",
	GameConfig.Rank.KING: "K",
	GameConfig.Rank.JOKER: "JK",
}


func _run() -> void:
	_ensure_dir(OUTPUT_DIR)

	var deck: Deck = Deck.build_standard_108()
	var written: int = 0
	var errors: int = 0

	for card in deck.cards:
		var path: String = "%s/card_%03d_%s%s.tres" % [
			OUTPUT_DIR,
			card.id,
			RANK_NAMES.get(card.rank, "??"),
			SUIT_NAMES.get(card.suit, "?"),
		]
		var err: int = ResourceSaver.save(card, path, ResourceSaver.FLAG_COMPRESS)
		if err == OK:
			written += 1
		else:
			errors += 1
			push_error("generate_card_atlas: error guardando %s (%d)" % [path, err])

	print("[generate_card_atlas] %d/%d cartas escritas en %s (errores: %d)" % [
		written, deck.cards.size(), OUTPUT_DIR, errors,
	])


func _ensure_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		return
	var err: int = DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		push_error("generate_card_atlas: no se pudo crear %s (%d)" % [path, err])

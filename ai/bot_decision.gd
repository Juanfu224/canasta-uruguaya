## Decisión que toma un bot en una fase del turno.
##
## Estructura simple e inmutable; producida por `BotPlayer.decide()` y
## consumida por `BotController` para ejecutar la acción autoritativa.
##
## `kind` enumera el tipo de acción:
##   - "draw":     robar 2 cartas del mazo.
##   - "capture":  capturar el pozo. `card_ids` = cartas reclamadas (pueden
##                 estar vacías si el rango ya tiene meld del equipo).
##   - "meld":     bajar combinación nueva (o extender la del rango). `card_ids`
##                 + `declared_rank`.
##   - "close":    cerrar la mano. Pre: equipo cumple `can_close`.
##   - "pass_play":no meldear este turno; saltar a descarte.
##   - "discard":  descartar `target_card_id`.
class_name BotDecision
extends RefCounted

var kind: String = ""
var card_ids: PackedInt32Array = PackedInt32Array()
var declared_rank: int = -1
var target_card_id: int = -1


static func draw() -> BotDecision:
	var d := BotDecision.new()
	d.kind = "draw"
	return d


static func capture(claim_ids: PackedInt32Array) -> BotDecision:
	var d := BotDecision.new()
	d.kind = "capture"
	d.card_ids = claim_ids
	return d


static func meld(card_ids_arg: PackedInt32Array, rank: int) -> BotDecision:
	var d := BotDecision.new()
	d.kind = "meld"
	d.card_ids = card_ids_arg
	d.declared_rank = rank
	return d


static func close_match() -> BotDecision:
	var d := BotDecision.new()
	d.kind = "close"
	return d


static func pass_play() -> BotDecision:
	var d := BotDecision.new()
	d.kind = "pass_play"
	return d


static func discard(card_id: int) -> BotDecision:
	var d := BotDecision.new()
	d.kind = "discard"
	d.target_card_id = card_id
	return d


func _to_string() -> String:
	return "BotDecision(%s,cards=%s,rank=%d,target=%d)" % [
		kind, str(card_ids), declared_rank, target_card_id
	]

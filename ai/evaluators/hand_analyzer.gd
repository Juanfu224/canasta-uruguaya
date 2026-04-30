## Análisis estático de una mano: agrupa cartas por rango, separa comodines.
##
## Resultado tipado en `Analysis` para evitar diccionarios opacos. Las
## funciones son puras: NO mutan la mano de entrada.
class_name HandAnalyzer
extends RefCounted


## Grupo de cartas naturales del mismo rango.
class RankGroup:
	var rank: int = -1
	var cards: Array[Card] = []
	func count() -> int:
		return cards.size()


## Resultado del análisis.
class Analysis:
	## rank (int) → RankGroup. Sólo ranks no-comodín y no Tres.
	var groups: Dictionary = {}
	## Comodines (Jokers + 2s) en la mano.
	var wilds: Array[Card] = []
	## Joker count puro.
	var jokers: int = 0
	## Doses count.
	var twos: int = 0
	## Treses negros (no se usan en melds, pero útil saber cuántos hay).
	var black_threes: Array[Card] = []
	## Tamaño total de mano (excluye treses rojos que ya se removieron antes).
	var size: int = 0


static func analyze(hand: Array[Card]) -> Analysis:
	var a := Analysis.new()
	a.size = hand.size()
	for c in hand:
		if c.is_red_three:
			# Defensivo: no debería estar en mano (RulesEngine los extrae).
			continue
		if c.is_black_three:
			a.black_threes.append(c)
			continue
		if c.is_wildcard:
			a.wilds.append(c)
			if c.rank == GameConfig.Rank.JOKER:
				a.jokers += 1
			else:
				a.twos += 1
			continue
		var g: RankGroup = a.groups.get(c.rank, null)
		if g == null:
			g = RankGroup.new()
			g.rank = c.rank
			a.groups[c.rank] = g
		g.cards.append(c)
	return a


## Devuelve los rangos en mano ordenados de mayor cantidad a menor.
static func ranks_by_size_desc(a: Analysis) -> Array[int]:
	var pairs: Array = []
	for r in a.groups.keys():
		pairs.append([(a.groups[r] as RankGroup).count(), r as int])
	pairs.sort_custom(func(x, y):
		if x[0] == y[0]:
			return (x[1] as int) > (y[1] as int)
		return (x[0] as int) > (y[0] as int))
	var out: Array[int] = []
	for p in pairs:
		out.append(p[1] as int)
	return out

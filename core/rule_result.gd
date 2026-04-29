## Resultado de una validación / acción del motor de reglas.
##
## Patrón "Result type": evita excepciones y obliga al caller a inspeccionar
## el motivo del rechazo antes de mutar estado.
class_name RuleResult
extends RefCounted

var ok: bool
var reason: String


static func success() -> RuleResult:
	var r: RuleResult = RuleResult.new()
	r.ok = true
	r.reason = ""
	return r


static func failure(reason_code: String) -> RuleResult:
	var r: RuleResult = RuleResult.new()
	r.ok = false
	r.reason = reason_code
	return r

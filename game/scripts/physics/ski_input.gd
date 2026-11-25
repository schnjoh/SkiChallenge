class_name SkiInput
extends RefCounted
## One frame of rider input (device independent).

var steer: float = 0.0  ## -1 = left, +1 = right
var tuck: bool = false
var brake: bool = false  ## stand up / brake (skid)
var prejump: bool = false  ## edge-triggered by the controller


static func make(p_steer: float, p_tuck: bool, p_brake: bool = false, p_prejump: bool = false) -> SkiInput:
	var i: SkiInput = SkiInput.new()
	i.steer = clampf(p_steer, -1.0, 1.0)
	i.tuck = p_tuck
	i.brake = p_brake
	i.prejump = p_prejump
	return i

extends Label

var accum := 0.0
const INTERVAL := 0.25

func _process(delta: float) -> void:
	accum += delta
	if accum < INTERVAL:
		return
	accum = 0.0
	text = "FPS: %d" % Engine.get_frames_per_second()

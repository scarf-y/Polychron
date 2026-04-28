extends AudioStreamPlayer

## Level BGM — respects GlobalSettings music toggle and volume.

func _ready() -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and not gs.music_enabled:
		stop()
	elif gs:
		volume_db = gs.get_volume_db() - 12.0
		play()

func _process(_delta: float) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if not gs:
		return
	if not gs.music_enabled:
		if playing:
			stop()
	else:
		if not playing:
			play()
		volume_db = gs.get_volume_db() - 12.0

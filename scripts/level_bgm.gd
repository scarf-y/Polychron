extends AudioStreamPlayer

## Level BGM — respects GlobalSettings music toggle and volume.

func _ready() -> void:
	if not GlobalSettings.music_enabled:
		stop()
	else:
		volume_db = GlobalSettings.get_volume_db() - 12.0  # -12 base offset for gameplay BGM
		play()

func _process(_delta: float) -> void:
	if not GlobalSettings.music_enabled:
		if playing:
			stop()
	else:
		if not playing:
			play()
		volume_db = GlobalSettings.get_volume_db() - 12.0

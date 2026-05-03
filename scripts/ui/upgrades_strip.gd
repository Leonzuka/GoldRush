extends HBoxContainer
class_name UpgradesStrip

## Compact strip of chips showing currently-owned upgrades (icon + level).
## Hidden slots for upgrades at level 0. Refreshes on EventBus.upgrades_changed.

var _chips: Dictionary = {}        # upgrade_id → PanelContainer
var _level_labels: Dictionary = {} # upgrade_id → Label

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh()
	EventBus.upgrades_changed.connect(refresh)

func _build() -> void:
	for id in Config.UPGRADE_DEFINITIONS.keys():
		var def: Dictionary = Config.UPGRADE_DEFINITIONS[id]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UITheme.chip_style())
		chip.visible = false
		add_child(chip)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		chip.add_child(hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = def.get("icon", "?")
		icon_lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(icon_lbl)

		var level_lbl := Label.new()
		level_lbl.name = "LevelLabel"
		level_lbl.add_theme_font_size_override("font_size", 12)
		level_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
		if UITheme.font_body_bold:
			level_lbl.add_theme_font_override("font", UITheme.font_body_bold)
		hbox.add_child(level_lbl)

		chip.tooltip_text = def.get("label", id)
		_chips[id] = chip
		_level_labels[id] = level_lbl

func refresh() -> void:
	for id in _chips.keys():
		var chip: PanelContainer = _chips[id]
		var lvl: int = UpgradeManager.get_level(id)
		chip.visible = lvl > 0
		if lvl > 0:
			var level_lbl: Label = _level_labels.get(id)
			if level_lbl:
				level_lbl.text = "Lv%d" % lvl

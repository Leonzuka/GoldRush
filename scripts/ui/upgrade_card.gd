extends PanelContainer
class_name UpgradeCard

## Reusable upgrade card for the shop dialog.
## Shows icon, name, level pips, next-level effect text, cost and Buy button.
## Auto-refreshes on EventBus.upgrade_purchased and EventBus.money_changed.

var upgrade_id: String = ""

var _icon_lbl: Label
var _name_lbl: Label
var _level_lbl: Label
var _effect_lbl: Label
var _cost_lbl: Label
var _buy_btn: Button
var _loan_hint: Label

const CARD_MIN_SIZE := Vector2(170, 180)

func _ready() -> void:
	custom_minimum_size = CARD_MIN_SIZE
	add_theme_stylebox_override("panel", UITheme.panel_style())
	_build()
	EventBus.upgrade_purchased.connect(_on_any_upgrade_purchased)
	EventBus.money_changed.connect(_on_money_changed)
	refresh()

func _build() -> void:
	var def: Dictionary = Config.UPGRADE_DEFINITIONS.get(upgrade_id, {})

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(vbox)

	# Icon
	_icon_lbl = Label.new()
	_icon_lbl.text = def.get("icon", "?")
	_icon_lbl.add_theme_font_size_override("font_size", 28)
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_icon_lbl)

	# Name
	_name_lbl = Label.new()
	_name_lbl.text = tr(def.get("label", upgrade_id))
	_name_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme.font_heading:
		_name_lbl.add_theme_font_override("font", UITheme.font_heading)
	_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_lbl.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(_name_lbl)

	# Level pips
	_level_lbl = Label.new()
	_level_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	_level_lbl.add_theme_font_size_override("font_size", 12)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_level_lbl)

	# Effect text
	_effect_lbl = Label.new()
	_effect_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	_effect_lbl.add_theme_font_size_override("font_size", 11)
	_effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_effect_lbl)

	# Cost label
	_cost_lbl = Label.new()
	_cost_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	_cost_lbl.add_theme_font_size_override("font_size", 14)
	_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme.font_body_bold:
		_cost_lbl.add_theme_font_override("font", UITheme.font_body_bold)
	vbox.add_child(_cost_lbl)

	# Buy button
	_buy_btn = Button.new()
	_buy_btn.text = tr("UPGRADE_BUY")
	_buy_btn.add_theme_stylebox_override("normal", UITheme.action_button_style())
	_buy_btn.custom_minimum_size = Vector2(0, 32)
	_buy_btn.focus_mode = Control.FOCUS_NONE
	_buy_btn.pressed.connect(_on_buy_pressed)
	vbox.add_child(_buy_btn)

	# Hint shown when player can't afford — directs them to the Bank
	_loan_hint = Label.new()
	_loan_hint.text = tr("UPGRADE_LOAN_HINT")
	_loan_hint.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
	_loan_hint.add_theme_font_size_override("font_size", 10)
	_loan_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loan_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loan_hint.visible = false
	vbox.add_child(_loan_hint)

func refresh() -> void:
	if upgrade_id == "" or not Config.UPGRADE_DEFINITIONS.has(upgrade_id):
		return
	var def: Dictionary = Config.UPGRADE_DEFINITIONS[upgrade_id]
	var lvl: int = UpgradeManager.get_level(upgrade_id)
	var max_lvl: int = def.get("max_level", 1)

	_level_lbl.text = _format_pips(lvl, max_lvl)
	_effect_lbl.text = _format_effect(def, lvl)

	if UpgradeManager.is_maxed(upgrade_id):
		_cost_lbl.text = "MAX"
		_cost_lbl.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		_buy_btn.disabled = true
		_buy_btn.text = "—"
		if _loan_hint:
			_loan_hint.visible = false
	else:
		var cost: int = UpgradeManager.get_current_cost(upgrade_id)
		var can_buy: bool = UpgradeManager.can_purchase(upgrade_id)
		_cost_lbl.text = "$ %d" % cost
		_cost_lbl.add_theme_color_override("font_color",
			UITheme.COLOR_GOLD_PRIMARY if can_buy else UITheme.COLOR_DANGER)
		_buy_btn.disabled = not can_buy
		_buy_btn.text = tr("UPGRADE_BUY")
		if _loan_hint:
			_loan_hint.visible = not can_buy

func _format_pips(current: int, max_lvl: int) -> String:
	var s: String = ""
	for i in max_lvl:
		s += "●" if i < current else "○"
	return "%s  %s" % [s, tr("UPGRADE_LV") % [current, max_lvl]]

func _format_effect(def: Dictionary, current_lvl: int) -> String:
	var per: float = def.get("effect_per_level", 0.0)
	var kind: String = def.get("effect_kind", "multiplier")

	# Show CURRENT effect (already owned), then NEXT effect on the line below.
	var current_text: String = _format_effect_value(per, kind, current_lvl)
	if current_lvl >= def.get("max_level", 1):
		return tr("UPGRADE_CURRENT") % current_text
	var next_text: String = _format_effect_value(per, kind, current_lvl + 1)
	if current_lvl == 0:
		return tr("UPGRADE_NEXT") % next_text
	return tr("UPGRADE_CURRENT_NEXT") % [current_text, next_text]

func _format_effect_value(per: float, kind: String, lvl: int) -> String:
	match kind:
		"additive":
			# Storage / time bonus — display total bonus
			return "+%d" % int(round(per * lvl))
		"multiplier_inverse":
			# Cooldown reduction — show as negative percent
			var pct: float = per * lvl * 100.0
			return "-%d%%" % int(round(pct))
		_:
			# Standard multiplier — show as positive percent
			var pct2: float = per * lvl * 100.0
			return "+%d%%" % int(round(pct2))

func _on_buy_pressed() -> void:
	if UpgradeManager.purchase(upgrade_id):
		_play_purchase_punch()

func _play_purchase_punch() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_any_upgrade_purchased(_id: String, _new_level: int) -> void:
	# Refresh ALL cards on any purchase — money state changed for all
	refresh()

func _on_money_changed(_new_amount: int) -> void:
	refresh()

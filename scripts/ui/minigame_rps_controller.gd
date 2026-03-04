extends Control
class_name MinigameRPSController

## Best-of-3 Rock-Paper-Scissors minigame for challenging NPC-owned plots.
## UI is built entirely in code (no .tscn required).
## Emits minigame_finished(player_won, plot) when the match concludes.

# ============================================================================
# SIGNALS
# ============================================================================

signal minigame_finished(player_won: bool, plot: PlotData)

# ============================================================================
# PRIVATE STATE
# ============================================================================

var _plot: PlotData = null
var _npc_name: String = ""
var _npc_agent = null          # NPCAuctionAgent (untyped — inner class)
var _auction_system = null     # AuctionSystem ref (for player_rps_history)

var _player_wins: int = 0
var _npc_wins: int = 0
var _round_active: bool = false  # Blocks input during NPC "thinking" delay

# UI nodes built in _ready()
var _score_label: Label
var _result_label: Label
var _choice_row: HBoxContainer
var _continue_btn: Button
var _npc_choice_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to map below
	_build_ui()

## Start the minigame for the given plot and NPC
## @param auction_system_ref: AuctionSystem node — used to record player_rps_history
func start_minigame(plot: PlotData, npc_name: String, npc_agent, auction_system_ref = null) -> void:
	_plot = plot
	_npc_name = npc_name
	_npc_agent = npc_agent
	_auction_system = auction_system_ref
	_player_wins = 0
	_npc_wins = 0
	_round_active = true
	_populate_npc_info()
	_update_score_label()
	_result_label.text = "Choose your move!"
	_result_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	_continue_btn.visible = false
	_set_buttons_disabled(false)

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_ui() -> void:
	# -- Dark semi-transparent overlay --
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# -- Center panel --
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -270.0
	panel.offset_top    = -240.0
	panel.offset_right  = 270.0
	panel.offset_bottom = 240.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.045, 0.015, 0.98)
	panel_style.set_corner_radius_all(12)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.85)
	panel_style.content_margin_left   = 28.0
	panel_style.content_margin_right  = 28.0
	panel_style.content_margin_top    = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	if UITheme.font_heading:
		title_lbl.add_theme_font_override("font", UITheme.font_heading)
	vbox.add_child(title_lbl)
	# Title text is set in start_minigame — store reference via closure workaround
	# We'll set it after building, below.

	# NPC info row (avatar + name + personality tag)
	var npc_row := HBoxContainer.new()
	npc_row.add_theme_constant_override("separation", 12)
	npc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(npc_row)

	# NPC Avatar placeholder (filled in start_minigame, built now)
	var avatar_ctrl := _build_npc_avatar_placeholder()
	npc_row.add_child(avatar_ctrl)

	var npc_info_col := VBoxContainer.new()
	npc_info_col.add_theme_constant_override("separation", 2)
	npc_row.add_child(npc_info_col)

	var npc_name_lbl := Label.new()
	npc_name_lbl.add_theme_font_size_override("font_size", 16)
	npc_name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	npc_info_col.add_child(npc_name_lbl)

	var personality_lbl := Label.new()
	personality_lbl.add_theme_font_size_override("font_size", 12)
	personality_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	npc_info_col.add_child(personality_lbl)

	# Score label
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	if UITheme.font_heading:
		_score_label.add_theme_font_override("font", UITheme.font_heading)
	vbox.add_child(_score_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(UITheme.COLOR_GOLD_PRIMARY, 0.35))
	vbox.add_child(sep)

	# Choice buttons row
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 12)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_choice_row)

	var choices := [["✊", "Rock", "rock"], ["✋", "Paper", "paper"], ["✌️", "Scissors", "scissors"]]
	for choice_data in choices:
		var btn := Button.new()
		btn.text = "%s %s" % [choice_data[0], choice_data[1]]
		btn.custom_minimum_size = Vector2(108, 52)
		btn.add_theme_font_size_override("font_size", 16)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.14, 0.08, 0.03, 1.0)
		btn_style.set_corner_radius_all(8)
		btn_style.set_border_width_all(2)
		btn_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.5)
		btn_style.content_margin_top = 8.0
		btn_style.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style := btn_style.duplicate()
		hover_style.bg_color = Color(0.22, 0.14, 0.05, 1.0)
		hover_style.border_color = UITheme.COLOR_GOLD_BRIGHT
		btn.add_theme_stylebox_override("hover", hover_style)
		var key: String = choice_data[2]
		btn.pressed.connect(func(): _on_player_choice(key))
		_choice_row.add_child(btn)

	# NPC "thinking" + result row
	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 8)
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(result_row)

	var player_choice_lbl := Label.new()
	player_choice_lbl.name = "PlayerChoiceLabel"
	player_choice_lbl.add_theme_font_size_override("font_size", 13)
	player_choice_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	result_row.add_child(player_choice_lbl)

	_npc_choice_label = Label.new()
	_npc_choice_label.add_theme_font_size_override("font_size", 13)
	_npc_choice_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	result_row.add_child(_npc_choice_label)

	# Main result label
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 17)
	_result_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	if UITheme.font_heading:
		_result_label.add_theme_font_override("font", UITheme.font_heading)
	vbox.add_child(_result_label)

	# Continue button (hidden until round ends)
	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.visible = false
	_continue_btn.custom_minimum_size = Vector2(160, 44)
	var cont_style := UITheme.action_button_style()
	_continue_btn.add_theme_stylebox_override("normal", cont_style)
	_continue_btn.add_theme_font_size_override("font_size", 15)
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)

	# --- Fill dynamic text (requires _npc_name, but we set it during start_minigame) ---
	# Store label references for later text population
	title_lbl.name = "TitleLabel"
	npc_name_lbl.name = "NpcNameLabel"
	personality_lbl.name = "PersonalityLabel"
	avatar_ctrl.name = "AvatarCtrl"

func _build_npc_avatar_placeholder() -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(52, 52)
	return ctrl

# ============================================================================
# ROUND LOGIC
# ============================================================================

func _on_player_choice(choice: String) -> void:
	if not _round_active:
		return
	_round_active = false
	_set_buttons_disabled(true)

	# Record player choice in auction system history (for Lily's learning)
	if _auction_system:
		_auction_system.player_rps_history.append(choice)

	# Update player choice label
	var player_lbl := _find_label("PlayerChoiceLabel")
	if player_lbl:
		player_lbl.text = "You: %s" % choice.capitalize()

	# NPC "thinking" delay
	_npc_choice_label.text = "%s: ..." % _npc_name
	await get_tree().create_timer(0.5).timeout

	# NPC picks a move
	var history: Array = _auction_system.player_rps_history if _auction_system else []
	var npc_choice: String = "rock"
	if _npc_agent:
		npc_choice = _npc_agent.get_rps_choice(history)

	_npc_choice_label.text = "%s: %s" % [_npc_name, npc_choice.capitalize()]

	# Resolve
	var outcome := _resolve_round(choice, npc_choice)
	if outcome == 1:
		_player_wins += 1
		_result_label.text = "You win this round!"
		_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	elif outcome == -1:
		_npc_wins += 1
		_result_label.text = "%s wins this round!" % _npc_name
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		_result_label.text = "Tie! Go again."
		_result_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

	_update_score_label()

	# Check if match is over (first to 2 wins)
	if _player_wins >= 2 or _npc_wins >= 2:
		await get_tree().create_timer(1.0).timeout
		_show_final_result()
	else:
		await get_tree().create_timer(1.2).timeout
		# Reset for next round
		if player_lbl:
			player_lbl.text = ""
		_npc_choice_label.text = ""
		_result_label.text = "Choose your move!"
		_result_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
		_round_active = true
		_set_buttons_disabled(false)

func _show_final_result() -> void:
	var player_won := _player_wins >= 2
	if player_won:
		_result_label.text = "VICTORY! You claimed %s!" % _plot.plot_name
		_result_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.45))
	else:
		_result_label.text = "DEFEAT! %s keeps the plot." % _npc_name
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	_continue_btn.visible = true
	_round_active = false

func _on_continue_pressed() -> void:
	var player_won := _player_wins >= 2
	minigame_finished.emit(player_won, _plot)

## Returns 1 if player wins, -1 if NPC wins, 0 for tie
func _resolve_round(player: String, npc: String) -> int:
	if player == npc:
		return 0
	var wins_against := {"rock": "scissors", "scissors": "paper", "paper": "rock"}
	if wins_against.get(player, "") == npc:
		return 1
	return -1

func _update_score_label() -> void:
	if _score_label:
		_score_label.text = "You  %d — %d  %s" % [_player_wins, _npc_wins, _npc_name]

func _set_buttons_disabled(disabled: bool) -> void:
	if _choice_row:
		for child in _choice_row.get_children():
			if child is Button:
				child.disabled = disabled

# ============================================================================
# HELPERS
# ============================================================================

## Populate dynamic labels and avatar after start_minigame() sets _npc_name etc.
func _populate_npc_info() -> void:
	var title_lbl := _find_label("TitleLabel")
	if title_lbl:
		title_lbl.text = "Duel for %s!" % _plot.plot_name

	var npc_name_lbl := _find_label("NpcNameLabel")
	if npc_name_lbl:
		npc_name_lbl.text = _npc_name
		var npc_color = Config.NPC_COLORS.get(_npc_name, Color.WHITE)
		npc_name_lbl.add_theme_color_override("font_color", npc_color.lightened(0.3))

	var personality_lbl := _find_label("PersonalityLabel")
	if personality_lbl and _npc_agent:
		var tag_map := {
			"conservative": "🏕 Conservative",
			"aggressive": "⚔ Aggressive",
			"cunning": "🦊 Cunning",
			"smart": "🧠 Smart",
		}
		personality_lbl.text = tag_map.get(_npc_agent.personality, _npc_agent.personality.capitalize())

	# Build avatar with NPC image or fallback initial
	var avatar_ctrl := _find_control("AvatarCtrl")
	if avatar_ctrl:
		_fill_avatar(avatar_ctrl)

func _fill_avatar(ctrl: Control) -> void:
	var npc_color: Color = Config.NPC_COLORS.get(_npc_name, Color(0.5, 0.5, 0.8))
	var img_path: String = Config.NPC_IMAGES.get(_npc_name, "")

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(npc_color.r * 0.25, npc_color.g * 0.25, npc_color.b * 0.25, 1.0)
	bg_style.set_corner_radius_all(26)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color(npc_color.r, npc_color.g, npc_color.b, 0.9)

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", bg_style)
	ctrl.add_child(bg)

	var tex: Texture2D = load(img_path) as Texture2D if not img_path.is_empty() else null
	if tex:
		var trect := TextureRect.new()
		trect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		trect.texture = tex
		trect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tif (length(uv) > 0.5) { discard; }\n\tCOLOR = texture(TEXTURE, UV);\n}"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		trect.material = mat
		ctrl.add_child(trect)
	else:
		# Procedural fallback: colored circle with initial letter
		var lbl := Label.new()
		lbl.text = _npc_name[0].to_upper() if _npc_name.length() > 0 else "?"
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", npc_color.lightened(0.4))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(lbl)

func _find_label(node_name: String) -> Label:
	return _find_node_recursive(self, node_name) as Label

func _find_control(node_name: String) -> Control:
	return _find_node_recursive(self, node_name) as Control

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	return null

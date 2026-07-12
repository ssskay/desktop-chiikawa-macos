extends Node2D

const SAVE_PATH := "user://pet_state.cfg"
const WANDER_SPEED := 40.0
const MENU_ID_SNACK := 10
const MENU_ID_WANDER := 11
const BASE_WINDOW := Vector2i(400, 250)
const SIZE_PRESETS := [0.75, 1.0, 1.5, 2.0, 3.0]

@onready var sprite = $AnimatedSprite2D
@onready var chat_bubble = $AnimatedSprite2D / ChatBubble
@onready var chat_label = $AnimatedSprite2D / ChatBubble / Label
@onready var reminder_timer = $AnimatedSprite2D / reminder_timer
@onready var popup_hide_timer = $AnimatedSprite2D / popup_hide_timer

@onready var right_click_menu = $RightClickMenu
@onready var language_menu = $RightClickMenu / LanguageMenu
@onready var skin_menu = $RightClickMenu / SkinMenu
@onready var reminder_menu = $RightClickMenu / ReminderMenu
@onready var size_menu = $RightClickMenu / SizeMenu

@onready var custom_reminder_popup = $CustomReminderPopup
@onready var custom_reminder_spinbox = $CustomReminderPopup / VBoxContainer / CustomReminderSpinbox
@onready var custom_reminder_label = $CustomReminderPopup / VBoxContainer / ReminderLabel

@onready var custom_message_popup = $CustomMessagePopup
@onready var custom_message_edit = $CustomMessagePopup / VBoxContainer / CustomMessageEdit
@onready var custom_message_button = $CustomMessagePopup / VBoxContainer / CustomMessageConfirmButton

var dragging: = false
var drag_offset: = Vector2.ZERO
var drag_dist: = 0.0
var press_ms: = 0
var pressed_on_sprite: = false

var current_language = "en"
var current_skin = "Chiikawa"
var custom_reminder_msg = ""

var wander_enabled: = true
var wander_state: = "idle"
var wander_dir: = Vector2.RIGHT
var wander_time_left: = 0.0
var window_pos_f: = Vector2.ZERO
var base_scale: = Vector2.ONE
var base_sprite_pos: = Vector2.ZERO
var size_mult: = 1.0
var size_names: = {
	"en": ["Small", "Normal", "Large", "Huge", "Giant"],
	"jp": ["小", "普通", "大", "特大", "巨大"],
	"yue": ["細", "正常", "大", "超大", "巨型"],
	"zh_cn": ["小", "正常", "大", "超大", "巨大"],
	"zh_tw": ["小", "正常", "大", "超大", "巨大"],
}
var _menubar_base: = -1
var _native_rids: Array[RID] = []
var _status_id: = -1

var messages: = {
	"en": {
		"health": [
			"(ノ´ヮ`)ノ Time to stretch!",
			"( ˘▽˘)っ旦~ Water time! Hydrate~",
			"(¬‿¬) Blink your eyes! Rest them~",
			"(￣▽￣)ﾉ Roll your shoulders back~",
			"(｡•́‿•̀｡) Posture check — sit up tall~",
			"(づ｡◕‿‿◕｡)づ Look far away for 20 seconds~",
			"ヽ(´▽`)ノ Stand up and move a little!",
			"( ˶ˆ ᗜ ˆ˵ ) Unclench your jaw, deep breath~",
			"(っ˘ω˘ς ) One task done? Take a mini break~",
			"(ᐢ⑅•ᴗ•⑅ᐢ) Wiggle your fingers, relax your hands~"
		],
		"night": ["(´-ω-)｡ﾟzzZ It's late... I'm sleepy...", "(ᴗ˳ᴗ) Shouldn't you be in bed?"],
		"greet_m": ["ヽ(´▽`)ノ Good morning! Let's have a great day!"],
		"greet_a": ["(￣▽￣)ノ Good afternoon~ Keep it up!"],
		"greet_e": ["(´｡• ᵕ •｡`) Good evening! Time to wind down~"]
	},
	"jp": {
		"health": [
			"(ノ´ヮ`)ノ ストレッチしよう！",
			"( ˘▽˘)っ旦~ お水飲んでね〜",
			"(¬‿¬) 目を休めて〜",
			"(￣▽￣)ﾉ 肩を回してみよう〜",
			"(｡•́‿•̀｡) 姿勢を正して、背筋ピン！",
			"(づ｡◕‿‿◕｡)づ 20秒だけ遠くを見て〜",
			"ヽ(´▽`)ノ 立ち上がって少し動こう！",
			"( ˶ˆ ᗜ ˆ˵ ) 顎の力を抜いて、深呼吸〜",
			"(っ˘ω˘ς ) ひと仕事おわった？少し休憩〜",
			"(ᐢ⑅•ᴗ•⑅ᐢ) 手をぶらぶら、リラックス〜"
		],
		"night": ["(´-ω-)｡ﾟzzZ もう遅いよ…ねむい…", "(ᴗ˳ᴗ) そろそろ寝ようよ〜"],
		"greet_m": ["ヽ(´▽`)ノ おはよう！今日もがんばろう！"],
		"greet_a": ["(￣▽￣)ノ こんにちは〜 その調子！"],
		"greet_e": ["(´｡• ᵕ •｡`) こんばんは！ゆっくりしてね〜"]
	},
	"yue": {
		"health": ["(ノ´ヮ`)ノ 伸吓懶腰啦～", "( ˘▽˘)っ旦~ 飲杯水先～", "(¬‿¬) 眨吓眼啦！"],
		"night": ["(´-ω-)｡ﾟzzZ 好夜喇…眼瞓喇…", "(ᴗ˳ᴗ) 係咪應該去訓覺？"],
		"greet_m": ["ヽ(´▽`)ノ 早晨呀！今日一齊加油！"],
		"greet_a": ["(￣▽￣)ノ 午安呀～繼續努力！"],
		"greet_e": ["(´｡• ᵕ •｡`) 晚上好呀～休息吓啦～"]
	},
	"zh_cn": {
		"health": ["(ノ´ヮ`)ノ 起来活动一下～", "( ˘▽˘)っ旦~ 喝点水吧～", "(¬‿¬) 眨一眨眼！"],
		"night": ["(´-ω-)｡ﾟzzZ 好晚了…好困…", "(ᴗ˳ᴗ) 该睡觉了吧？"],
		"greet_m": ["ヽ(´▽`)ノ 早上好！今天也要加油哦！"],
		"greet_a": ["(￣▽￣)ノ 下午好～继续加油！"],
		"greet_e": ["(´｡• ᵕ •｡`) 晚上好！放松一下吧～"]
	},
	"zh_tw": {
		"health": ["(ノ´ヮ`)ノ 起來伸展一下～", "( ˘▽˘)っ旦~ 喝點水唄～", "(¬‿¬) 眨眨眼吧！"],
		"night": ["(´-ω-)｡ﾟzzZ 好晚了…好睏…", "(ᴗ˳ᴗ) 該睡覺了吧？"],
		"greet_m": ["ヽ(´▽`)ノ 早安！今天也要加油喔！"],
		"greet_a": ["(￣▽￣)ノ 午安～繼續加油！"],
		"greet_e": ["(´｡• ᵕ •｡`) 晚安時間快到了～放鬆一下吧～"]
	}
}

# Character voices — real catchphrases from the series.
# Chiikawa hums 波のピエロ (the yampapa song), Usagi yells Ura/Yaha,
# Hachiware has ~tte koto!?, Momonga demands to be called cute.
# Goblins have no canon lines, so they get mischievous noises.
# "ja" shows for all non-English UI languages; "en" is romanized/translated.
var voice: = {
	"ja": {
		"Chiikawa": {
			"pet": ["ワァ…！ (ᐢ⑅•ᴗ•⑅ᐢ)", "…フ…フフ… (´｡• ᵕ •｡`)", "ヤン パン パパン ルラルラ〜♪"],
			"snack": ["……！！ (ᐢ⑅˃ᗜ˂⑅ᐢ)", "ワ〜！ (≧▽≦)", "ヤン パン パパン♪ ( ˶ˆᗜˆ˵ )"],
			"cozy": ["ヤン パン パパン ルラルラ〜♪", "フ…フフ… (´｡• ᵕ •｡`)", "ぇ〜ん (ಥ﹏ಥ)", "ワァ… (⁎˃ᆺ˂)"]
		},
		"Hachiware": {
			"pet": ["えへへ…ってコト！？ (≧▽≦)", "サイコ〜！ ヽ(´▽`)ノ", "いいってことよ〜 (￣▽￣)"],
			"snack": ["サイコー！ (≧▽≦)", "うんまい…ってコト！？ Σ(°△°)", "なんとかなれーッ！ ٩(ˊᗜˋ*)و"],
			"cozy": ["なんとかなれーッ！ ٩(ˊᗜˋ*)و", "〜ってコト！？ Σ(°△°)", "全然わかんない (・_・;)", "泣いちゃった (｡•́︿•̀｡)"]
		},
		"Usagi": {
			"pet": ["ウラ！ ٩(ˊᗜˋ*)و", "ヤハ！！ ヽ(°〇°)ﾉ", "フゥン (￣ｰ￣)", "プルルルルル！"],
			"snack": ["ウラウラ！ (≧▽≦)", "イヤーッハ！！ ヽ(°〇°)ﾉ", "ヤハ〜！ ٩(ˊᗜˋ*)و"],
			"cozy": ["ハァ？ (￢_￢)", "ウラ… ( ˙▿˙ )", "ヤハ ヽ(´ー｀)ノ", "プルルル…"]
		},
		"Goblin": {
			"pet": ["フーッ フーッ (｀ｪ´)", "ケケケ… (￣ｰ￣)", "グル…？ (・o・)"],
			"snack": ["ケケケケ！ (≧ｪ≦)", "グルルル〜♪ (￣ｰ￣)", "フンフン♪ ( ˙▿˙ )"],
			"cozy": ["フーッ… (｀ｪ´)", "ケケ… (￣ｰ￣)", "グルル… (¬､¬)"]
		},
		"Momonga": {
			"pet": ["かわいいねって言え (｀へ´*)ノ", "かわいこぶってやる (￣ｰ￣)", "フフン ( ･´ー･｀)"],
			"snack": ["甘いものが食べたいんだよォー！ (๑>◡<๑)", "もっとよこせ (｀へ´*)ノ", "ヤダヤダ〜！ (≧▽≦)"],
			"cozy": ["慰めろ (｀へ´*)ノ", "ヤダヤダ (｀Δ´)！", "見ろ！ ( ･´ー･｀)", "抱っこして (๑•́ ₃ •̀๑)"]
		}
	},
	"en": {
		"Chiikawa": {
			"pet": ["Waah...! (ᐢ⑅•ᴗ•⑅ᐢ)", "...Hee...hehe... (´｡• ᵕ •｡`)", "Yan pan papan rurarura~♪"],
			"snack": ["......!! (ᐢ⑅˃ᗜ˂⑅ᐢ)", "Wah~! (≧▽≦)", "Yan pan papan♪ ( ˶ˆᗜˆ˵ )"],
			"cozy": ["Yan pan papan rurarura~♪", "Hee...hehe... (´｡• ᵕ •｡`)", "Waaahh~ (ಥ﹏ಥ)", "Wah... (⁎˃ᆺ˂)"]
		},
		"Hachiware": {
			"pet": ["Ehehe... you mean it?! (≧▽≦)", "The BEST! ヽ(´▽`)ノ", "Don't mention it~ (￣▽￣)"],
			"snack": ["The BEST! (≧▽≦)", "So yummy... wait, REALLY?! Σ(°△°)", "It'll all work ouuut!! ٩(ˊᗜˋ*)و"],
			"cozy": ["It'll all work ouuut!! ٩(ˊᗜˋ*)و", "...Wait, REALLY?! Σ(°△°)", "I don't get it at all (・_・;)", "I cried (｡•́︿•̀｡)"]
		},
		"Usagi": {
			"pet": ["Ura! ٩(ˊᗜˋ*)و", "Yaha!! ヽ(°〇°)ﾉ", "Hmmph (￣ｰ￣)", "Prrrrrr!"],
			"snack": ["Ura ura! (≧▽≦)", "Yeee-HA!! ヽ(°〇°)ﾉ", "Yaha~! ٩(ˊᗜˋ*)و"],
			"cozy": ["Haah?? (￢_￢)", "Ura... ( ˙▿˙ )", "Yaha ヽ(´ー｀)ノ", "Prrrr..."]
		},
		"Goblin": {
			"pet": ["Fff! Fff! (｀ｪ´)", "Kekeke... (￣ｰ￣)", "Grr...? (・o・)"],
			"snack": ["Kekekeke! (≧ｪ≦)", "Grrrr~♪ (￣ｰ￣)", "Hmm hmm♪ ( ˙▿˙ )"],
			"cozy": ["Fff... (｀ｪ´)", "Keke... (￣ｰ￣)", "Grrr... (¬､¬)"]
		},
		"Momonga": {
			"pet": ["Say I'm cute! (｀へ´*)ノ", "I'll act all cute (￣ｰ￣)", "Hmhm ( ･´ー･｀)"],
			"snack": ["I want something sweeeet!! (๑>◡<๑)", "Gimme more (｀へ´*)ノ", "No no no~! (≧▽≦)"],
			"cozy": ["Comfort me (｀へ´*)ノ", "No! No! (｀Δ´)!", "Look at me! ( ･´ー･｀)", "Hold me (๑•́ ₃ •̀๑)"]
		}
	}
}


func _voice_pool(kind: String) -> Array:
	var lang_key = "en" if current_language == "en" else "ja"
	return voice[lang_key][current_skin][kind]

var ui_labels: = {
	"snack": {"en": "Give Snack 🍙", "jp": "おやつをあげる 🍙", "yue": "俾零食 🍙", "zh_cn": "给零食 🍙", "zh_tw": "給零食 🍙"},
	"wander": {"en": "Wander around", "jp": "おさんぽモード", "yue": "自己四圍行", "zh_cn": "自由走动", "zh_tw": "自由走動"}
}

func _ready():
	DisplayServer.window_set_title("chiikawaPet")
	randomize()

	get_viewport().transparent_bg = true
	chat_bubble.hide()
	base_scale = sprite.scale
	base_sprite_pos = sprite.position

	reminder_timer.wait_time = 900
	_load_state()

	sprite.play(current_skin)
	reminder_timer.timeout.connect(_on_reminder)
	reminder_timer.start()

	popup_hide_timer.wait_time = 3
	popup_hide_timer.timeout.connect(_hide_popup)

	custom_message_button.pressed.connect(_on_custom_message_confirm)
	custom_message_edit.text_submitted.connect(_on_custom_message_confirm)

	_init_menus()

	wander_time_left = randf_range(2.0, 5.0)

	await get_tree().create_timer(1.2).timeout
	_show_greeting()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()


func _save_state():
	var cfg = ConfigFile.new()
	var p = DisplayServer.window_get_position()
	cfg.set_value("pet", "pos_x", p.x)
	cfg.set_value("pet", "pos_y", p.y)
	cfg.set_value("pet", "skin", current_skin)
	cfg.set_value("pet", "lang", current_language)
	cfg.set_value("pet", "reminder_sec", reminder_timer.wait_time)
	cfg.set_value("pet", "wander", wander_enabled)
	cfg.set_value("pet", "size_mult", size_mult)
	cfg.set_value("pet", "custom_msg", custom_reminder_msg)
	var err = cfg.save(SAVE_PATH)
	if err != OK:
		print("ChiikawaPet: failed to save state, error ", err)


func _load_state():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		print("ChiikawaPet: no saved state yet, using defaults")
		return
	current_skin = cfg.get_value("pet", "skin", current_skin)
	current_language = cfg.get_value("pet", "lang", current_language)
	wander_enabled = cfg.get_value("pet", "wander", true)
	custom_reminder_msg = cfg.get_value("pet", "custom_msg", "")
	reminder_timer.wait_time = cfg.get_value("pet", "reminder_sec", 900)
	_apply_size(cfg.get_value("pet", "size_mult", 1.0), false)
	var px = cfg.get_value("pet", "pos_x", null)
	var py = cfg.get_value("pet", "pos_y", null)
	if px != null and py != null:
		var pos = Vector2i(int(px), int(py))
		if _pos_visible(pos):
			DisplayServer.window_set_position(pos)
			print("ChiikawaPet: restored position ", pos)
		else:
			print("ChiikawaPet: saved position off-screen, ignoring")


func _pos_visible(p: Vector2i) -> bool:
	var wsize = DisplayServer.window_get_size()
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).intersects(Rect2i(p, wsize)):
			return true
	return false


func _ui_label(key: String) -> String:
	return ui_labels[key].get(current_language, ui_labels[key]["en"])


func _init_menus():

	match current_language:
		"jp":
			custom_reminder_label.text = "分数を入力してください："
		"yue":
			custom_reminder_label.text = "輸入分鐘："
		"zh_cn":
			custom_reminder_label.text = "输入时间（分钟）："
		"zh_tw":
			custom_reminder_label.text = "輸入時間（分鐘）："
		_:
			custom_reminder_label.text = "Enter custom time in minutes:"


	language_menu.clear()
	skin_menu.clear()
	right_click_menu.clear()


	language_menu.add_item("English", 0)
	language_menu.add_item("日本語", 1)
	if not language_menu.id_pressed.is_connected(_on_language_selected):
		language_menu.id_pressed.connect(_on_language_selected)

	right_click_menu.clear()

	var reminder_label: = ""
	match current_language:
		"jp":
			reminder_label = "リマインダー設定"
		"yue":
			reminder_label = "設定提醒"
		"zh_cn":
			reminder_label = "设置提醒"
		"zh_tw":
			reminder_label = "設定提醒"
		_:
			reminder_label = "Set Reminder"

	right_click_menu.add_submenu_item(
	"語言" if current_language in ["jp", "yue", "zh_cn", "zh_tw"] else "Language",
	"LanguageMenu"
	)
	right_click_menu.add_submenu_item(
		"皮膚" if current_language in ["jp", "yue", "zh_cn", "zh_tw"] else "Skin",
		"SkinMenu"
	)
	right_click_menu.add_submenu_item(
		{"jp": "サイズ", "yue": "大細", "zh_cn": "大小", "zh_tw": "大小"}.get(current_language, "Size"),
		"SizeMenu"
	)
	right_click_menu.add_submenu_item(reminder_label, "ReminderMenu")

	right_click_menu.add_separator()
	right_click_menu.add_item(_ui_label("snack"), MENU_ID_SNACK)
	right_click_menu.add_check_item(_ui_label("wander"), MENU_ID_WANDER)
	right_click_menu.set_item_checked(right_click_menu.get_item_index(MENU_ID_WANDER), wander_enabled)
	if not right_click_menu.id_pressed.is_connected(_on_main_menu_id_pressed):
		right_click_menu.id_pressed.connect(_on_main_menu_id_pressed)


	skin_menu.add_item("Chiikawa", 0)
	skin_menu.add_item("Hachiware", 1)
	skin_menu.add_item("Usagi", 2)
	skin_menu.add_item("Goblin", 3)
	skin_menu.add_item("Momonga", 4)
	if not skin_menu.id_pressed.is_connected(_on_skin_selected):
		skin_menu.id_pressed.connect(_on_skin_selected)


	size_menu.clear()
	var s_names = size_names.get(current_language, size_names["en"])
	for i in SIZE_PRESETS.size():
		size_menu.add_radio_check_item(s_names[i], i)
		size_menu.set_item_checked(i, is_equal_approx(SIZE_PRESETS[i], size_mult))
	if not size_menu.id_pressed.is_connected(_on_size_selected):
		size_menu.id_pressed.connect(_on_size_selected)


	reminder_menu.clear()

	var min_label: = ""
	var custom_label: = ""
	match current_language:
		"jp":
			min_label = "分"
			custom_label = "カスタム時間..."
		"yue":
			min_label = "分鐘"
			custom_label = "自定義..."
		"zh_cn":
			min_label = "分钟"
			custom_label = "自定义..."
		"zh_tw":
			min_label = "分鐘"
			custom_label = "自訂..."
		_:
			min_label = "min"
			custom_label = "Custom time..."

	reminder_menu.add_item("5 %s" % min_label)
	reminder_menu.set_item_metadata(0, 5)
	reminder_menu.add_item("10 %s" % min_label)
	reminder_menu.set_item_metadata(1, 10)
	reminder_menu.add_item("30 %s" % min_label)
	reminder_menu.set_item_metadata(2, 30)
	reminder_menu.add_separator()
	reminder_menu.add_item(custom_label)
	reminder_menu.set_item_metadata(4, -1)
	reminder_menu.add_separator()
	var msg_label = "カスタムメッセージ..." if current_language == "jp" else "Custom message..."
	var default_label = "デフォルトに戻す" if current_language == "jp" else "Default reminders"
	reminder_menu.add_item(msg_label)
	reminder_menu.set_item_metadata(6, -2)
	reminder_menu.add_item(default_label)
	reminder_menu.set_item_metadata(7, -3)
	$CustomMessagePopup / VBoxContainer / MessageLabel.text = "何をリマインドする？" if current_language == "jp" else "What should I remind you?"
	custom_message_button.text = "保存" if current_language == "jp" else "Save"

	if not reminder_menu.id_pressed.is_connected(_on_ReminderMenu_id_pressed):
		reminder_menu.id_pressed.connect(_on_ReminderMenu_id_pressed)

	_build_native_menus()



func _on_language_selected(id: int) -> void :
	match id:
		0:
			current_language = "en"
		1:
			current_language = "jp"

	_init_menus()
	_save_state()


func _on_main_menu_id_pressed(id: int) -> void :
	match id:
		MENU_ID_SNACK:
			_on_snack()
		MENU_ID_WANDER:
			_toggle_wander()


func _on_size_selected(id: int) -> void :
	_apply_size(SIZE_PRESETS[id], true)
	for i in size_menu.item_count:
		size_menu.set_item_checked(i, i == id)
	_save_state()
	_build_native_menus()


func _apply_size(mult: float, recenter: bool) -> void :
	size_mult = mult
	sprite.scale = base_scale * mult
	sprite.position = base_sprite_pos * mult
	var new_size = Vector2i(roundi(BASE_WINDOW.x * mult), roundi(BASE_WINDOW.y * mult))
	if recenter:
		var c = DisplayServer.window_get_position() + DisplayServer.window_get_size() / 2
		DisplayServer.window_set_size(new_size)
		DisplayServer.window_set_position(c - new_size / 2)
	else:
		DisplayServer.window_set_size(new_size)
	_update_passthrough()


func _on_snack():
	show_message(_voice_pool("snack").pick_random())
	_bounce()


func _on_petted():
	show_message(_voice_pool("pet").pick_random())
	_bounce()


func _bounce():
	var tw = create_tween()
	var s = base_scale * size_mult
	tw.tween_property(sprite, "scale", s * 1.15, 0.1)
	tw.tween_property(sprite, "scale", s, 0.15)


func _show_greeting():
	var h = Time.get_time_dict_from_system().hour
	var key: = "greet_m"
	if h >= 22 or h < 5:
		key = "night"
	elif h >= 17:
		key = "greet_e"
	elif h >= 12:
		key = "greet_a"
	show_message(messages[current_language][key].pick_random())


func _on_reminder():
	if custom_reminder_msg != "":
		show_message(custom_reminder_msg)
		return
	var h = Time.get_time_dict_from_system().hour
	if (h >= 23 or h < 5) and randf() < 0.5:
		show_message(messages[current_language]["night"].pick_random())
		return
	var use_health = randf() < 0.5
	var msg = messages[current_language]["health"].pick_random() if use_health else _voice_pool("cozy").pick_random()
	show_message(msg)

func show_message(msg: String):
	chat_label.text = msg
	chat_bubble.show()
	popup_hide_timer.start()

func _hide_popup():
	chat_bubble.hide()


func _update_passthrough():
	# Only the area around the sprite (and chat bubble when visible) accepts
	# clicks; everywhere else the window is click-through so it never blocks
	# interaction with other apps.
	var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var sz = tex.get_size() * sprite.scale
	var r = Rect2(sprite.global_position - sz * 0.5, sz).grow(10.0)
	if chat_bubble.visible:
		r = r.merge(chat_bubble.get_global_rect())
	var poly = PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y)
	])
	DisplayServer.window_set_mouse_passthrough(poly)


func _process(delta):
	_update_passthrough()
	var menu_open = right_click_menu.visible or custom_reminder_popup.visible
	var can_wander = wander_enabled and not dragging and not menu_open

	if can_wander:
		wander_time_left -= delta
		if wander_time_left <= 0.0:
			_pick_wander_state()
		if wander_state == "walk":
			_wander_step(delta)

	var walking = can_wander and wander_state == "walk"
	var should_play = dragging or walking or not wander_enabled
	if should_play and not sprite.is_playing():
		sprite.play(current_skin)
	elif not should_play and sprite.is_playing():
		sprite.pause()


func _pick_wander_state():
	if wander_state == "walk":
		wander_state = "idle"
		wander_time_left = randf_range(2.5, 8.0)
	else:
		wander_state = "walk"
		wander_time_left = randf_range(1.5, 4.5)
		var ang = randf_range(-0.35, 0.35)
		if randf() < 0.5:
			wander_dir = Vector2.RIGHT.rotated(ang)
		else:
			wander_dir = Vector2.LEFT.rotated(ang)
		window_pos_f = Vector2(DisplayServer.window_get_position())


func _wander_step(delta):
	window_pos_f += wander_dir * WANDER_SPEED * delta
	var wsize = Vector2(DisplayServer.window_get_size())
	var r = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if window_pos_f.x < r.position.x:
		window_pos_f.x = r.position.x
		wander_dir.x = abs(wander_dir.x)
	if window_pos_f.x + wsize.x > r.end.x:
		window_pos_f.x = r.end.x - wsize.x
		wander_dir.x = - abs(wander_dir.x)
	if window_pos_f.y < r.position.y:
		window_pos_f.y = r.position.y
		wander_dir.y = abs(wander_dir.y)
	if window_pos_f.y + wsize.y > r.end.y:
		window_pos_f.y = r.end.y - wsize.y
		wander_dir.y = - abs(wander_dir.y)
	sprite.flip_h = wander_dir.x < 0
	DisplayServer.window_set_position(Vector2i(window_pos_f))


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var pos = get_global_mouse_position()

				var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				var sprite_size = tex.get_size() * sprite.scale
				var sprite_rect = Rect2(sprite.global_position - sprite_size * 0.5, sprite_size)
				var drag_from_sprite = sprite_rect.has_point(pos)

				var drag_from_bubble = chat_bubble.visible and chat_bubble.get_global_rect().has_point(pos)

				if drag_from_sprite or drag_from_bubble:
					dragging = true
					drag_offset = event.position
					drag_dist = 0.0
					press_ms = Time.get_ticks_msec()
					pressed_on_sprite = drag_from_sprite
			else:
				if dragging:
					if pressed_on_sprite and drag_dist < 8.0 and Time.get_ticks_msec() - press_ms < 400:
						_on_petted()
					_save_state()
				dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_click_menu.popup(Rect2i(event.global_position, Vector2i(1, 1)))

	elif event is InputEventMouseMotion and dragging:
		drag_dist += event.relative.length()
		var mouse_global = Vector2(DisplayServer.mouse_get_position())
		var new_window_pos = mouse_global - drag_offset
		DisplayServer.window_set_position(Vector2i(new_window_pos))
		window_pos_f = new_window_pos

func _on_skin_selected(id: int):
	match id:
		0:
			_set_skin("Chiikawa")
		1:
			_set_skin("Hachiware")
		2:
			_set_skin("Usagi")
		3:
			_set_skin("Goblin")
		4:
			_set_skin("Momonga")

func _set_skin(skin_name: String):
	current_skin = skin_name
	sprite.play(skin_name)
	_save_state()
	_build_native_menus()


func _on_reminder_timer_timeout() -> void :
	pass

func _on_ReminderMenu_id_pressed(id: int) -> void :
	var value = reminder_menu.get_item_metadata(id)
	if value == -1:
		custom_reminder_popup.popup_centered()
	elif value == -2:
		_open_custom_message()
	elif value == -3:
		_clear_custom_message()
	else:
		reminder_timer.wait_time = value * 60
		reminder_timer.start()
		_save_state()


func _open_custom_message() -> void :
	custom_message_edit.text = custom_reminder_msg
	custom_message_popup.popup_centered(Vector2i(320, 120))
	custom_message_edit.grab_focus()


func _clear_custom_message() -> void :
	custom_reminder_msg = ""
	_save_state()


func _on_custom_message_confirm(_submitted: String = "") -> void :
	custom_reminder_msg = custom_message_edit.text.strip_edges()
	custom_message_popup.hide()
	_save_state()

func _on_custom_reminder_confirm_button_pressed() -> void :
	var minutes = custom_reminder_spinbox.value
	if minutes > 0:
		reminder_timer.wait_time = minutes * 60
		reminder_timer.start()
		custom_reminder_popup.hide()
		_save_state()


# ---------------------------------------------------------------------------
# Native macOS menus: the top-left app menu bar and an always-visible menu-bar
# tray icon, both mirroring the right-click commands. Rebuilt from current
# state whenever a setting changes. No-op on platforms without a system menu.
# ---------------------------------------------------------------------------
func _tr_menu(key: String) -> String :
	var jp = {
		"skin": "皮膚", "size": "サイズ", "language": "言語",
		"reminder": "リマインダー設定", "actions": "操作",
		"min": "分", "custom": "カスタム時間...", "quit": "終了",
		"custom_msg": "カスタムメッセージ...", "default_rem": "デフォルトに戻す",
	}
	var en = {
		"skin": "Skin", "size": "Size", "language": "Language",
		"reminder": "Set Reminder", "actions": "Actions",
		"min": "min", "custom": "Custom time...", "quit": "Quit",
		"custom_msg": "Custom message...", "default_rem": "Default reminders",
	}
	return jp[key] if current_language == "jp" else en[key]


func _nm_menu_skin() -> RID :
	var m = NativeMenu.create_menu()
	_native_rids.append(m)
	var skins = ["Chiikawa", "Hachiware", "Usagi", "Goblin", "Momonga"]
	for i in skins.size():
		var idx = NativeMenu.add_radio_check_item(m, skins[i], _nm_skin, Callable(), i)
		NativeMenu.set_item_checked(m, idx, skins[i] == current_skin)
	return m


func _nm_menu_size() -> RID :
	var m = NativeMenu.create_menu()
	_native_rids.append(m)
	var names = size_names.get(current_language, size_names["en"])
	for i in SIZE_PRESETS.size():
		var idx = NativeMenu.add_radio_check_item(m, names[i], _nm_size, Callable(), i)
		NativeMenu.set_item_checked(m, idx, is_equal_approx(SIZE_PRESETS[i], size_mult))
	return m


func _nm_menu_lang() -> RID :
	var m = NativeMenu.create_menu()
	_native_rids.append(m)
	var a = NativeMenu.add_radio_check_item(m, "English", _nm_lang, Callable(), 0)
	NativeMenu.set_item_checked(m, a, current_language == "en")
	var b = NativeMenu.add_radio_check_item(m, "日本語", _nm_lang, Callable(), 1)
	NativeMenu.set_item_checked(m, b, current_language == "jp")
	return m


func _nm_menu_reminder() -> RID :
	var m = NativeMenu.create_menu()
	_native_rids.append(m)
	var unit = _tr_menu("min")
	NativeMenu.add_item(m, "5 %s" % unit, _nm_reminder, Callable(), 5)
	NativeMenu.add_item(m, "10 %s" % unit, _nm_reminder, Callable(), 10)
	NativeMenu.add_item(m, "30 %s" % unit, _nm_reminder, Callable(), 30)
	NativeMenu.add_separator(m)
	NativeMenu.add_item(m, _tr_menu("custom"), _nm_reminder, Callable(), -1)
	NativeMenu.add_item(m, _tr_menu("custom_msg"), _nm_reminder, Callable(), -2)
	NativeMenu.add_item(m, _tr_menu("default_rem"), _nm_reminder, Callable(), -3)
	return m


func _nm_menu_actions() -> RID :
	var m = NativeMenu.create_menu()
	_native_rids.append(m)
	NativeMenu.add_item(m, _ui_label("snack"), _nm_snack, Callable(), 0)
	var w = NativeMenu.add_check_item(m, _ui_label("wander"), _nm_wander, Callable(), 0)
	NativeMenu.set_item_checked(m, w, wander_enabled)
	return m


func _build_native_menus() -> void :
	if not NativeMenu.has_system_menu(NativeMenu.MAIN_MENU_ID):
		return
	var main = NativeMenu.get_system_menu(NativeMenu.MAIN_MENU_ID)
	if _menubar_base < 0:
		_menubar_base = NativeMenu.get_item_count(main)
	# tear down the top-level menus we added last time, then free old submenus
	while NativeMenu.get_item_count(main) > _menubar_base:
		NativeMenu.remove_item(main, NativeMenu.get_item_count(main) - 1)
	for r in _native_rids:
		if NativeMenu.has_menu(r):
			NativeMenu.free_menu(r)
	_native_rids.clear()

	# top-left app menu bar
	NativeMenu.add_submenu_item(main, _tr_menu("skin"), _nm_menu_skin())
	NativeMenu.add_submenu_item(main, _tr_menu("size"), _nm_menu_size())
	NativeMenu.add_submenu_item(main, _tr_menu("language"), _nm_menu_lang())
	NativeMenu.add_submenu_item(main, _tr_menu("reminder"), _nm_menu_reminder())
	NativeMenu.add_submenu_item(main, _tr_menu("actions"), _nm_menu_actions())

	# always-visible menu-bar tray icon: same commands in one dropdown
	var root = NativeMenu.create_menu()
	_native_rids.append(root)
	NativeMenu.add_submenu_item(root, _tr_menu("skin"), _nm_menu_skin())
	NativeMenu.add_submenu_item(root, _tr_menu("size"), _nm_menu_size())
	NativeMenu.add_submenu_item(root, _tr_menu("language"), _nm_menu_lang())
	NativeMenu.add_submenu_item(root, _tr_menu("reminder"), _nm_menu_reminder())
	NativeMenu.add_separator(root)
	NativeMenu.add_item(root, _ui_label("snack"), _nm_snack, Callable(), 0)
	var w = NativeMenu.add_check_item(root, _ui_label("wander"), _nm_wander, Callable(), 0)
	NativeMenu.set_item_checked(root, w, wander_enabled)
	NativeMenu.add_separator(root)
	NativeMenu.add_item(root, _tr_menu("quit"), _nm_quit, Callable(), 0)

	if _status_id == -1:
		_status_id = DisplayServer.create_status_indicator(load("res://icon.png"), "Chiikawa Pet", Callable())
	DisplayServer.status_indicator_set_menu(_status_id, root)


# Native callbacks receive the item tag. Defer the action so we never rebuild a
# menu from inside its own activation callback.
func _nm_skin(tag): _on_skin_selected.call_deferred(int(tag))
func _nm_size(tag): _on_size_selected.call_deferred(int(tag))
func _nm_lang(tag): _on_language_selected.call_deferred(int(tag))
func _nm_reminder(tag): _nm_set_reminder.call_deferred(int(tag))
func _nm_snack(_tag): _on_snack.call_deferred()
func _nm_wander(_tag): _toggle_wander.call_deferred()
func _nm_quit(_tag): _quit.call_deferred()


func _nm_set_reminder(mins: int) -> void :
	if mins == -1:
		custom_reminder_popup.popup_centered()
	elif mins == -2:
		_open_custom_message()
	elif mins == -3:
		_clear_custom_message()
	else:
		reminder_timer.wait_time = mins * 60
		reminder_timer.start()
		_save_state()


func _toggle_wander() -> void :
	wander_enabled = not wander_enabled
	right_click_menu.set_item_checked(right_click_menu.get_item_index(MENU_ID_WANDER), wander_enabled)
	if wander_enabled:
		wander_state = "idle"
		wander_time_left = randf_range(1.0, 3.0)
	_save_state()
	_build_native_menus()


func _quit() -> void :
	_save_state()
	get_tree().quit()

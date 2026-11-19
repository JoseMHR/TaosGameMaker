# OrbBarksManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# GESTOR DE FASES Y MENSAJES DE LA ESFERA DE LA VERDAD
#
# La Esfera de la Verdad es el guía permanente de la misión principal.
# Implementa el sistema de 3 Modos:
#   · Modo 1: Esfera grande en el centro + modal (bloquea al jugador). Explica acontecimientos.
#   · Modo 2: Esfera pequeña en la esquina. Al pulsarla, resume el objetivo principal actual (mensaje pequeño).
#   · Modo 3: Esfera pequeña en la esquina. Infraestructura para diálogos automáticos/comentarios (barks).
# ─────────────────────────────────────────────────────────────────────────────
extends Node

signal bark_requested(speaker: String, text: String, duration: float)
signal important_message_requested(text: String, quest_state: String, flag_to_set: String)

## Tiempo en segundos sin progreso para lanzar una pista de atasco (5 minutos).
const STUCK_TIMEOUT: float = 300.0

var _barks_db: Dictionary = {}
var _stuck_timer: float = 0.0
var _session_resume_reminder_shown: bool = false

## Registro oficial de las 5 Fases del Prólogo
const PHASES: Dictionary = {
	1: {
		"large": {
			"es": "La palanca para iluminar esta sala debería encontrarse en el primer piso.",
			"en": "The lever to light up this room should be on the first floor.",
			"fr": "Le levier pour éclairer cette pièce devrait se trouver au premier étage.",
			"it": "La leva per illuminare questa stanza dovrebbe trovarsi al primo piano.",
			"de": "Der Hebel, um diesen Raum zu erleuchten, sollte sich im ersten Stock befinden.",
			"zh": "点亮这个房间的拉杆应该在一楼。",
			"ja": "この部屋を照らすレバーは1階にあるはずだ。"
		},
		"small": {
			"es": "Sube al primer piso y acciona la palanca.",
			"en": "Go up to the first floor and pull the lever.",
			"fr": "Monte au premier étage et actionne le levier.",
			"it": "Sali al primo piano e aziona la leva.",
			"de": "Gehe in den ersten Stock und betätige den Hebel.",
			"zh": "上到一楼并拉动拉杆。",
			"ja": "1階に上がってレバーを引け。"
		}
	},
	2: {
		"large": {
			"es": "¡¿Pero qué has hecho?! Te dije la otra palanca. ¡Lo has llenado todo de lava! Sal corriendo por el piso superior, ¡corre! Aprovecharé que estás en mi rango de alcance para proporcionarte el recuerdo de todas tus habilidades temporalmente. ¡Úsalas para huir!",
			"en": "What did you just do?! I told you the other lever! You flooded everything with lava! Run out through the upper floor, run! While you're within my range, I'll temporarily grant you the memory of all your skills. Use them to escape!",
			"fr": "Mais qu'est-ce que tu as fait ?! Je t'avais dit l'autre levier ! Tu as tout inondé de lave ! Cours vers l'étage supérieur, cours ! Tant que tu es à ma portée, je vais te conférer temporairement le souvenir de toutes tes compétences. Utilise-les pour t'enfuir !",
			"it": "Ma cosa hai fatto?! Ti avevo detto l'altra leva! Hai allagato tutto di lava! Corri verso il piano superiore, corri! Finché sei nel mio raggio, ti concederò temporaneamente il ricordo di tutte le tue abilità. Usale per fuggire!",
			"de": "Was hast du bloß getan?! Ich sagte der andere Hebel! Du hast alles mit Lava überflutet! Renn durch das obere Stockwerk hinaus, renn! Solange du in meiner Reichweite bist, verleihe ich dir vorübergehend die Erinnerung an all deine Fähigkeiten. Nutze sie, um zu fliehen!",
			"zh": "你到底干了什么？！我说了是另一个拉杆！你把这里全灌满岩浆了！快从顶层跑出去，快跑！趁你还在我的感知范围内，我暂时借给你所有技能的记忆。用它们逃出去！",
			"ja": "なんてことしてくれたんだ？！もう片方のレバーだと言っただろう！一面マグマ浸しじゃないか！上の階から急いで逃げろ、走れ！私の届く範囲にいるうちに、一時的にお前のすべての技の記憶を取り戻してやろう。それらを使って脱出するんだ！"
		},
		"small": {
			"es": "¡Corre! ¡Sal de aquí!",
			"en": "Run! Get out of here!",
			"fr": "Cours ! Sors d'ici !",
			"it": "Corri! Esci da qui!",
			"de": "Renn! Raus hier!",
			"zh": "快跑！离开这里！",
			"ja": "走れ！ここから脱出しろ！"
		}
	},
	3: {
		"large": {
			"es": "Has logrado salir con vida... por los pelos. ¿Es que no puedes estar un momento sin liarla? Me has inundado de lava mi entrada trasera... en serio... En fin, necesitarás llegar en barco por mi otra entrada, así que dirígete al Puerto de Celestia, al este. Aunque estás demasiado débil para cruzar el túnel del Yelmo.",
			"en": "You made it out alive... barely. Can't you go one minute without making a mess? You flooded my back entrance with lava... seriously... Anyway, you'll need to reach my other entrance by boat, so head to the Port of Celestia, to the east. Though you're too weak to cross the Helm tunnel right now.",
			"fr": "Tu t'en es sorti vivant... de justesse. Tu ne peux pas passer une minute sans semer le chaos ? Tu as inondé mon entrée arrière de lave... sérieusement... Bref, tu devras atteindre mon autre entrée par bateau, alors dirige-toi vers le Port de Celestia, à l'est. Même si tu es trop faible pour traverser le tunnel du Heaume pour l'instant.",
			"it": "Sei riuscito a uscirne vivo... per un pelo. Non puoi stare un attimo senza combinare guai? Hai allagato di lava la mia entrata sul retro... sul serio... Comunque, dovrai raggiungere l'altra entrata in barca, quindi dirigiti al Porto di Celestia, a est. Anche se sei troppo debole per attraversare il tunnel dell'Elmo adesso.",
			"de": "Du bist mit dem Leben davongekommen... haarscharf. Kannst du nicht eine Minute lang keinen Ärger machen? Du hast meinen Hintereingang mit Lava geflutet... im Ernst... Wie auch immer, du musst meinen anderen Eingang mit dem Boot erreichen, also mach dich auf den Weg zum Hafen von Celestia im Osten. Obwohl du im Moment zu schwach bist, um den Helm-Tunnel zu durchqueren.",
			"zh": "你竟然活着出来了……千钧一发。你就不能消停哪怕一分钟吗？你把我的后门全都淹没在熔岩里了……说真的……算了，你需要坐船到达我的另一个入口，往东去塞拉斯蒂亚港口吧。虽然你现在太虚弱了，还过不去头盔隧道。",
			"ja": "命からがら脱出できたようだな……間一髪だったぞ。少しもおとなしくしていられないのか？私の裏口をマグマまみれにしてくれて……まったく……ともかく、船で私の別の入口に向かう必要がある。東のセレスティア港を目指せ。もっとも、今の弱り切ったお前ではヘルムのトンネルを抜けるのは無理だがな。"
		},
		"small": {
			"es": "Investiga la forma de salir del Yelmo.",
			"en": "Find a way to leave the Helm.",
			"fr": "Trouve un moyen de quitter le Heaume.",
			"it": "Trova un modo per uscire dall'Elmo.",
			"de": "Finde einen Weg, den Helm zu verlassen.",
			"zh": "寻找离开头盔区域的方法。",
			"ja": "ヘルムから脱出する方法を探せ。"
		}
	},
	4: {
		"large": {
			"es": "¡Enhorabuena por atravesar el túnel del monstruo! Ahora te aguarda el frío inclemente de la montaña helada. Cruza la montaña helada con cuidado.",
			"en": "Congratulations on making it through the monster's tunnel! Now the biting cold of the frozen mountain awaits you. Cross the frozen mountain carefully.",
			"fr": "Félicitations pour avoir traversé le tunnel du monstre ! Maintenant, le froid mordant de la montagne gelée t'attend. Traverse la montagne gelée avec prudence.",
			"it": "Congratulazioni per aver attraversato il tunnel del mostro! Ora ti aspetta il freddo pungente della montagna ghiacciata. Attraversa la montagna ghiacciata con cautela.",
			"de": "Glückwunsch zum Überqueren des Monstertunnels! Nun erwartet dich die eisige Kälte des gefrorenen Berges. Überquere den gefrorenen Berg vorsichtig.",
			"zh": "恭喜你穿过了怪物的隧道！现在冰山的刺骨严寒在等待着你。小心穿过冰山。",
			"ja": "怪物のトンネル突破、見事だったぞ！次は凍てつく雪山の過酷な寒さが待っている。油断せずに雪山を越えろ。"
		},
		"small": {
			"es": "Cruza la montaña helada.",
			"en": "Cross the frozen mountain.",
			"fr": "Traverse la montagne gelée.",
			"it": "Attraversa la montagna ghiacciata.",
			"de": "Überquere den gefrorenen Berg.",
			"zh": "穿过冰山。",
			"ja": "凍てつく雪山を越えろ。"
		}
	},
	5: {
		"large": {
			"es": "¡Ya casi estamos! La grandiosa ciudad de Celestia está muy cerca. Atraviesa la pradera y dirígete al puerto.",
			"en": "We're almost there! The grand city of Celestia is very close. Cross the meadow and head to the port.",
			"fr": "Nous y sommes presque ! La grandiose cité de Celestia est toute proche. Traverse la prairie et dirige-toi vers le port.",
			"it": "Ci siamo quasi! La grandiosa città di Celestia è vicinissima. Attraversa la prateria e dirigiti al porto.",
			"de": "Wir sind fast da! Die grandiose Stadt Celestia ist ganz in der Nähe. Durchquere die Wiese und begib dich zum Hafen.",
			"zh": "我们快到了！宏伟的塞拉斯蒂亚城就在不远处。穿过草地前往港口。",
			"ja": "もうすぐそこだ！雄大なるセレスティアの街は目の前だぞ。草原を抜けて港へ向かえ。"
		},
		"small": {
			"es": "Llega hasta Celestia.",
			"en": "Reach Celestia.",
			"fr": "Atteins Celestia.",
			"it": "Raggiungi Celestia.",
			"de": "Erreiche Celestia.",
			"zh": "到达塞拉斯蒂亚。",
			"ja": "セレスティアに到達せよ。"
		}
	}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_barks_db()
	if GlobalState != null:
		GlobalState.state_updated.connect(_on_state_updated)
	if SceneManager != null:
		SceneManager.navigate_to.connect(func(v_name: String, _data: Dictionary) -> void:
			if v_name == "menu" or v_name == "splash":
				_session_resume_reminder_shown = false
		)
		SceneManager.view_changed.connect(func(_v_name: String) -> void:
			if SaveManager != null and SaveManager.active:
				check_overworld_milestones()
		)
	if SaveManager != null:
		SaveManager.game_loaded.connect(func() -> void:
			_session_resume_reminder_shown = false
		)


func _load_barks_db() -> void:
	var path := "res://data/orb_barks.json"
	if not FileAccess.file_exists(path):
		path = "user://data/orb_barks.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json is Dictionary:
				_barks_db = json


func _process(delta: float) -> void:
	if SceneRunner != null and SceneRunner.is_active():
		return
	if SaveManager != null and not SaveManager.active:
		return
	if SceneManager != null and not SceneManager.is_orb_allowed():
		return

	_stuck_timer += delta
	if _stuck_timer >= STUCK_TIMEOUT:
		_stuck_timer = 0.0
		trigger_stuck_hint()


## Devuelve la fase actual del prólogo (1..5)
func get_current_phase() -> int:
	if GlobalState != null:
		return int(GlobalState.get_world_flag_val("sphere_phase", 1))
	return 1


## Avanza o establece la fase del prólogo, mostrando opcionalmente el Modo 1 (Modal grande)
func set_phase(p: int, show_modal: bool = true) -> void:
	var old_p := get_current_phase()
	if GlobalState != null:
		GlobalState.set_world_flag("sphere_phase", p)

	if show_modal or p != old_p:
		var p_data: Dictionary = PHASES.get(p, {})
		var raw_large = p_data.get("large", "")
		var msg: String = Locale.pick(raw_large) if raw_large is Dictionary else String(raw_large)
		if msg != "":
			trigger_important_message(msg)


## Modo 2: Muestra el resumen corto del objetivo actual al pulsar la Esfera pequeña
func get_small_hint() -> String:
	var p := get_current_phase()
	var p_data: Dictionary = PHASES.get(p, {})
	var raw_small = p_data.get("small", "")
	var small: String = Locale.pick(raw_small) if raw_small is Dictionary else String(raw_small)
	if small != "":
		return small
	if QuestManager != null:
		var q: Dictionary = QuestManager.get_active_quest()
		var hint_text: String = String(Locale.pick(q.get("hint", {}))) if q.has("hint") else ""
		if hint_text != "":
			return hint_text
	return Locale.pick({
		"es": "Explora el valle.",
		"en": "Explore the valley.",
		"fr": "Explore la vallée.",
		"it": "Esplora la valle.",
		"de": "Erkunde das Tal.",
		"zh": "探索山谷。",
		"ja": "谷を探索しろ。"
	})


## Modo 3: Infraestructura para comentarios automáticos de la Esfera
func trigger_auto_comment(comment_text: String, duration: float = 4.5) -> void:
	var sphere_lbl := Locale.pick({
		"es": "Esfera: '%s'",
		"en": "Sphere: '%s'",
		"fr": "Sphère : « %s »",
		"it": "Sfera: '%s'",
		"de": "Sphäre: '%s'",
		"zh": "光球：“%s”",
		"ja": "光球：「%s」"
	})
	trigger_bark(sphere_lbl % comment_text, duration)


## Dispara un bocadillo de texto plano (*bark*) directamente (Modo 3).
func trigger_bark(text: String, duration: float = 4.5) -> void:
	if text.strip_edges() == "":
		return
	var sphere_name := Locale.pick({
		"es": "Esfera de la Verdad",
		"en": "Sphere of Truth",
		"fr": "Sphère de la Vérité",
		"it": "Sfera della Verità",
		"de": "Sphäre der Wahrheit",
		"zh": "真理之球",
		"ja": "真理の球"
	})
	bark_requested.emit(sphere_name, text, duration)


## Dispara un aviso/popup de historia de la Esfera (alias compatible con TabWorld3D).
func trigger_story_popup(text: String, duration: float = 5.0) -> void:
	trigger_bark(text, duration)


## Dispara un bark data-driven por su clave en `data/orb_barks.json`.
func trigger_bark_key(key: String, duration: float = 4.5) -> void:
	var entry = _barks_db.get(key, null)
	if entry is Dictionary:
		var txt: String = String(Locale.pick(entry))
		trigger_bark(txt, duration)
	elif entry is String:
		trigger_bark(String(entry), duration)
	else:
		trigger_bark(key, duration)


## Dispara un mensaje importante de hito principal (Modo 1: Esfera en el centro + Modal).
func trigger_important_message(text: String, quest_state: String = "", flag_to_set: String = "") -> void:
	if text.strip_edges() == "":
		return
	important_message_requested.emit(text, quest_state, flag_to_set)


## Dispara un bark derivado de un token de recompensa DSL (`bark:CLAVE_O_TEXTO`).
func trigger_bark_from_token(val: String) -> void:
	if _barks_db.has(val):
		trigger_bark_key(val)
	else:
		trigger_bark(val)


## Verificación estricta de hitos narrativos del mapamundi (Fases 3, 4 y 5).
func check_overworld_milestones() -> void:
	if GlobalState == null or SceneManager == null:
		return
	if SaveManager != null and not SaveManager.active:
		return
	if not SceneManager.is_orb_allowed():
		return
	if SceneManager.current_view_name != "world":
		return

	var phase := get_current_phase()

	# Transición a Fase 3: Salida de la primera mazmorra (al llegar al mapamundi)
	if phase < 3 and (GlobalState.cave_cleared or GlobalState.has_world_flag("cave_cleared") or GlobalState.has_world_flag("prologue_dungeon_cleared")):
		_session_resume_reminder_shown = true
		set_phase(3, true)
		return

	# Transición a Fase 4: Al cruzar el túnel (zona helada / cueva despejada)
	if phase == 3 and (GlobalState.has_world_flag("tunnel_cleared") or GlobalState.has_world_flag("cave_cleared")):
		var cur_cell: CellResource = GlobalState.hexagons_db.get(GlobalState.player_pos, null) as CellResource
		if cur_cell != null and (cur_cell.terrain == "bad" or cur_cell.terrain == "snw" or GlobalState.has_world_flag("crossed_tunnel")):
			_session_resume_reminder_shown = true
			set_phase(4, true)
			return

	# Transición a Fase 5: Al entrar en la pradera (terreno grs tras la nieve)
	if phase == 4:
		var cur_cell2: CellResource = GlobalState.hexagons_db.get(GlobalState.player_pos, null) as CellResource
		if cur_cell2 != null and cur_cell2.terrain == "grs":
			_session_resume_reminder_shown = true
			set_phase(5, true)
			return

	# Si ya construyó la base en algún momento, nos aseguramos de que el flag quede registrado
	if GlobalState.has_built_base:
		if not GlobalState.has_world_flag("tent_first_obtained_announced"):
			GlobalState.set_world_flag("tent_first_obtained_announced", true)

	# Hito: Primera obtención de la Tienda de Campaña (Modo 1 en grande)
	if (GlobalState.has_item("tent") or GlobalState.has_world_flag("tent_ever_obtained")) and not GlobalState.has_world_flag("tent_first_obtained_announced") and not GlobalState.has_built_base:
		GlobalState.set_world_flag("tent_first_obtained_announced", true)
		trigger_important_message(Locale.pick({
			"es": "¡Mira qué bien, por fin tenemos techo propio! Consigue algo de madera y monta la tienda en una pradera despejada para establecer tu campamento base. Te vendrá de perlas para descansar y pasar la noche a salvo... a menos que prefieras que te devoren las alimañas.",
			"en": "Well look at that, we finally have our own roof! Gather some wood and pitch the tent in an open meadow to set up your base camp. It'll be a lifesaver for resting and surviving the night... unless you'd rather be beast food.",
			"fr": "Eh bien regarde-moi ça, on a enfin un toit à nous ! Récolte du bois et plante la tente dans une prairie dégagée pour établir ton camp de base. Ça te sauvera la vie pour te reposer et survivre à la nuit... à moins que tu préfères servir de repas aux bêtes.",
			"it": "Ma guarda un po', finalmente abbiamo un tetto tutto nostro! Raccogli del legno e pianta la tenda in una radura sgombra per stabilire il tuo campo base. Sarà una salvezza per riposare e sopravvivere alla notte... a meno che tu non preferisca finire come pasto per le bestie.",
			"de": "Sieh mal einer an, wir haben endlich unser eigenes Dach! Sammle etwas Holz und schlage das Zelt auf einer freien Wiese auf, um dein Basislager einzurichten. Das wird dir das Leben retten, um dich auszuruhen und die Nacht sicher zu überstehen... es sei denn, du willst lieber Tierfutter werden.",
			"zh": "瞧瞧，我们终于有了自己的屋顶！收集一些木材，在空旷的草地上搭起帐篷，建立你的基地营地。这对于休息和安全度过夜晚将大有帮助……除非你更想被野兽吃掉。",
			"ja": "見てくれよ、ついに自分の屋根を手に入れたぞ！木材を集めて、開けた草原にテントを張り、拠点キャンプを設けよう。休息を取り、夜を安全に乗り切るのに大いに役立つはずだ……野獣の餌になりたいのでなければな。",
		}), "", "tent_first_obtained_announced")
		return

	# Hito: Aviso de 5ª habilidad aprendida cuando los 4 huecos de combate están llenos
	if check_skill_overflow_milestone():
		return

	# Hito: Aviso de Sendero superado (vuelve con el maestro para desbloquear la profesión)
	if check_trial_completed_milestone():
		return

	# Recordatorio al CONTINUAR / Reanudar Partida Guardada (1 vez por sesión al volver al mapa)
	if not _session_resume_reminder_shown:
		_session_resume_reminder_shown = true
		var small_msg: String = get_small_hint()
		var resume_msg := Locale.pick({
			"es": "¡De vuelta! Recuerda tu objetivo actual: %s",
			"en": "Welcome back! Remember your current objective: %s",
			"fr": "De retour ! N'oublie pas ton objectif actuel : %s",
			"it": "Bentornato! Ricorda il tuo obiettivo attuale: %s",
			"de": "Willkommen zurück! Erinnere dich an dein aktuelles Ziel: %s",
			"zh": "欢迎回来！记住你当前的目标：%s",
			"ja": "おかえり！現在の目的を忘れるなよ：%s"
		}) % small_msg
		trigger_important_message(resume_msg, "", "")


## Lanza una pista de ayuda si el jugador pasa 5 minutos sin avanzar.
func trigger_stuck_hint() -> void:
	var small_hint := get_small_hint()
	var stuck_prefix := Locale.pick({
		"es": "Esfera: '%s'",
		"en": "Sphere: '%s'",
		"fr": "Sphère : « %s »",
		"it": "Sfera: '%s'",
		"de": "Sphäre: '%s'",
		"zh": "光球：“%s”",
		"ja": "光球：「%s」"
	})
	trigger_bark(stuck_prefix % small_hint)


func reset_stuck_timer() -> void:
	_stuck_timer = 0.0


func _on_state_updated() -> void:
	reset_stuck_timer()
	check_overworld_milestones()


## Comprueba si se ha aprendido una 5ª habilidad y los 4 huecos están llenos para avisar con la Esfera en grande.
func check_skill_overflow_milestone() -> bool:
	if GlobalState == null or SceneManager == null:
		return false
	if not SceneManager.is_orb_allowed():
		return false
	if not GlobalState.has_world_flag("sphere_skill_overflow_warned") and GlobalState.has_any_job_skill_overflow():
		GlobalState.set_world_flag("sphere_skill_overflow_warned", true)
		trigger_important_message(Locale.pick({
			"es": "¡Oye, despabilado! Parece que has aprendido una nueva habilidad de combate pero tus 4 ranuras activas ya están llenas. ¡No te cabe en la cabeza tanta técnica junta! Abre el menú en la pestaña de Profesiones para gestionarlas y sustituirla por alguna de las que ya tienes asignadas.",
			"en": "Hey, wake up! Looks like you learned a new combat skill, but your 4 active slots are already full! You can't fit that much technique in your head at once! Open the menu under the Professions tab to manage them and swap it in for one of your currently equipped ones.",
			"fr": "Hé, réveille-toi ! On dirait que tu as appris une nouvelle compétence de combat, mais tes 4 emplacements actifs sont déjà pleins ! Ouvre le menu dans l'onglet Professions pour les gérer et la remplacer par l'une de celles déjà équipées.",
			"it": "Ehi, sveglia! Sembra che tu abbia appreso una nuova abilità di combattimento, ma i tuoi 4 slot attivi sono già pieni! Apri il menu nella scheda Professioni per gestirle e sostituirla con una di quelle già equipaggiate.",
			"de": "He, aufwachen! Es sieht so aus, als hättest du eine neue Kampffertigkeit gelernt, aber deine 4 aktiven Plätze sind bereits voll! Öffne das Menü unter Berufe, um sie zu verwalten und sie gegen eine deiner ausgerüsteten auszutauschen.",
			"zh": "嘿，醒醒！看来你学会了一项新的战斗技能，但你的4个激活槽位已经满了！打开菜单进入‘职业’页面来管理技能，把当前装备的技能替换为你想要的吧。",
			"ja": "おい、しっかりしろ！新しい戦闘スキルを習得したようだが、4つのアクティブスロットはすでに満杯だぞ！メニューの「職業」タブを開いて管理し、セットされているスキルと入れ替えよう。"
		}), "", "sphere_skill_overflow_warned")
		return true
	return false


## Comprueba si se ha completado la prueba de un Sendero para que la Esfera oriente al jugador hacia el entrenador.
func check_trial_completed_milestone() -> bool:
	if GlobalState == null or SceneManager == null:
		return false
	if not SceneManager.is_orb_allowed():
		return false
	if GlobalState.pending_trial_completed_sendero == "":
		return false

	var sendero_id: String = GlobalState.pending_trial_completed_sendero
	GlobalState.pending_trial_completed_sendero = ""

	const TRIAL_DATA: Dictionary = {
		"sendero_guerrero": {
			"prof": "Guerrero",
			"name": {"es": "Guerrero", "en": "Warrior"},
			"trainer": {"es": "tu maestro el Guerrero", "en": "your master the Warrior"}
		},
		"sendero_psiquico": {
			"prof": "Psíquico",
			"name": {"es": "Psíquico", "en": "Psychic"},
			"trainer": {"es": "tu maestro el Psíquico", "en": "your master the Psychic"}
		},
		"sendero_tiempo": {
			"prof": "Tiempo",
			"name": {"es": "Tiempo", "en": "Time Mage"},
			"trainer": {"es": "tu maestro del Tiempo", "en": "your master the Time Mage"}
		},
		"sendero_arquero": {
			"prof": "Arquero",
			"name": {"es": "Arquero", "en": "Archer"},
			"trainer": {"es": "tu maestro el Arquero", "en": "your master the Archer"}
		},
		"sendero_elementalista": {
			"prof": "Elementalista",
			"name": {"es": "Elementalista", "en": "Elementalist"},
			"trainer": {"es": "tu maestra la Elementalista", "en": "your master the Elementalist"}
		},
		"sendero_sacerdote": {
			"prof": "Sacerdote",
			"name": {"es": "Sacerdote", "en": "Priest"},
			"trainer": {"es": "el Sumo Sacerdote", "en": "the High Priest"}
		}
	}

	if not TRIAL_DATA.has(sendero_id):
		return false

	var t_data: Dictionary = TRIAL_DATA[sendero_id]
	var prof_id: String = String(t_data.get("prof", ""))
	if prof_id in GlobalState.unlocked_professions:
		return false

	var prof_name: String = Locale.pick(t_data.get("name", {}))
	var trainer_name: String = Locale.pick(t_data.get("trainer", {}))

	var msg: String = Locale.pick({
		"es": "¡Buen trabajo! Has superado la prueba del sendero. Vuelve a hablar con %s para contarle tu victoria y así desbloquearás la profesión de %s." % [trainer_name, prof_name],
		"en": "Great job! You passed the trial of the path. Go back and talk to %s to report your victory and unlock the %s profession." % [trainer_name, prof_name],
		"fr": "Beau travail ! Tu as réussi l'épreuve du sentier. Retourne voir %s pour lui annoncer ta victoire et ainsi débloquer la profession de %s." % [trainer_name, prof_name],
		"it": "Ottimo lavoro! Hai superato la prova del sentiero. Ora torna da %s per riferirgli la tua vittoria e sbloccare la professione di %s." % [trainer_name, prof_name],
		"de": "Gute Arbeit! Du hast die Prüfung des Pfades bestanden. Kehre jetzt zu %s zurück, um deinen Sieg zu melden und den Beruf %s freizuschalten." % [trainer_name, prof_name],
		"zh": "干得漂亮！你通过了试炼之路。现在回到%s那里汇报你的胜利，就能解锁%s职业了。" % [trainer_name, prof_name],
		"ja": "見事だ！道の試練を乗り越えたな。%sの元へ戻って勝利を報告し、%sの職業を解放しよう。" % [trainer_name, prof_name]
	})

	trigger_important_message(msg)
	return true


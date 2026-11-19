# OrbCompanionManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# GESTOR DINÁMICO DE DIÁLOGOS Y COMPORTAMIENTO DE LA ESFERA ACOMPAÑANTE
#
# Entidad flotante mística, omnisciente, con humor agudo, irónico y absurdo.
# Sabe que está en un videojuego (rompe la 4ª pared), conoce las mecánicas,
# la barra de vida, los bugs, las trampas y el mapa.
#
# Arquitectura:
#   - Modo Pequeño (SMALL): Comentarios contextuales en bocadillo lateral (3.5s).
#   - Modo Grande (LARGE): Hitos de historia, revelaciones y avisos de bloqueo.
#   - Anti-repetición Shuffle-Bag: Mazo aleatorio por categoría que se vacía
#     antes de volver a barajar, imposibilitando repeticiones inmediatas.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

signal play_orb_bark(text: String, mode: String)

enum Mode { SMALL, LARGE }

## Tiempos de enfriamiento activos por evento (ms)
var cooldowns: Dictionary = {}

## Registro de banderas de interacción única
var flags: Dictionary = {
	"seen_stone_block_first": false,
	"seen_lava_first": false,
	"seen_ice_first": false,
	"seen_boat_first": false,
	"seen_dungeon_first": false
}

## Mazos de anti-repetición (Shuffle-Bag): event_id -> Array de líneas restantes
var _decks: Dictionary = {}

## Rastreo de movimiento cinemático
var _last_step_dir: Vector2i = Vector2i.ZERO
var _straight_steps_count: int = 0
var _recent_cells: Array[Vector2i] = []
var _circle_detect_cooldown: float = 0.0

## Rastreo de toques directos a la esfera (Pokes)
var _poke_count: int = 0
var _last_poke_time: float = 0.0

## Cooldown global de cortesía entre barks espontáneos (para no solapar ni aturdir)
var _last_any_bark_time: float = 0.0
const MIN_GLOBAL_BARK_INTERVAL: float = 4.0

## Catálogo exhaustivo de diálogos estructurado por etiquetas de contexto
const DIALOGUE_POOLS: Dictionary = {
	"lava_step": {
		"es": [
			"¡Illo, que te quemas!",
			"¿Está calentita o te pongo un té con pastitas?",
			"Aviso médico: la piel tostada a la brasa no sube tus estadísticas.",
			"Aterrizar en lava: 0 estrellas en TripAdvisor. No lo recomiendo.",
			"Huelo a barbacoa de primera calidad... ah, no, espera, eres tú.",
			"Si querías depilación láser, la lava es un método un pelín drástico.",
			"Recuerda que la suela de tus botas no es ignífuga en esta versión del motor.",
			"Me encanta el aroma a carbón por la mañana, pero preferiría que no fuera tu pierna."
		],
		"en": [
			"Hey, you're burning!",
			"Is it nice and warm, or shall I fetch you some tea and biscuits?",
			"Medical notice: char-grilled skin does not raise your stats.",
			"Landing on lava: 0 stars on TripAdvisor. Would not recommend.",
			"I smell top-quality barbecue... oh, wait, that's you.",
			"If you wanted laser hair removal, lava is a slightly drastic method.",
			"Remember, your boot soles aren't fireproof in this build of the engine.",
			"I love the smell of charcoal in the morning, but I'd rather it wasn't your leg."
		],
		"fr": [
			"Hé, tu es en train de brûler !",
			"C'est bien chaud, ou je te sers un thé avec des petits gâteaux ?",
			"Avis médical : la peau grillée au barbecue n'augmente pas tes stats.",
			"Atterrir dans la lave : 0 étoile sur TripAdvisor. Je ne recommande pas.",
			"Je sens un barbecue de première qualité... ah non, attends, c'est toi.",
			"Si tu voulais une épilation au laser, la lave est une méthode un peu radicale.",
			"Rappelle-toi que la semelle de tes bottes n'est pas ignifugée dans cette version du moteur.",
			"J'adore l'odeur du charbon le matin, mais je préférerais que ce ne soit pas ta jambe."
		],
		"it": [
			"Ehi, ti stai bruciando!",
			"È bella calda o ti porto un tè con i biscotti?",
			"Avviso medico: la pelle grigliata alla brace non aumenta le tue statistiche.",
			"Atterrare sulla lava: 0 stelle su TripAdvisor. Non lo consiglio.",
			"Sento profumo di barbecue di prima qualità... ah, no, aspetta, sei tu.",
			"Se volevi la depilazione laser, la lava è un metodo un po' drastico.",
			"Ricorda che la suola dei tuoi stivali non è ignifuga in questa versione del motore.",
			"Adoro l'odore di carbone al mattino, ma preferirei non fosse la tua gamba."
		],
		"de": [
			"He, du verbrennst dir was!",
			"Ist es schön warm, oder soll ich dir Tee mit Keksen bringen?",
			"Medizinischer Hinweis: gegrillte Haut erhöht deine Werte nicht.",
			"Landung in Lava: 0 Sterne auf TripAdvisor. Kann ich nicht empfehlen.",
			"Ich rieche erstklassiges Barbecue... ach, warte, das bist ja du.",
			"Wenn du Laser-Haarentfernung wolltest, ist Lava eine etwas drastische Methode.",
			"Denk dran, deine Stiefelsohlen sind in dieser Engine-Version nicht feuerfest.",
			"Ich liebe den Geruch von Kohle am Morgen, aber lieber nicht von deinem Bein."
		],
		"zh": [
			"喂，你要烧起来了！",
			"暖和吗？还是我给你端杯茶配点心？",
			"医疗提示：把皮肤烤焦并不会提升你的属性。",
			"踩进熔岩：TripAdvisor 零星评价，不推荐。",
			"我闻到了顶级烧烤的味道……啊，等等，是你。",
			"如果你想做激光脱毛，熔岩这方法有点太激进了。",
			"提醒一下，在这个引擎版本里你的鞋底可不防火。",
			"我喜欢清晨的炭火味，但最好别是你的腿。"
		],
		"ja": [
			"おい、燃えてるぞ！",
			"いい湯加減か？それとも紅茶とお菓子でも持ってこようか？",
			"医療上の注意：こんがり焼けた肌はステータスを上げない。",
			"溶岩に着地：TripAdvisorで星ゼロ。おすすめしない。",
			"最高級バーベキューの匂いがする……あ、待って、君だ。",
			"レーザー脱毛がしたかったなら、溶岩はちょっと過激な方法だぞ。",
			"念のため、このエンジン版では君のブーツの底は耐火じゃないからな。",
			"朝の炭の匂いは好きだが、それが君の脚じゃないといいな。"
		]
	},

	"snow_step": {
		"es": [
			"Abrígate, que a los personajes con hipotermia les bajan los fotogramas por segundo.",
			"Si encuentras un pingüino pídele un autógrafo, seguro que tiene mejor lore que nosotros.",
			"El frío conserva las carnes, pero no abuses que la animación de congelado es ridícula.",
			"Patas frías, corazón caliente... o principio de congelación de grado dos.",
			"Si nos quedamos atrapados aquí, por favor no intentes usar mi brillo místico como estufa.",
			"Un paisaje nevado precioso. Lástima que tus dedos se estén poniendo morados."
		],
		"en": [
			"Bundle up; characters with hypothermia get lower frames per second.",
			"If you find a penguin, ask for an autograph; it surely has better lore than us.",
			"Cold preserves meat, but don't overdo it: the frozen animation is ridiculous.",
			"Cold feet, warm heart... or the onset of second-degree frostbite.",
			"If we get stuck here, please don't try to use my mystic glow as a heater.",
			"A gorgeous snowy landscape. Shame your fingers are turning purple."
		],
		"fr": [
			"Couvre-toi ; les personnages en hypothermie ont moins d'images par seconde.",
			"Si tu trouves un pingouin, demande un autographe : il a sûrement un meilleur lore que nous.",
			"Le froid conserve la viande, mais n'abuse pas : l'animation de gel est ridicule.",
			"Pieds froids, cœur chaud... ou début d'engelure au deuxième degré.",
			"Si on reste coincés ici, n'essaie surtout pas d'utiliser ma lueur mystique comme radiateur.",
			"Un magnifique paysage enneigé. Dommage que tes doigts virent au violet."
		],
		"it": [
			"Copriti; i personaggi in ipotermia hanno meno fotogrammi al secondo.",
			"Se trovi un pinguino chiedigli un autografo, di sicuro ha un lore migliore del nostro.",
			"Il freddo conserva la carne, ma non esagerare: l'animazione da congelato è ridicola.",
			"Piedi freddi, cuore caldo... o principio di congelamento di secondo grado.",
			"Se restiamo bloccati qui, ti prego, non usare il mio bagliore mistico come stufa.",
			"Un paesaggio innevato splendido. Peccato che le tue dita stiano diventando viola."
		],
		"de": [
			"Zieh dich warm an; Charaktere mit Unterkühlung haben weniger Bilder pro Sekunde.",
			"Wenn du einen Pinguin findest, bitte um ein Autogramm; er hat sicher mehr Lore als wir.",
			"Kälte konserviert Fleisch, aber übertreib's nicht: die Einfrier-Animation ist lächerlich.",
			"Kalte Füße, warmes Herz... oder der Beginn von Erfrierungen zweiten Grades.",
			"Falls wir hier feststecken, benutz bitte nicht mein magisches Leuchten als Heizung.",
			"Eine herrliche Schneelandschaft. Schade, dass deine Finger blau anlaufen."
		],
		"zh": [
			"穿暖点，失温的角色会掉帧。",
			"要是遇到企鹅记得要签名，它的背景故事说不定比我们还精彩。",
			"寒冷能保存肉类，但别太过分，那个冻结动画丑得很。",
			"脚冷心热……或者说是二度冻伤的前兆。",
			"如果我们困在这里，拜托别想着把我的神秘光芒当暖炉用。",
			"雪景美极了。可惜你的手指都冻紫了。"
		],
		"ja": [
			"厚着しろよ、低体温症のキャラはフレームレートが落ちるんだ。",
			"ペンギンに会ったらサインをもらえ、きっと俺たちより設定が濃いぞ。",
			"寒さは肉を保存するが、やりすぎるな。凍結アニメがひどいからな。",
			"足は冷たく心は温かく……いや、それは第二度の凍傷の始まりだ。",
			"ここで立ち往生しても、俺の神秘の輝きを暖房に使おうとするなよ。",
			"見事な雪景色だ。惜しいのは君の指が紫になってることだな。"
		]
	},

	"ice_slip": {
		"es": [
			"¡Upa! Ese resbalón ha sido digno de unos dibujos animados de sábado por la mañana.",
			"Diez sobre diez en estilo acrobático involuntario.",
			"La física de fricción cero nunca defrauda. ¡A patinar se ha dicho!",
			"Si te rompes la crisma, avisa; yo no tengo manos para ponerte una venda."
		],
		"en": [
			"Whoops! That slip was worthy of a Saturday-morning cartoon.",
			"Ten out of ten for involuntary acrobatic style.",
			"Zero-friction physics never disappoints. Time to skate!",
			"If you crack your skull, let me know; I have no hands to bandage you."
		],
		"fr": [
			"Oups ! Cette glissade était digne d'un dessin animé du samedi matin.",
			"Dix sur dix pour le style acrobatique involontaire.",
			"La physique sans friction ne déçoit jamais. En piste pour le patinage !",
			"Si tu te fends le crâne, préviens-moi ; je n'ai pas de mains pour te bander."
		],
		"it": [
			"Ops! Quella scivolata era degna di un cartone del sabato mattina.",
			"Dieci su dieci per lo stile acrobatico involontario.",
			"La fisica ad attrito zero non delude mai. Si pattina!",
			"Se ti spacchi la testa, avvisami; non ho mani per fasciarti."
		],
		"de": [
			"Hoppla! Dieser Ausrutscher war eines Samstagmorgen-Cartoons würdig.",
			"Zehn von zehn für unfreiwilligen Akrobatik-Stil.",
			"Reibungslose Physik enttäuscht nie. Auf zum Schlittern!",
			"Wenn du dir den Schädel spaltest, sag Bescheid; ich habe keine Hände zum Verbinden."
		],
		"zh": [
			"哎哟！这一滑简直够格上周六早间动画片了。",
			"这不由自主的杂技风格，满分十分。",
			"零摩擦物理从不让人失望。开滑吧！",
			"要是把脑袋摔破了记得说一声，我可没手给你包扎。"
		],
		"ja": [
			"おっと！今の転び方は土曜朝のアニメ級だな。",
			"不本意なアクロバットのスタイルに十点満点。",
			"摩擦ゼロの物理はいつも期待を裏切らない。さあ滑ろう！",
			"頭を割ったら教えてくれ。俺には包帯を巻く手がないんだ。"
		]
	},

	"desert_step": {
		"es": [
			"La arena se mete en sitios donde ni un orbe sin cuerpo querría tener arena.",
			"Veo un oasis glorioso con palmeras y fuentes... espera, es un fallo de compresión de textura.",
			"Si te da una insolación, avísame, que yo solo sé emitir destellos y sarcasmo.",
			"¿Sabías que el noventa por ciento de las dunas esconden escorpiones y el otro diez trampas de guion?",
			"Tengo más polvo encima que la estantería de un mago ermitaño retirado."
		],
		"en": [
			"Sand gets into places where even a bodiless orb wouldn't want sand.",
			"I see a glorious oasis with palm trees and fountains... wait, it's a texture compression glitch.",
			"If you get heatstroke, let me know; all I can do is emit sparkles and sarcasm.",
			"Did you know ninety percent of dunes hide scorpions and the other ten hide plot traps?",
			"I've got more dust on me than the shelf of a retired hermit wizard."
		],
		"fr": [
			"Le sable se glisse dans des endroits où même un orbe sans corps n'en voudrait pas.",
			"Je vois un oasis glorieux avec des palmiers et des fontaines... non, c'est un bug de compression de texture.",
			"Si tu as une insolation, préviens-moi ; je ne sais qu'émettre des étincelles et du sarcasme.",
			"Savais-tu que quatre-vingt-dix pour cent des dunes cachent des scorpions et les dix autres des pièges de scénario ?",
			"J'ai plus de poussière sur moi que l'étagère d'un mage ermite à la retraite."
		],
		"it": [
			"La sabbia si infila in posti dove nemmeno un orbe senza corpo la vorrebbe.",
			"Vedo una gloriosa oasi con palme e fontane... aspetta, è un glitch di compressione delle texture.",
			"Se ti viene un'insolazione, avvisami; io so solo emettere scintille e sarcasmo.",
			"Lo sapevi che il novanta per cento delle dune nasconde scorpioni e l'altro dieci trappole di trama?",
			"Ho più polvere addosso io dello scaffale di un mago eremita in pensione."
		],
		"de": [
			"Sand kommt an Stellen, an denen selbst ein körperloser Orb keinen Sand haben wollte.",
			"Ich sehe eine herrliche Oase mit Palmen und Brunnen... moment, das ist ein Textur-Kompressionsfehler.",
			"Wenn du einen Hitzschlag bekommst, sag Bescheid; ich kann nur Funken und Sarkasmus versprühen.",
			"Wusstest du, dass neunzig Prozent der Dünen Skorpione verstecken und die anderen zehn Plot-Fallen?",
			"Ich habe mehr Staub auf mir als das Regal eines pensionierten Einsiedler-Magiers."
		],
		"zh": [
			"沙子会钻进连没有身体的宝珠都不想让它进的地方。",
			"我看到一片壮丽的绿洲，有棕榈树和喷泉……等等，那是贴图压缩的错误。",
			"你要是中暑了记得告诉我，我只会放光和吐槽。",
			"你知道吗，九成的沙丘藏着蝎子，另外一成藏着剧情陷阱。",
			"我身上的灰比一位退休隐士法师的书架还多。"
		],
		"ja": [
			"砂は、体のない宝珠でさえ入ってほしくない場所にまで入り込む。",
			"ヤシの木と噴水のある見事なオアシスが見える……待て、テクスチャ圧縮のバグだ。",
			"熱中症になったら教えてくれ。俺にできるのは光ることと皮肉だけだ。",
			"砂丘の九割はサソリを、残り一割はシナリオの罠を隠してるって知ってたか？",
			"引退した隠者魔法使いの本棚より、俺のほうがホコリまみれだ。"
		]
	},

	"water_step": {
		"es": [
			"Mojarse los calcetines debería acarrear penalización de moral inmediata.",
			"Esa agua tiene un color sospechoso. No preguntes qué flotaba ahí antes de que llegáramos.",
			"Si ves una sirena, no te emociones: con nuestro presupuesto seguro que muerde.",
			"Chapoteando con dignidad épica. Los peces nos están juzgando en silencio."
		],
		"en": [
			"Getting your socks wet should carry an immediate morale penalty.",
			"That water is a suspicious color. Don't ask what floated there before we arrived.",
			"If you see a mermaid, don't get excited: on our budget it definitely bites.",
			"Splashing along with epic dignity. The fish are judging us in silence."
		],
		"fr": [
			"Se mouiller les chaussettes devrait infliger une pénalité de moral immédiate.",
			"Cette eau a une couleur suspecte. Ne demande pas ce qui flottait là avant notre arrivée.",
			"Si tu vois une sirène, ne t'emballe pas : avec notre budget, elle mord, c'est sûr.",
			"On patauge avec une dignité épique. Les poissons nous jugent en silence."
		],
		"it": [
			"Bagnarsi i calzini dovrebbe comportare una penalità al morale immediata.",
			"Quell'acqua ha un colore sospetto. Non chiedere cosa galleggiava lì prima che arrivassimo.",
			"Se vedi una sirena, non emozionarti: col nostro budget di sicuro morde.",
			"Sguazziamo con dignità epica. I pesci ci stanno giudicando in silenzio."
		],
		"de": [
			"Nasse Socken sollten eine sofortige Moral-Strafe nach sich ziehen.",
			"Dieses Wasser hat eine verdächtige Farbe. Frag nicht, was da trieb, bevor wir kamen.",
			"Wenn du eine Meerjungfrau siehst, freu dich nicht zu früh: bei unserem Budget beißt die garantiert.",
			"Wir plantschen mit epischer Würde. Die Fische verurteilen uns schweigend."
		],
		"zh": [
			"把袜子弄湿了，应该立刻扣士气值。",
			"那水的颜色很可疑。别问我们来之前上面漂着什么。",
			"看到美人鱼别激动：以我们的预算，那玩意儿肯定会咬人。",
			"以史诗般的尊严涉水前行。鱼群正在默默地评判我们。"
		],
		"ja": [
			"靴下を濡らしたら即座に士気ペナルティを課すべきだ。",
			"あの水は怪しい色をしている。俺たちが来る前に何が浮いてたかは聞くな。",
			"人魚を見ても喜ぶな。うちの予算じゃ絶対に噛みついてくるぞ。",
			"叙事詩的な威厳をもって水しぶきを上げて進む。魚たちが黙って俺たちを見定めている。"
		]
	},

	"boat_sailing": {
		"es": [
			"¡Ah del barco! Mírate, capitaneando una chalupa con aires de galeón pirata.",
			"Si nos ataca un kraken gigante, yo me teletransporto y tú improvisas con los remos, ¿trato?",
			"El viento en las velas, el salitre en la cara... y tú sin saber usar una brújula náutica.",
			"Rumbo a lo desconocido... o al banco de arena más cercano que encontremos."
		],
		"en": [
			"Ahoy! Look at you, captaining a dinghy with the airs of a pirate galleon.",
			"If a giant kraken attacks, I teleport and you improvise with the oars, deal?",
			"Wind in the sails, salt on your face... and you can't even use a nautical compass.",
			"Bound for the unknown... or the nearest sandbank we can find."
		],
		"fr": [
			"Ohé du bateau ! Regarde-toi, capitaine d'une chaloupe avec des airs de galion pirate.",
			"Si un kraken géant nous attaque, je me téléporte et tu improvises avec les rames, marché conclu ?",
			"Le vent dans les voiles, le sel sur le visage... et toi incapable d'utiliser une boussole marine.",
			"Cap sur l'inconnu... ou sur le banc de sable le plus proche."
		],
		"it": [
			"Ehilà della barca! Guardati, al comando di una scialuppa con arie da galeone pirata.",
			"Se ci attacca un kraken gigante, io mi teletrasporto e tu improvvisi con i remi, affare fatto?",
			"Il vento nelle vele, il sale in faccia... e tu che non sai usare una bussola nautica.",
			"Rotta verso l'ignoto... o verso il banco di sabbia più vicino che troviamo."
		],
		"de": [
			"Ahoi! Sieh dich an, wie du eine Jolle mit dem Getue einer Piratengaleone kommandierst.",
			"Falls ein riesiger Krake angreift, teleportiere ich mich und du improvisierst mit den Rudern, abgemacht?",
			"Wind in den Segeln, Salz im Gesicht... und du kannst nicht mal einen Schiffskompass benutzen.",
			"Kurs auf das Unbekannte... oder auf die nächste Sandbank, die wir finden."
		],
		"zh": [
			"船上的！瞧瞧你，撑着一条小舢板却摆出海盗大帆船的架势。",
			"要是巨型海妖来袭，我瞬移走，你用桨随机应变，成交？",
			"风鼓满帆，咸味扑面……可你连航海罗盘都不会用。",
			"驶向未知……或者驶向我们能找到的最近的沙洲。"
		],
		"ja": [
			"おーい船よ！見ろよ、海賊のガレオン気取りで小舟を操ってるぞ。",
			"巨大なクラーケンが襲ってきたら、俺は瞬間移動、君はオールで即興。それで手を打つか？",
			"帆に風、顔に潮……なのに君は航海用コンパスも使えない。",
			"目指すは未知の彼方……いや、一番近くの砂州だな。"
		]
	},

	"straight_line": {
		"es": [
			"¡Wiii! ¡A la aventura a encontrar el One Piece!",
			"Si seguimos recto llegaremos al borde del mapa... literal.",
			"Parece que la tecla de avanzar se te ha quedado encasquillada con pegamento.",
			"Me fascina tu determinación geométrica. Rectilíneo, obstinado y sin frenos.",
			"Sabes que existe la diagonal, ¿verdad? Es un concepto fascinante que inventaron los matemáticos.",
			"Un kilómetro en línea recta. Los cartógrafos del reino van a llorar de pura emoción."
		],
		"en": [
			"Wheee! Off on an adventure to find the One Piece!",
			"If we keep going straight we'll reach the edge of the map... literally.",
			"Looks like your forward key got jammed with glue.",
			"I'm fascinated by your geometric determination. Straight, stubborn and brakeless.",
			"You know diagonals exist, right? A fascinating concept invented by mathematicians.",
			"A kilometer in a straight line. The kingdom's cartographers are going to weep with joy."
		],
		"fr": [
			"Wiii ! En avant l'aventure pour trouver le One Piece !",
			"Si on continue tout droit, on atteindra le bord de la carte... littéralement.",
			"On dirait que ta touche d'avance est restée collée.",
			"Ta détermination géométrique me fascine. Rectiligne, têtu et sans freins.",
			"Tu sais que la diagonale existe, non ? Un concept fascinant inventé par les mathématiciens.",
			"Un kilomètre en ligne droite. Les cartographes du royaume vont pleurer d'émotion."
		],
		"it": [
			"Wiii! All'avventura per trovare il One Piece!",
			"Se continuiamo dritti arriveremo al bordo della mappa... letteralmente.",
			"Sembra che il tasto avanti ti si sia incollato.",
			"Mi affascina la tua determinazione geometrica. Rettilineo, testardo e senza freni.",
			"Lo sai che esiste la diagonale, vero? Un concetto affascinante inventato dai matematici.",
			"Un chilometro in linea retta. I cartografi del regno piangeranno di commozione."
		],
		"de": [
			"Juhuu! Auf ins Abenteuer, das One Piece zu finden!",
			"Wenn wir geradeaus weitergehen, erreichen wir den Rand der Karte... buchstäblich.",
			"Sieht aus, als wäre deine Vorwärtstaste mit Klebstoff verklemmt.",
			"Deine geometrische Entschlossenheit fasziniert mich. Geradlinig, stur und ohne Bremse.",
			"Du weißt schon, dass es Diagonalen gibt, oder? Ein faszinierendes Konzept der Mathematiker.",
			"Einen Kilometer schnurgerade. Die Kartografen des Königreichs werden vor Rührung weinen."
		],
		"zh": [
			"呜哇！出发去寻找 One Piece 大冒险吧！",
			"再这么直走下去，我们真的会走到地图边缘……字面意义上的。",
			"看样子你的前进键被胶水粘住了。",
			"你这几何式的执着让我着迷。笔直、固执、还没刹车。",
			"你知道有斜线这回事吧？那可是数学家发明的迷人概念。",
			"直走了一公里。王国的制图师们要感动得哭了。"
		],
		"ja": [
			"うぇーい！ワンピースを探す冒険に出発だ！",
			"このまま真っすぐ進めば地図の端に着くぞ……文字どおりに。",
			"前進キーが接着剤で固まっちまったみたいだな。",
			"君の幾何学的な決意には感心するよ。真っすぐ、頑固、ブレーキなし。",
			"斜め移動があるのは知ってるよな？数学者が発明した実に魅力的な概念だ。",
			"直線で一キロ。王国の地図製作者が感動のあまり泣くぞ。"
		]
	},

	"lost_circles": {
		"es": [
			"Me encanta este baile, pero la misión principal está para el otro lado.",
			"¿Buscamos algo en el suelo o estamos haciendo tiempo para el almuerzo?",
			"Si pretendías abrir un portal trazando círculos, te está saliendo un donut bastante triste.",
			"Llevamos cuatro vueltas a la misma piedra. ¿Le has cogido cariño sentimental o algo?",
			"La brújula dice Norte, tu intuición dice 'mareo en tiovivo'.",
			"¿Nos hemos perdido con elegancia épica o nos hemos perdido de vergüenza ajena?"
		],
		"en": [
			"I love this dance, but the main quest is the other way.",
			"Are we looking for something on the ground or just killing time until lunch?",
			"If you meant to open a portal by drawing circles, you're getting a rather sad donut.",
			"That's four laps around the same rock. Have you grown sentimentally attached or something?",
			"The compass says North, your intuition says 'merry-go-round nausea'.",
			"Did we get lost with epic elegance or with secondhand embarrassment?"
		],
		"fr": [
			"J'adore cette danse, mais la quête principale est de l'autre côté.",
			"On cherche quelque chose par terre ou on tue le temps jusqu'au déjeuner ?",
			"Si tu voulais ouvrir un portail en traçant des cercles, tu obtiens plutôt un donut bien triste.",
			"Quatre tours autour du même rocher. Tu t'y es attaché sentimentalement ou quoi ?",
			"La boussole dit Nord, ton intuition dit 'nausée de manège'.",
			"On s'est perdus avec une élégance épique ou avec une honte par procuration ?"
		],
		"it": [
			"Adoro questo ballo, ma la missione principale è dall'altra parte.",
			"Stiamo cercando qualcosa per terra o ammazziamo il tempo fino a pranzo?",
			"Se volevi aprire un portale disegnando cerchi, ti sta venendo una ciambella piuttosto triste.",
			"Siamo al quarto giro attorno alla stessa roccia. Ci hai fatto un legame sentimentale o cosa?",
			"La bussola dice Nord, la tua intuizione dice 'nausea da giostra'.",
			"Ci siamo persi con eleganza epica o con imbarazzo per procura?"
		],
		"de": [
			"Ich liebe diesen Tanz, aber die Hauptquest ist in die andere Richtung.",
			"Suchen wir etwas am Boden oder schlagen wir nur die Zeit bis zum Mittagessen tot?",
			"Falls du ein Portal durch Kreise ziehen öffnen wolltest, wird das ein ziemlich trauriger Donut.",
			"Das ist die vierte Runde um denselben Felsen. Bist du sentimental daran gebunden?",
			"Der Kompass sagt Norden, deine Intuition sagt 'Karussell-Übelkeit'.",
			"Haben wir uns mit epischer Eleganz verlaufen oder mit Fremdscham?"
		],
		"zh": [
			"我很喜欢这支舞，可主线任务在另一边。",
			"我们是在地上找东西，还是在磨时间等午饭？",
			"如果你想靠画圈开传送门，那你画出来的是个相当可悲的甜甜圈。",
			"我们绕同一块石头四圈了。你是对它产生感情了还是怎么的？",
			"罗盘说往北走，你的直觉说'旋转木马眩晕'。",
			"我们是以史诗般的优雅迷路的，还是尴尬到让人替你脸红地迷路的？"
		],
		"ja": [
			"このダンスは好きだが、メインクエストは反対方向だぞ。",
			"地面で何か探してるのか、それとも昼飯までの時間つぶしか？",
			"円を描いてポータルを開くつもりなら、かなり悲しいドーナツができてるぞ。",
			"同じ岩の周りをもう四周だ。情が移ったのか何なんだ？",
			"コンパスは北と言い、君の直感はメリーゴーラウンド酔いと言ってる。",
			"叙事詩的な優雅さで迷ったのか、それとも見てるこっちが恥ずかしくなる感じで迷ったのか？"
		]
	},

	"hit_wall": {
		"es": [
			"¡Ouch! El muro sigue siendo sólido. Gracias por comprobarlo con la frente.",
			"A menos que desbloquees la habilidad secreta de atravesar polígonos, sugiero rodear.",
			"Esa montaña lleva ahí tres eras geológicas. Dudo que se mueva porque la mires fijamente."
		],
		"en": [
			"Ouch! The wall is still solid. Thanks for checking with your forehead.",
			"Unless you unlock the secret skill of phasing through polygons, I suggest going around.",
			"That mountain has been there for three geological eras. I doubt it'll move because you stare at it."
		],
		"fr": [
			"Aïe ! Le mur est toujours solide. Merci de l'avoir vérifié avec ton front.",
			"À moins de débloquer la compétence secrète de traverser les polygones, je suggère de contourner.",
			"Cette montagne est là depuis trois ères géologiques. Elle ne bougera pas parce que tu la fixes."
		],
		"it": [
			"Ahi! Il muro è ancora solido. Grazie per averlo verificato con la fronte.",
			"A meno che tu non sblocchi l'abilità segreta di attraversare i poligoni, suggerisco di aggirarlo.",
			"Quella montagna è lì da tre ere geologiche. Dubito si sposti solo perché la fissi."
		],
		"de": [
			"Autsch! Die Wand ist immer noch fest. Danke, dass du es mit der Stirn geprüft hast.",
			"Solange du nicht die Geheimfähigkeit freischaltest, durch Polygone zu gehen, empfehle ich herumzugehen.",
			"Dieser Berg steht seit drei Erdzeitaltern hier. Er bewegt sich kaum, weil du ihn anstarrst."
		],
		"zh": [
			"哎哟！墙还是那么硬。谢谢你用额头帮忙确认。",
			"除非你解锁了穿墙这项秘技，否则我建议绕道。",
			"那座山在这儿待了三个地质纪元了。你盯着它看它也不会动的。"
		],
		"ja": [
			"いてっ！壁はまだ固いままだ。おでこで確認してくれてありがとう。",
			"ポリゴンをすり抜ける秘密のスキルを解放しない限り、迂回をおすすめする。",
			"あの山は三つの地質時代からそこにある。にらんだところで動きゃしないぞ。"
		]
	},

	"stone_block_first": {
		"es": [
			"Esa grieta en la piedra... parece que con una bomba la volarías en pedazos."
		],
		"en": [
			"That crack in the rock... looks like a bomb would blow it to pieces."
		],
		"fr": [
			"Cette fissure dans la roche... on dirait qu'une bombe la ferait voler en éclats."
		],
		"it": [
			"Quella crepa nella roccia... sembra che una bomba la farebbe a pezzi."
		],
		"de": [
			"Dieser Riss im Fels... sieht aus, als würde eine Bombe ihn in Stücke sprengen."
		],
		"zh": [
			"石头上那道裂缝……看样子一颗炸弹就能把它炸个粉碎。"
		],
		"ja": [
			"あの岩のひび割れ……爆弾があれば粉々に吹き飛ばせそうだな。"
		]
	},

	"stone_block_repeat": {
		"es": [
			"¿No te dije lo de las bombas? Porque sigues mirando la piedra con cara de póker.",
			"La telequinesis no está implementada en este parche. Necesitas explosivos, criatura.",
			"Mirar la roca fijamente durante diez minutos solo te va a provocar jaqueca."
		],
		"en": [
			"Didn't I mention the bombs? Because you're still staring at the rock with a poker face.",
			"Telekinesis isn't implemented in this patch. You need explosives, creature.",
			"Staring at the rock for ten minutes will only give you a headache."
		],
		"fr": [
			"Je ne t'ai pas parlé des bombes ? Parce que tu fixes toujours le rocher, impassible.",
			"La télékinésie n'est pas implémentée dans ce patch. Il te faut des explosifs, créature.",
			"Fixer le rocher pendant dix minutes ne te donnera qu'une migraine."
		],
		"it": [
			"Non ti avevo parlato delle bombe? Perché continui a fissare la roccia con la faccia da poker.",
			"La telecinesi non è implementata in questa patch. Ti servono esplosivi, creatura.",
			"Fissare la roccia per dieci minuti ti darà solo mal di testa."
		],
		"de": [
			"Hab ich nicht die Bomben erwähnt? Du starrst den Fels immer noch mit Pokerface an.",
			"Telekinese ist in diesem Patch nicht implementiert. Du brauchst Sprengstoff, Kreatur.",
			"Den Fels zehn Minuten anzustarren, bringt dir nur Kopfschmerzen."
		],
		"zh": [
			"我没跟你说过炸弹的事吗？你还在面无表情地盯着那块石头。",
			"这个补丁里没实现念力。你需要炸药，小家伙。",
			"盯着石头看十分钟只会让你头疼。"
		],
		"ja": [
			"爆弾の話はしなかったか？まだポーカーフェイスで岩を見つめてるぞ。",
			"このパッチにテレキネシスは実装されてない。爆薬がいるんだよ、相棒。",
			"岩を十分間見つめても頭痛になるだけだぞ。"
		]
	},

	"low_health": {
		"es": [
			"Yo que tú me comería un bocata antes de palmarla.",
			"Tu barra de vida está pidiendo la hora al árbitro.",
			"Tu esperanza de vida ahora mismo es inferior a la batería de un móvil del año 2005.",
			"A un soplo de viento de ver los créditos finales. ¡Tómate una poción ya!",
			"La Parca te está mandando toques al móvil. Haz el favor de curarte."
		],
		"en": [
			"If I were you, I'd eat a sandwich before kicking the bucket.",
			"Your health bar is begging the referee for extra time.",
			"Your life expectancy right now is lower than a 2005 phone's battery.",
			"One gust of wind away from seeing the end credits. Drink a potion already!",
			"The Grim Reaper is buzzing your phone. Do me a favor and heal up."
		],
		"fr": [
			"À ta place, je mangerais un sandwich avant de casser ta pipe.",
			"Ta barre de vie demande une prolongation à l'arbitre.",
			"Ton espérance de vie est en ce moment inférieure à la batterie d'un téléphone de 2005.",
			"À un souffle de vent de voir le générique de fin. Bois une potion, enfin !",
			"La Faucheuse te fait vibrer le téléphone. Fais-moi plaisir et soigne-toi."
		],
		"it": [
			"Se fossi in te mangerei un panino prima di tirare le cuoia.",
			"La tua barra della vita sta chiedendo i supplementari all'arbitro.",
			"La tua aspettativa di vita ora è inferiore alla batteria di un cellulare del 2005.",
			"A un soffio di vento dai titoli di coda. Bevi una pozione, subito!",
			"La Morte ti sta squillando il telefono. Fammi il favore, curati."
		],
		"de": [
			"An deiner Stelle würde ich ein Sandwich essen, bevor du ins Gras beißt.",
			"Deine Lebensleiste bettelt beim Schiedsrichter um Nachspielzeit.",
			"Deine Lebenserwartung ist gerade geringer als der Akku eines Handys von 2005.",
			"Einen Windhauch vom Abspann entfernt. Trink endlich einen Trank!",
			"Der Sensenmann klingelt bei dir durch. Tu mir den Gefallen und heil dich."
		],
		"zh": [
			"我要是你，蹬腿之前先吃个三明治。",
			"你的血条正在向裁判申请加时。",
			"你现在的预期寿命比 2005 年的手机电池还短。",
			"离看片尾字幕就差一阵风了。快喝药水啊！",
			"死神都在给你手机发消息了。行行好，赶紧回血吧。"
		],
		"ja": [
			"俺が君なら、くたばる前にサンドイッチでも食うね。",
			"君の体力ゲージが審判にロスタイムを要求してるぞ。",
			"今の君の余命は2005年の携帯のバッテリーより短い。",
			"エンドロールまであと一吹きの風だ。さっさとポーションを飲め！",
			"死神が君の携帯に着信を入れてる。頼むから回復してくれ。"
		]
	},

	"idle_afk": {
		"es": [
			"¿Nos hemos dormido o estás consultando la guía secreta en Reddit?",
			"Avísame cuando volvamos a jugar, voy a aprovechar para ordenar mis partículas místicas.",
			"Llevas quince segundos inmóvil. Voy a empezar a cobrarte alquiler por flotar a tu lado.",
			"Si estás esperando a que crezca la hierba, te informo de que el shader no da para tanto.",
			"¿Se te ha caído el mando al suelo o estás sufriendo una crisis existencial repentina?",
			"Bostezo celestial en tres... dos... uno..."
		],
		"en": [
			"Did we fall asleep or are you checking the secret guide on Reddit?",
			"Let me know when we're playing again; I'll tidy up my mystic particles meanwhile.",
			"You've been still for fifteen seconds. I'll start charging you rent for floating beside you.",
			"If you're waiting for the grass to grow, I'll inform you the shader can't handle that.",
			"Did you drop the controller or are you having a sudden existential crisis?",
			"Celestial yawn in three... two... one..."
		],
		"fr": [
			"On s'est endormis ou tu consultes le guide secret sur Reddit ?",
			"Préviens-moi quand on rejoue ; j'en profite pour ranger mes particules mystiques.",
			"Tu es immobile depuis quinze secondes. Je vais te facturer un loyer pour flotter à côté de toi.",
			"Si tu attends que l'herbe pousse, sache que le shader n'en est pas capable.",
			"Tu as fait tomber la manette ou tu traverses une crise existentielle soudaine ?",
			"Bâillement céleste dans trois... deux... un..."
		],
		"it": [
			"Ci siamo addormentati o stai consultando la guida segreta su Reddit?",
			"Avvisami quando riprendiamo a giocare; intanto riordino le mie particelle mistiche.",
			"Sei fermo da quindici secondi. Inizierò a farti pagare l'affitto per fluttuarti accanto.",
			"Se aspetti che cresca l'erba, ti informo che lo shader non arriva a tanto.",
			"Ti è caduto il controller o hai una crisi esistenziale improvvisa?",
			"Sbadiglio celeste tra tre... due... uno..."
		],
		"de": [
			"Sind wir eingeschlafen oder checkst du den Geheimguide auf Reddit?",
			"Sag Bescheid, wenn wir weiterspielen; ich sortiere derweil meine mystischen Partikel.",
			"Du stehst seit fünfzehn Sekunden still. Ich verlange bald Miete fürs Neben-dir-Schweben.",
			"Falls du wartest, dass das Gras wächst: der Shader schafft das nicht.",
			"Ist dir der Controller runtergefallen oder hast du eine plötzliche Sinnkrise?",
			"Himmlisches Gähnen in drei... zwei... eins..."
		],
		"zh": [
			"我们是睡着了，还是你在 Reddit 上查秘密攻略？",
			"我们再开玩的时候叫我一声，我趁机整理一下我的神秘粒子。",
			"你已经一动不动十五秒了。我要开始收你'漂在你旁边'的租金了。",
			"如果你在等草长出来，我告诉你，这着色器可撑不住。",
			"你是手柄掉地上了，还是突然陷入了存在主义危机？",
			"天界哈欠倒数三……二……一……"
		],
		"ja": [
			"眠っちゃったのか、それともRedditで隠し攻略でも見てるのか？",
			"また遊ぶときは教えてくれ。その間に神秘の粒子を整理しておくよ。",
			"十五秒も動いてないぞ。隣で浮いてる家賃を請求し始めるからな。",
			"草が生えるのを待ってるなら言っておくが、このシェーダーじゃ無理だ。",
			"コントローラーを落としたのか、それとも突然の実存的危機か？",
			"天界のあくび、三……二……一……"
		]
	},

	"level_up": {
		"es": [
			"¡Subida de nivel! Ahora eres un tres por ciento más letal y un cien por cien más engreído.",
			"Esas lucecitas doradas nunca pasan de moda. ¡A gastar puntos antes de que caduquen!",
			"Más estadísticas para fallar menos... o para fallar con muchísimo más estilo."
		],
		"en": [
			"Level up! Now you're three percent more lethal and a hundred percent more smug.",
			"Those golden sparkles never go out of style. Spend your points before they expire!",
			"More stats to miss less... or to miss with a whole lot more style."
		],
		"fr": [
			"Niveau supérieur ! Te voilà trois pour cent plus létal et cent pour cent plus prétentieux.",
			"Ces petites lumières dorées ne se démodent jamais. Dépense tes points avant qu'ils n'expirent !",
			"Plus de stats pour rater moins... ou pour rater avec beaucoup plus de style."
		],
		"it": [
			"Salita di livello! Ora sei il tre per cento più letale e il cento per cento più presuntuoso.",
			"Quelle lucine dorate non passano mai di moda. Spendi i punti prima che scadano!",
			"Più statistiche per sbagliare meno... o per sbagliare con molto più stile."
		],
		"de": [
			"Stufenaufstieg! Jetzt bist du drei Prozent tödlicher und hundert Prozent selbstgefälliger.",
			"Diese goldenen Lichtlein kommen nie aus der Mode. Gib deine Punkte aus, bevor sie verfallen!",
			"Mehr Werte, um weniger zu verfehlen... oder um mit viel mehr Stil zu verfehlen."
		],
		"zh": [
			"升级了！现在你的杀伤力提升了百分之三，自负程度提升了百分之百。",
			"那些金色的小光点永不过时。趁点数还没过期赶紧花掉！",
			"更多属性让你少失手……或者让你失手得更有型。"
		],
		"ja": [
			"レベルアップ！これで君は三パーセント致命的に、百パーセント得意げになった。",
			"あの金色の光はいつまでも色あせない。期限が切れる前にポイントを使え！",
			"ミスを減らすためのステータス……いや、もっとかっこよくミスするためのな。"
		]
	},

	"inventory_full": {
		"es": [
			"Tienes los bolsillos más apretados que el equipaje de mano en un vuelo low-cost.",
			"Eres un auténtico síndrome de Diógenes medieval. Tira algo al suelo de una vez.",
			"Si recoges una rama más, la física newtoniana del juego va a colapsar."
		],
		"en": [
			"Your pockets are tighter than carry-on luggage on a budget flight.",
			"You're a genuine medieval hoarder. Drop something on the ground already.",
			"If you pick up one more twig, the game's Newtonian physics will collapse."
		],
		"fr": [
			"Tes poches sont plus serrées qu'un bagage cabine sur un vol low-cost.",
			"Tu es un véritable syndrome de Diogène médiéval. Lâche quelque chose par terre, enfin.",
			"Si tu ramasses une branche de plus, la physique newtonienne du jeu va s'effondrer."
		],
		"it": [
			"Hai le tasche più strette del bagaglio a mano su un volo low-cost.",
			"Sei un vero accumulatore seriale medievale. Butta qualcosa a terra, dai.",
			"Se raccogli un altro rametto, la fisica newtoniana del gioco collasserà."
		],
		"de": [
			"Deine Taschen sind voller als Handgepäck auf einem Billigflug.",
			"Du bist ein echter mittelalterlicher Messie. Lass endlich was fallen.",
			"Wenn du noch einen Zweig aufhebst, kollabiert die newtonsche Physik des Spiels."
		],
		"zh": [
			"你的口袋比廉价航班的手提行李还挤。",
			"你就是个不折不扣的中世纪囤积症患者。快扔点东西在地上吧。",
			"你再捡一根树枝，游戏的牛顿物理就要崩溃了。"
		],
		"ja": [
			"君のポケットはLCCの機内持ち込み荷物よりぎゅうぎゅうだ。",
			"君はまさに中世のゴミ屋敷症候群だ。いい加減、何か地面に捨てろ。",
			"あと一本でも小枝を拾ったら、このゲームのニュートン力学が崩壊するぞ。"
		]
	},

	"gold_rich": {
		"es": [
			"Tanto oro en la bolsa y todavía no me has comprado una funda de terciopelo mágica.",
			"Sonamos como una máquina tragaperras cada vez que damos un paso. ¡Qué elegancia señorial!"
		],
		"en": [
			"So much gold in the bag and you still haven't bought me a magic velvet case.",
			"We jingle like a slot machine with every step we take. Such lordly elegance!"
		],
		"fr": [
			"Autant d'or dans la bourse et tu ne m'as toujours pas acheté un écrin de velours magique.",
			"On tinte comme une machine à sous à chaque pas. Quelle élégance seigneuriale !"
		],
		"it": [
			"Tutto quest'oro nella borsa e non mi hai ancora comprato una custodia di velluto magica.",
			"Tintinniamo come una slot machine a ogni passo. Che eleganza signorile!"
		],
		"de": [
			"So viel Gold im Beutel und du hast mir immer noch kein magisches Samtetui gekauft.",
			"Wir klimpern bei jedem Schritt wie ein Spielautomat. Welch herrschaftliche Eleganz!"
		],
		"zh": [
			"钱袋里这么多金子，你还没给我买个魔法天鹅绒盒子呢。",
			"我们每走一步都叮当作响，像老虎机一样。真是贵族般的优雅！"
		],
		"ja": [
			"袋にこんなに金があるのに、まだ俺に魔法のベルベットケースを買ってくれないのか。",
			"一歩歩くたびにスロットマシンみたいにチャリチャリ鳴る。なんとも貴族的な優雅さだ！"
		]
	},

	"combat_win_1hp": {
		"es": [
			"Calculado al milímetro... por favor dime que fue calculado.",
			"He visto saltos de fe al vacío con más garantías que tu último turno de combate.",
			"Mi medidor de taquicardia mágica casi explota. ¡Qué potra descomunal has tenido!"
		],
		"en": [
			"Calculated down to the millimeter... please tell me it was calculated.",
			"I've seen leaps of faith into the void with better odds than your last combat turn.",
			"My magic tachycardia meter almost exploded. What monstrous luck you had!"
		],
		"fr": [
			"Calculé au millimètre près... dis-moi que c'était calculé, s'il te plaît.",
			"J'ai vu des sauts de la foi dans le vide plus sûrs que ton dernier tour de combat.",
			"Mon compteur de tachycardie magique a failli exploser. Quelle chance monstrueuse !"
		],
		"it": [
			"Calcolato al millimetro... ti prego, dimmi che era calcolato.",
			"Ho visto salti nel vuoto con più garanzie del tuo ultimo turno di combattimento.",
			"Il mio misuratore di tachicardia magica è quasi esploso. Che culo spropositato hai avuto!"
		],
		"de": [
			"Auf den Millimeter berechnet... bitte sag mir, dass es berechnet war.",
			"Ich habe Sprünge ins Leere mit besseren Chancen gesehen als deinen letzten Kampfzug.",
			"Mein magischer Herzrasen-Messer wäre fast explodiert. Was für ein monströses Glück!"
		],
		"zh": [
			"精确到毫米……拜托告诉我这是算好的。",
			"我见过纵身跳进虚空的信仰之跃，成功率都比你上个战斗回合高。",
			"我的魔法心动过速仪差点爆表。你这运气也太逆天了！"
		],
		"ja": [
			"ミリ単位で計算済み……頼むから計算通りだったと言ってくれ。",
			"君の直前の戦闘ターンより成功率の高い、虚空への信仰の跳躍を見たことがあるぞ。",
			"俺の魔法性頻脈メーターが爆発しかけた。とんでもない強運だったな！"
		]
	},

	"combat_win_low_hp": {
		"es": [
			"Eso ha estado tan cerca que sentí un escalofrío ectoplásmico recorriéndome el núcleo.",
			"Sobrevivir de puro milagro también cuenta como victoria en el currículum del héroe.",
			"Recomiendo sentarse un ratito, respirar hondo y no mirar el estado de la ropa interior."
		],
		"en": [
			"That was so close I felt an ectoplasmic shiver run through my core.",
			"Surviving by sheer miracle also counts as a victory on a hero's résumé.",
			"I recommend sitting for a bit, breathing deep, and not checking the state of your underwear."
		],
		"fr": [
			"C'était tellement juste que j'ai senti un frisson ectoplasmique parcourir mon noyau.",
			"Survivre par pur miracle compte aussi comme une victoire sur le CV d'un héros.",
			"Je recommande de s'asseoir un peu, de respirer profondément et de ne pas vérifier l'état de tes sous-vêtements."
		],
		"it": [
			"È stato così vicino che ho sentito un brivido ectoplasmatico attraversarmi il nucleo.",
			"Sopravvivere per puro miracolo conta comunque come vittoria nel curriculum di un eroe.",
			"Consiglio di sedersi un attimo, respirare a fondo e non controllare lo stato della biancheria."
		],
		"de": [
			"Das war so knapp, dass mir ein ektoplasmatischer Schauer durch den Kern lief.",
			"Durch reines Wunder zu überleben zählt auf dem Lebenslauf eines Helden auch als Sieg.",
			"Ich empfehle, sich kurz zu setzen, tief durchzuatmen und nicht den Zustand deiner Unterwäsche zu prüfen."
		],
		"zh": [
			"刚才太惊险了，我核心里窜过一阵灵质般的寒颤。",
			"纯靠奇迹活下来，在英雄的简历上也算一场胜利。",
			"我建议先坐一会儿，深呼吸，别去看你内裤现在的状况。"
		],
		"ja": [
			"今のはあまりに際どくて、俺の核をエクトプラズムの寒気が駆け抜けたぞ。",
			"まぐれで生き延びるのも、英雄の経歴書では立派な勝利に数える。",
			"少し座って深呼吸して、下着の状態は確認しないことをおすすめする。"
		]
	},

	"combat_flawless": {
		"es": [
			"¿Ni un rasguño? El desarrollador va a nerfearte en el próximo parche como sigas así.",
			"Limpio, quirúrgico y casi profesional. Empiezo a respetarte un poquito.",
			"Parece que hoy has desayunado reflejos de gato cósmico superdotado."
		],
		"en": [
			"Not a scratch? The developer's going to nerf you next patch if you keep this up.",
			"Clean, surgical and almost professional. I'm starting to respect you a little.",
			"Looks like you had the reflexes of a gifted cosmic cat for breakfast."
		],
		"fr": [
			"Pas une égratignure ? Le développeur va te nerfer au prochain patch si tu continues.",
			"Propre, chirurgical et presque professionnel. Je commence à te respecter un peu.",
			"On dirait que tu as déjeuné de réflexes de chat cosmique surdoué."
		],
		"it": [
			"Nemmeno un graffio? Lo sviluppatore ti nerferà nella prossima patch se continui così.",
			"Pulito, chirurgico e quasi professionale. Comincio a rispettarti un pochino.",
			"Sembra che oggi tu abbia fatto colazione con riflessi da gatto cosmico superdotato."
		],
		"de": [
			"Kein Kratzer? Der Entwickler wird dich im nächsten Patch nerfen, wenn das so weitergeht.",
			"Sauber, chirurgisch und fast professionell. Ich fange an, dich ein bisschen zu respektieren.",
			"Sieht aus, als hättest du die Reflexe einer hochbegabten kosmischen Katze gefrühstückt."
		],
		"zh": [
			"毫发无伤？你再这么下去，开发者下个补丁就要削弱你了。",
			"干净、精准，近乎专业。我开始有点儿佩服你了。",
			"看样子你今天早餐吃的是天赋异禀的宇宙猫的反应速度。"
		],
		"ja": [
			"かすり傷ひとつない？このままだと開発者に次のパッチで弱体化されるぞ。",
			"クリーンで外科的、ほぼプロの仕事だ。少しだけ君を見直し始めたよ。",
			"今日は天才的な宇宙猫の反射神経を朝食に食べたみたいだな。"
		]
	},

	"combat_win_generic": {
		"es": [
			"Otro monstruo que muerde el polvo. Buen trabajo de coreografía bélica.",
			"Una victoria limpia. Recoge el botín antes de que desaparezca por el recolector de basura.",
			"Si todos los combates fueran así, casi pareceríamos competentes."
		],
		"en": [
			"Another monster bites the dust. Nice work on the combat choreography.",
			"A clean win. Grab the loot before the garbage collector sweeps it away.",
			"If every fight went like this, we'd almost look competent."
		],
		"fr": [
			"Encore un monstre qui mord la poussière. Belle chorégraphie de combat.",
			"Une victoire propre. Ramasse le butin avant que le ramasse-miettes ne l'emporte.",
			"Si tous les combats étaient comme ça, on aurait presque l'air compétents."
		],
		"it": [
			"Un altro mostro morde la polvere. Bel lavoro di coreografia bellica.",
			"Una vittoria pulita. Prendi il bottino prima che sparisca col netturbino della spazzatura.",
			"Se tutti i combattimenti fossero così, sembreremmo quasi competenti."
		],
		"de": [
			"Noch ein Monster beißt ins Gras. Gute Arbeit bei der Kampfchoreografie.",
			"Ein sauberer Sieg. Schnapp dir die Beute, bevor der Müllsammler sie wegräumt.",
			"Wenn jeder Kampf so liefe, würden wir fast kompetent aussehen."
		],
		"zh": [
			"又一只怪物倒下了。这场战斗编排得不错。",
			"漂亮的胜利。趁垃圾回收器把战利品清走之前赶紧捡起来。",
			"要是每场战斗都这样，我们看起来简直算得上称职了。"
		],
		"ja": [
			"また一体、モンスターが土を噛んだ。戦闘の振り付け、いい仕事だ。",
			"クリーンな勝利だ。ガベージコレクタに回収される前に戦利品を拾え。",
			"どの戦いもこうなら、俺たちほとんど有能に見えるのにな。"
		]
	},

	"combat_fled": {
		"es": [
			"La retirada estratégica: el nombre digno de salir por patas a toda velocidad.",
			"No es cobardía, es optimización táctica de recursos vitales... ejem.",
			"¡Pies, para qué os quiero! ¡Digno de un velocista olímpico con armadura!"
		],
		"en": [
			"Strategic retreat: the dignified name for bolting away at full speed.",
			"It's not cowardice, it's tactical optimization of vital resources... ahem.",
			"Feet, don't fail me now! Worthy of an Olympic sprinter in armor!"
		],
		"fr": [
			"Retraite stratégique : le nom digne de détaler à toute vitesse.",
			"Ce n'est pas de la lâcheté, c'est de l'optimisation tactique des ressources vitales... hum.",
			"Jambes, à quoi bon vous ? Digne d'un sprinteur olympique en armure !"
		],
		"it": [
			"Ritirata strategica: il nome dignitoso per scappare a gambe levate.",
			"Non è codardia, è ottimizzazione tattica delle risorse vitali... ehm.",
			"Gambe, a cosa servite! Degno di uno sprinter olimpico in armatura!"
		],
		"de": [
			"Strategischer Rückzug: der würdevolle Name fürs Davonrennen mit Vollgas.",
			"Das ist keine Feigheit, das ist taktische Optimierung lebenswichtiger Ressourcen... ähem.",
			"Beine, enttäuscht mich jetzt nicht! Eines olympischen Sprinters in Rüstung würdig!"
		],
		"zh": [
			"战略性撤退：拔腿狂奔的体面叫法。",
			"这不是懦弱，这是对生命资源的战术性优化……咳咳。",
			"腿啊，就指望你了！简直够格当穿盔甲的奥运短跑选手！"
		],
		"ja": [
			"戦略的撤退：全速力で逃げ出すことの上品な呼び名だ。",
			"臆病じゃない、生命リソースの戦術的最適化だ……ゴホン。",
			"足よ、今こそ頼む！鎧を着たオリンピック短距離選手級だ！"
		]
	},

	"player_defeat": {
		"es": [
			"Bueno... siempre puedes decir en Twitter que la pantalla táctil tenía lag.",
			"Una siesta táctica en el suelo frío. Levantémonos antes de que alguien lo grabe en vídeo."
		],
		"en": [
			"Well... you can always say on Twitter that the touchscreen had lag.",
			"A tactical nap on the cold ground. Let's get up before someone films it."
		],
		"fr": [
			"Bon... tu peux toujours dire sur Twitter que l'écran tactile avait du lag.",
			"Une sieste tactique sur le sol froid. Relevons-nous avant que quelqu'un ne filme."
		],
		"it": [
			"Beh... puoi sempre dire su Twitter che il touchscreen aveva lag.",
			"Un pisolino tattico sul pavimento freddo. Rialziamoci prima che qualcuno lo filmi."
		],
		"de": [
			"Naja... du kannst auf Twitter immer noch behaupten, der Touchscreen hätte gelaggt.",
			"Ein taktisches Nickerchen auf dem kalten Boden. Stehen wir auf, bevor es jemand filmt."
		],
		"zh": [
			"好吧……你总能在推特上说是触摸屏有延迟。",
			"在冰冷的地上来个战术小憩。趁没人拍视频之前赶紧起来吧。"
		],
		"ja": [
			"まあ……タッチスクリーンがラグってたってツイッターで言えばいいさ。",
			"冷たい地面での戦術的仮眠だ。誰かに動画を撮られる前に起きよう。"
		]
	},

	"chest_opened": {
		"es": [
			"¡Cofre! A ver qué chatarra histórica acumulamos para no usar en toda la aventura.",
			"Por un milisegundo pensé que le salían dientes y lengua. Menos mal, odio a los mímicos.",
			"Dime que son pociones útiles y no otro coleccionable decorativo, por favor.",
			"El botín de los valientes... o lo que alguien se dejó olvidado en el siglo pasado."
		],
		"en": [
			"Chest! Let's see what historic junk we hoard and never use the whole adventure.",
			"For a millisecond I thought it grew teeth and a tongue. Phew, I hate mimics.",
			"Please tell me these are useful potions and not another decorative collectible.",
			"The loot of the brave... or what someone left behind last century."
		],
		"fr": [
			"Un coffre ! Voyons quelle ferraille historique on accumule sans jamais l'utiliser.",
			"Pendant une milliseconde j'ai cru qu'il avait des dents et une langue. Ouf, je déteste les mimics.",
			"Dis-moi que ce sont des potions utiles et pas un énième objet décoratif, s'il te plaît.",
			"Le butin des braves... ou ce que quelqu'un a oublié le siècle dernier."
		],
		"it": [
			"Un baule! Vediamo che ferraglia storica accumuliamo per non usarla mai.",
			"Per un millisecondo ho pensato gli spuntassero denti e lingua. Meno male, odio i mimic.",
			"Dimmi che sono pozioni utili e non l'ennesimo oggetto decorativo, ti prego.",
			"Il bottino dei coraggiosi... o quello che qualcuno ha dimenticato il secolo scorso."
		],
		"de": [
			"Eine Truhe! Mal sehen, welchen historischen Schrott wir horten und nie benutzen.",
			"Für eine Millisekunde dachte ich, ihr wüchsen Zähne und Zunge. Puh, ich hasse Mimics.",
			"Bitte sag, das sind nützliche Tränke und nicht noch ein dekoratives Sammelobjekt.",
			"Die Beute der Tapferen... oder was jemand letztes Jahrhundert liegen ließ."
		],
		"zh": [
			"宝箱！来看看我们又囤了什么整趟冒险都用不上的历史垃圾。",
			"有那么一毫秒我以为它长出了牙和舌头。还好，我讨厌宝箱怪。",
			"拜托告诉我这些是有用的药水，而不是又一个装饰性收藏品。",
			"勇者的战利品……又或者是某人上个世纪落下的东西。"
		],
		"ja": [
			"宝箱だ！今回の冒険で一度も使わない歴史的ガラクタを、また何を溜め込むのか見てみよう。",
			"一瞬、歯と舌が生えたかと思った。よかった、俺はミミックが嫌いなんだ。",
			"頼むから、これが役立つポーションで、またしても飾り用コレクションじゃないと言ってくれ。",
			"勇者の戦利品……いや、誰かが前世紀に置き忘れた物か。"
		]
	},

	"poi_discovered": {
		"es": [
			"Huele a personaje secundario con un trauma infantil que tendremos que resolver gratis.",
			"Un nuevo punto de interés. Prepárate para que te pidan recolectar diez champiñones.",
			"Civilización a la vista. Intenta comportarte como una persona educada y no rompas las vasijas."
		],
		"en": [
			"Smells like a side character with childhood trauma we'll have to fix for free.",
			"A new point of interest. Get ready to be asked to gather ten mushrooms.",
			"Civilization in sight. Try to behave like a polite person and don't smash the pots."
		],
		"fr": [
			"Ça sent le personnage secondaire avec un traumatisme d'enfance qu'on devra régler gratis.",
			"Un nouveau point d'intérêt. Prépare-toi à ce qu'on te demande de récolter dix champignons.",
			"Civilisation en vue. Essaie de te comporter poliment et ne casse pas les jarres."
		],
		"it": [
			"Puzza di personaggio secondario con un trauma infantile che dovremo risolvere gratis.",
			"Un nuovo punto d'interesse. Preparati a farti chiedere di raccogliere dieci funghi.",
			"Civiltà in vista. Cerca di comportarti da persona educata e non rompere i vasi."
		],
		"de": [
			"Riecht nach einer Nebenfigur mit Kindheitstrauma, das wir gratis lösen müssen.",
			"Ein neuer Interessenpunkt. Mach dich bereit, zehn Pilze sammeln zu sollen.",
			"Zivilisation in Sicht. Versuch, dich höflich zu benehmen, und zerschlag nicht die Töpfe."
		],
		"zh": [
			"闻起来像是个有童年创伤、还得我们免费帮忙解决的配角。",
			"一个新的兴趣点。准备好被要求去采集十个蘑菇吧。",
			"看到文明了。尽量表现得像个有教养的人，别打碎那些坛子。"
		],
		"ja": [
			"無償で解決させられる幼少期のトラウマ持ちのサブキャラの匂いがするな。",
			"新しい関心地点だ。キノコを十個集めてこいと頼まれる覚悟をしておけ。",
			"文明が見えてきた。礼儀正しい人間らしく振る舞って、壺を割るなよ。"
		]
	},

	"camp_fire_rest": {
		"es": [
			"Ah, la hoguera... el único sitio donde los bichos del bosque no intentan descuartizarnos.",
			"El olor a asado me recuerda que no tengo estómago ni boca. Qué tristeza cuántica.",
			"Descansa los huesos, que mañana nos aguarda otra ración generosa de peligros absurdos."
		],
		"en": [
			"Ah, the campfire... the one place where the forest critters aren't trying to dismember us.",
			"The smell of roasting reminds me I have neither stomach nor mouth. Such quantum sadness.",
			"Rest your bones; tomorrow another generous helping of absurd dangers awaits us."
		],
		"fr": [
			"Ah, le feu de camp... le seul endroit où les bestioles de la forêt n'essaient pas de nous démembrer.",
			"L'odeur du rôti me rappelle que je n'ai ni estomac ni bouche. Quelle tristesse quantique.",
			"Repose tes os ; demain nous attend une autre généreuse portion de dangers absurdes."
		],
		"it": [
			"Ah, il falò... l'unico posto dove le bestie del bosco non cercano di farci a pezzi.",
			"L'odore di arrosto mi ricorda che non ho né stomaco né bocca. Che tristezza quantistica.",
			"Riposa le ossa; domani ci aspetta un'altra generosa porzione di pericoli assurdi."
		],
		"de": [
			"Ah, das Lagerfeuer... der einzige Ort, an dem die Waldviecher nicht versuchen, uns zu zerlegen.",
			"Der Bratengeruch erinnert mich, dass ich weder Magen noch Mund habe. Welch quantenhafte Traurigkeit.",
			"Ruh deine Knochen aus; morgen erwartet uns eine weitere großzügige Portion absurder Gefahren."
		],
		"zh": [
			"啊，篝火……唯一一个森林里的小怪不想把我们大卸八块的地方。",
			"烤肉的香味提醒我，我既没有胃也没有嘴。真是量子级的悲伤。",
			"歇歇筋骨吧，明天还有慷慨的一大份荒唐危险在等着我们。"
		],
		"ja": [
			"ああ、焚き火だ……森の生き物が俺たちをバラバラにしようとしてこない唯一の場所だ。",
			"焼ける匂いで、俺には胃も口もないことを思い出す。なんとも量子的な悲しさだ。",
			"骨を休めておけ。明日はまた不条理な危険がたっぷり一皿、待ち受けてるからな。"
		]
	},

	"camp_forge": {
		"es": [
			"Hierro al rojo, martillo y sudor. Espero que el herrero no le doble la hoja a tu arma.",
			"Más filo a la espada significa menos discusiones dialécticas con los monstruos."
		],
		"en": [
			"Red-hot iron, hammer and sweat. I hope the smith doesn't bend your weapon's blade.",
			"A sharper sword means fewer dialectical debates with the monsters."
		],
		"fr": [
			"Fer rougi, marteau et sueur. J'espère que le forgeron ne va pas tordre la lame de ton arme.",
			"Une épée plus tranchante, ce sont moins de débats dialectiques avec les monstres."
		],
		"it": [
			"Ferro rovente, martello e sudore. Spero che il fabbro non pieghi la lama della tua arma.",
			"Una spada più affilata significa meno dibattiti dialettici con i mostri."
		],
		"de": [
			"Glühendes Eisen, Hammer und Schweiß. Hoffentlich verbiegt der Schmied die Klinge nicht.",
			"Ein schärferes Schwert bedeutet weniger dialektische Debatten mit den Monstern."
		],
		"zh": [
			"烧红的铁、锤子和汗水。但愿铁匠别把你武器的刃给打弯了。",
			"剑更锋利，就意味着和怪物的辩证辩论更少。"
		],
		"ja": [
			"真っ赤な鉄、ハンマー、そして汗。鍛冶屋が君の武器の刃を曲げないといいな。",
			"剣が鋭くなれば、モンスターとの弁証法的な議論が減るってことだ。"
		]
	},

	"class_change": {
		"es": [
			"¿Otra profesión distinta? La indecisión vocacional hecha héroe legendario.",
			"Nuevo uniforme, nuevos hechizos, pero los mismos despistes de siempre al caminar."
		],
		"en": [
			"Another different profession? Vocational indecision made into a legendary hero.",
			"New uniform, new spells, but the same old absent-mindedness when walking."
		],
		"fr": [
			"Encore une profession différente ? L'indécision professionnelle faite héros légendaire.",
			"Nouvel uniforme, nouveaux sorts, mais les mêmes vieux moments d'inattention en marchant."
		],
		"it": [
			"Un'altra professione diversa? L'indecisione vocazionale fatta eroe leggendario.",
			"Nuova uniforme, nuovi incantesimi, ma le solite distrazioni di sempre quando cammini."
		],
		"de": [
			"Noch ein anderer Beruf? Berufliche Unentschlossenheit als legendärer Held.",
			"Neue Uniform, neue Zauber, aber die gleiche alte Zerstreutheit beim Gehen."
		],
		"zh": [
			"又换一个职业？把职业选择困难症活成了传奇英雄。",
			"新制服、新法术，可走路时还是老样子那么心不在焉。"
		],
		"ja": [
			"またも別の職業か？キャリアの優柔不断を伝説の英雄にまで昇華させたな。",
			"新しい制服、新しい呪文、でも歩くときのうっかりはいつもどおりだ。"
		]
	},

	"main_quest_advance": {
		"es": [
			"¡Impresionante! Hemos cerrado la brecha del Santuario. Ahora el camino al Norte está abierto.",
			"Un paso de gigante hacia el destino de Celestia. Y lo mejor de todo: mi cristal sigue impoluto.",
			"Hito desbloqueado con honores. Hasta la banda sonora se ha emocionado un poco."
		],
		"en": [
			"Impressive! We've sealed the Sanctuary breach. Now the path North is open.",
			"A giant leap toward Celestia's destiny. And best of all: my crystal is still spotless.",
			"Milestone unlocked with honors. Even the soundtrack got a little emotional."
		],
		"fr": [
			"Impressionnant ! Nous avons refermé la brèche du Sanctuaire. La route du Nord est ouverte.",
			"Un pas de géant vers le destin de Celestia. Et le meilleur : mon cristal reste immaculé.",
			"Jalon débloqué avec les honneurs. Même la bande-son s'est un peu émue."
		],
		"it": [
			"Impressionante! Abbiamo chiuso la breccia del Santuario. Ora la via a Nord è aperta.",
			"Un balzo da gigante verso il destino di Celestia. E la cosa migliore: il mio cristallo è ancora immacolato.",
			"Traguardo sbloccato con onore. Persino la colonna sonora si è un po' commossa."
		],
		"de": [
			"Beeindruckend! Wir haben den Riss des Heiligtums geschlossen. Der Weg nach Norden ist offen.",
			"Ein Riesensprung zu Celestias Schicksal. Und das Beste: mein Kristall ist noch makellos.",
			"Meilenstein mit Auszeichnung freigeschaltet. Sogar der Soundtrack wurde ein wenig gerührt."
		],
		"zh": [
			"了不起！我们封闭了圣所的裂隙。现在通往北方的道路打开了。",
			"向着塞莱斯蒂亚的命运迈出了一大步。最棒的是：我的水晶依旧一尘不染。",
			"荣耀地解锁了里程碑。连配乐都有点动情了。"
		],
		"ja": [
			"見事だ！聖域の裂け目を塞いだぞ。これで北への道が開けた。",
			"セレスティアの運命へ向けた大きな一歩だ。そして何より、俺の水晶はまだ無傷ときてる。",
			"栄誉あるマイルストーン解放だ。サントラまで少し感極まってるぞ。"
		]
	},

	"quest_blocked": {
		"es": [
			"Detente un momento. Para avanzar por aquí necesitas primero el artefacto clave requerido.",
			"Esa puerta no se abrirá con buenos deseos ni a cabezazos. Busca primero la llave correspondiente."
		],
		"en": [
			"Hold on a moment. To proceed here you first need the required key artifact.",
			"That door won't open with good wishes or headbutts. Find the matching key first."
		],
		"fr": [
			"Attends un instant. Pour avancer ici, il te faut d'abord l'artefact clé requis.",
			"Cette porte ne s'ouvrira pas avec de bons vœux ni des coups de tête. Trouve d'abord la clé correspondante."
		],
		"it": [
			"Fermati un momento. Per proseguire qui ti serve prima l'artefatto chiave richiesto.",
			"Quella porta non si aprirà con i buoni propositi né a testate. Trova prima la chiave corrispondente."
		],
		"de": [
			"Halt kurz inne. Um hier weiterzukommen, brauchst du zuerst das erforderliche Schlüsselartefakt.",
			"Diese Tür öffnet sich weder mit guten Wünschen noch mit Kopfstößen. Finde zuerst den passenden Schlüssel."
		],
		"zh": [
			"先等一下。要从这里继续前进，你得先拿到所需的关键神器。",
			"那扇门光靠美好愿望或用头撞是打不开的。先去找到对应的钥匙吧。"
		],
		"ja": [
			"ちょっと待て。ここを進むには、まず必要な鍵となるアーティファクトがいる。",
			"あの扉は良い願いや頭突きじゃ開かない。まずは対応する鍵を探せ。"
		]
	}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Inicializar mazos
	for key in DIALOGUE_POOLS.keys():
		_init_deck(key)
	# Al cambiar de idioma, los mazos cacheados contienen frases del idioma
	# anterior: se vacían para que se rebarajen en el nuevo idioma.
	if Locale != null and not Locale.locale_changed.is_connected(_on_locale_changed):
		Locale.locale_changed.connect(_on_locale_changed)


## Vacía los mazos al cambiar de idioma para que se rebarajen traducidos.
func _on_locale_changed() -> void:
	_decks.clear()


## Devuelve el array de frases del evento `event_id` en el idioma ACTIVO, con
## la jerarquía de fallback estándar (idioma actual -> en -> es -> cualquiera).
## Las frases de la esfera son data multi-idioma: `{event_id: {lang: [lines]}}`.
func _pool(event_id: String) -> Array:
	var entry = DIALOGUE_POOLS.get(event_id, null)
	if entry == null:
		return []
	# Compatibilidad: si alguna entrada quedara como Array plano, se usa tal cual.
	if entry is Array:
		return entry
	if entry is Dictionary:
		var lang := Locale.current if Locale != null else "es"
		for candidate in [lang, "en", "es"]:
			if entry.has(candidate) and entry[candidate] is Array and not (entry[candidate] as Array).is_empty():
				return entry[candidate]
		# Último recurso: el primer idioma no vacío disponible.
		for k in entry.keys():
			if entry[k] is Array and not (entry[k] as Array).is_empty():
				return entry[k]
	return []


func _process(delta: float) -> void:
	if _circle_detect_cooldown > 0.0:
		_circle_detect_cooldown -= delta
	if _poke_count > 0 and (Time.get_ticks_msec() / 1000.0) - _last_poke_time > 12.0:
		_poke_count = 0


## Obtiene la siguiente línea garantizando que no se repite ninguna hasta agotar
## el mazo. El pool se resuelve SIEMPRE en el idioma activo vía `_pool()`; el
## segundo parámetro (`_legacy`) se conserva solo por compatibilidad con las
## numerosas llamadas existentes `_get_next_line("x", DIALOGUE_POOLS["x"])` y se
## ignora (la entrada de `DIALOGUE_POOLS` es ahora un diccionario por idioma).
func _get_next_line(event_id: String, _legacy = null) -> String:
	var pool: Array = _pool(event_id)
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return String(pool[0])

	if not _decks.has(event_id) or _decks[event_id].is_empty():
		_init_deck(event_id)

	var deck: Array = _decks[event_id]
	if deck.is_empty():
		return String(pool.pick_random())

	return String(deck.pop_back())


func _init_deck(event_id: String) -> void:
	var pool: Array = _pool(event_id)
	if pool.is_empty():
		return
	var deck := pool.duplicate()
	deck.shuffle()
	_decks[event_id] = deck


## Disparo principal de diálogos contextuales con comprobación de cooldown y reglas
func trigger_bark(event_id: String, params: Dictionary = {}) -> void:
	if is_on_cooldown(event_id):
		return

	# Control de cortesía global (salvo para mensajes de historia LARGE)
	var now_sec := Time.get_ticks_msec() / 1000.0
	var is_large_event := (event_id == "main_quest_advance" or event_id == "quest_blocked")
	var is_priority_event := (
		is_large_event
		or event_id.begins_with("combat_")
		or event_id == "player_defeat"
		or event_id == "stone_block_interact"
		or event_id == "chest_opened"
	)
	if not is_priority_event and (now_sec - _last_any_bark_time) < MIN_GLOBAL_BARK_INTERVAL:
		return

	match event_id:
		"stone_block_interact":
			if not flags["seen_stone_block_first"]:
				flags["seen_stone_block_first"] = true
				play(_get_next_line("stone_block_first", DIALOGUE_POOLS["stone_block_first"]), Mode.SMALL)
				set_cooldown(event_id, 4.0)
			else:
				var has_bombs: bool = params.get("has_bombs", false)
				if not has_bombs and randf() <= 0.6:
					play(_get_next_line("stone_block_repeat", DIALOGUE_POOLS["stone_block_repeat"]), Mode.SMALL)
					set_cooldown(event_id, 8.0)

		"lava_step":
			play(_get_next_line("lava_step", DIALOGUE_POOLS["lava_step"]), Mode.SMALL)
			set_cooldown(event_id, 5.0)

		"snow_step":
			if randf() <= 0.45:
				play(_get_next_line("snow_step", DIALOGUE_POOLS["snow_step"]), Mode.SMALL)
				set_cooldown(event_id, 10.0)

		"ice_slip":
			play(_get_next_line("ice_slip", DIALOGUE_POOLS["ice_slip"]), Mode.SMALL)
			set_cooldown(event_id, 6.0)

		"desert_step":
			if randf() <= 0.35:
				play(_get_next_line("desert_step", DIALOGUE_POOLS["desert_step"]), Mode.SMALL)
				set_cooldown(event_id, 12.0)

		"water_step":
			if randf() <= 0.35:
				play(_get_next_line("water_step", DIALOGUE_POOLS["water_step"]), Mode.SMALL)
				set_cooldown(event_id, 10.0)

		"boat_sailing":
			if randf() <= 0.35:
				play(_get_next_line("boat_sailing", DIALOGUE_POOLS["boat_sailing"]), Mode.SMALL)
				set_cooldown(event_id, 14.0)

		"straight_line":
			if randf() <= 0.4:
				play(_get_next_line("straight_line", DIALOGUE_POOLS["straight_line"]), Mode.SMALL)
				set_cooldown(event_id, 12.0)

		"lost_circles":
			play(_get_next_line("lost_circles", DIALOGUE_POOLS["lost_circles"]), Mode.SMALL)
			set_cooldown(event_id, 16.0)

		"hit_wall":
			if randf() <= 0.5:
				play(_get_next_line("hit_wall", DIALOGUE_POOLS["hit_wall"]), Mode.SMALL)
				set_cooldown(event_id, 8.0)

		"low_health":
			play(_get_next_line("low_health", DIALOGUE_POOLS["low_health"]), Mode.SMALL)
			set_cooldown(event_id, 16.0)

		"idle_afk":
			play(_get_next_line("idle_afk", DIALOGUE_POOLS["idle_afk"]), Mode.SMALL)
			set_cooldown(event_id, 25.0)

		"level_up":
			play(_get_next_line("level_up", DIALOGUE_POOLS["level_up"]), Mode.SMALL)
			set_cooldown(event_id, 5.0)

		"inventory_full":
			play(_get_next_line("inventory_full", DIALOGUE_POOLS["inventory_full"]), Mode.SMALL)
			set_cooldown(event_id, 15.0)

		"gold_rich":
			play(_get_next_line("gold_rich", DIALOGUE_POOLS["gold_rich"]), Mode.SMALL)
			set_cooldown(event_id, 30.0)

		"combat_win_1hp":
			play(_get_next_line("combat_win_1hp", DIALOGUE_POOLS["combat_win_1hp"]), Mode.SMALL)
			set_cooldown(event_id, 5.0)

		"combat_win_low_hp":
			play(_get_next_line("combat_win_low_hp", DIALOGUE_POOLS["combat_win_low_hp"]), Mode.SMALL)
			set_cooldown(event_id, 8.0)

		"combat_flawless":
			play(_get_next_line("combat_flawless", DIALOGUE_POOLS["combat_flawless"]), Mode.SMALL)
			set_cooldown(event_id, 10.0)

		"combat_win_generic":
			if randf() <= 0.25:
				play(_get_next_line("combat_win_generic", DIALOGUE_POOLS["combat_win_generic"]), Mode.SMALL)
				set_cooldown(event_id, 12.0)

		"combat_fled":
			play(_get_next_line("combat_fled", DIALOGUE_POOLS["combat_fled"]), Mode.SMALL)
			set_cooldown(event_id, 6.0)

		"player_defeat":
			play(_get_next_line("player_defeat", DIALOGUE_POOLS["player_defeat"]), Mode.SMALL)
			set_cooldown(event_id, 10.0)

		"chest_opened":
			if randf() <= 0.65:
				play(_get_next_line("chest_opened", DIALOGUE_POOLS["chest_opened"]), Mode.SMALL)
				set_cooldown(event_id, 8.0)

		"poi_discovered":
			if randf() <= 0.7:
				play(_get_next_line("poi_discovered", DIALOGUE_POOLS["poi_discovered"]), Mode.SMALL)
				set_cooldown(event_id, 15.0)

		"camp_fire_rest":
			play(_get_next_line("camp_fire_rest", DIALOGUE_POOLS["camp_fire_rest"]), Mode.SMALL)
			set_cooldown(event_id, 20.0)

		"camp_forge":
			if randf() <= 0.5:
				play(_get_next_line("camp_forge", DIALOGUE_POOLS["camp_forge"]), Mode.SMALL)
				set_cooldown(event_id, 15.0)

		"class_change":
			play(_get_next_line("class_change", DIALOGUE_POOLS["class_change"]), Mode.SMALL)
			set_cooldown(event_id, 10.0)

		"main_quest_advance":
			var custom_text: String = String(params.get("text", ""))
			if custom_text == "":
				custom_text = _get_next_line("main_quest_advance", DIALOGUE_POOLS["main_quest_advance"])
			play(custom_text, Mode.LARGE)
			set_cooldown(event_id, 5.0)

		"quest_blocked":
			var req_text: String = String(params.get("text", ""))
			if req_text == "":
				req_text = _get_next_line("quest_blocked", DIALOGUE_POOLS["quest_blocked"])
			play(req_text, Mode.LARGE)
			set_cooldown(event_id, 5.0)

		_:
			# Clave personalizada o data-driven
			if DIALOGUE_POOLS.has(event_id):
				play(_get_next_line(event_id, DIALOGUE_POOLS[event_id]), Mode.SMALL)
				set_cooldown(event_id, 5.0)
			elif params.has("text"):
				play(String(params["text"]), Mode.SMALL)
				set_cooldown(event_id, 4.0)


## Emite la señal centralizada de reproducción
func play(text: String, mode: Mode) -> void:
	if text.strip_edges() == "":
		return
	_last_any_bark_time = Time.get_ticks_msec() / 1000.0
	var mode_str := "LARGE" if mode == Mode.LARGE else "SMALL"
	play_orb_bark.emit(text, mode_str)


## Configura un cooldown en segundos para una clave
func set_cooldown(event_id: String, duration: float) -> void:
	cooldowns[event_id] = Time.get_ticks_msec() + int(duration * 1000.0)


## Comprueba si un evento está actualmente bloqueado por enfriamiento
func is_on_cooldown(event_id: String) -> bool:
	if not cooldowns.has(event_id):
		return false
	return Time.get_ticks_msec() < cooldowns[event_id]


func _get_global_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("GlobalState"):
		return tree.root.get_node("GlobalState")
	return null


func _get_orb_barks_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("OrbBarksManager"):
		return tree.root.get_node("OrbBarksManager")
	return null


func _get_quest_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("QuestManager"):
		return tree.root.get_node("QuestManager")
	return null


## Notifica movimiento paso a paso desde el mapamundi para detectar patrones
func notify_step(cur_c: Vector2i, old_c: Vector2i, terrain: String) -> void:
	if cur_c == old_c:
		return

	# 1. Detección de línea recta prolongada (> 5 casillas)
	var step_dir := cur_c - old_c
	if step_dir == _last_step_dir:
		_straight_steps_count += 1
		if _straight_steps_count >= 5:
			_straight_steps_count = 0
			trigger_bark("straight_line")
	else:
		_last_step_dir = step_dir
		_straight_steps_count = 1

	# 2. Detección de pérdida / vueltas en círculo
	_recent_cells.push_back(cur_c)
	if _recent_cells.size() > 8:
		_recent_cells.pop_front()

	if _circle_detect_cooldown <= 0.0 and _recent_cells.size() >= 6:
		var visits: Dictionary = {}
		for cell in _recent_cells:
			visits[cell] = int(visits.get(cell, 0)) + 1
			if visits[cell] >= 3:
				_circle_detect_cooldown = 18.0
				trigger_bark("lost_circles")
				break

	# 3. Detección de terreno específico
	var gs := _get_global_state()
	match terrain:
		"lav", "lava":
			trigger_bark("lava_step")
		"snw", "ice", "icy":
			trigger_bark("snow_step")
		"snd", "des", "are":
			trigger_bark("desert_step")
		"sea", "wat":
			if gs != null and bool(gs.get("is_sailing")):
				trigger_bark("boat_sailing")
			else:
				trigger_bark("water_step")

	# 4. Salud crítica
	if gs != null:
		var raw_max = gs.get("max_hp")
		var raw_cur = gs.get("hp")
		var max_hp: int = int(raw_max) if raw_max != null else 0
		var cur_hp: int = int(raw_cur) if raw_cur != null else 0
		if max_hp > 0:
			var hp_ratio: float = float(cur_hp) / float(max_hp)
			if hp_ratio < 0.20:
				trigger_bark("low_health")


## Notifica inactividad del jugador
func notify_idle(idle_seconds: float) -> void:
	if idle_seconds >= 15.0:
		trigger_bark("idle_afk")


const POKE_RESPONSES: Dictionary = {
	1: {
		"es": "A tu servicio. Tu fiel esfera flotante siempre al pie del cañón.",
		"en": "At your service. Your loyal floating sphere, always on duty.",
		"fr": "À ton service. Ta fidèle sphère flottante, toujours sur le pont.",
		"it": "Al tuo servizio. La tua fedele sfera fluttuante, sempre in prima linea.",
		"de": "Zu deinen Diensten. Deine treue schwebende Sphäre, immer einsatzbereit.",
		"zh": "为你效劳。你忠诚的悬浮球随时待命。",
		"ja": "御用をお伺いします。忠実な浮遊球体はいつでもスタンバイしています。"
	},
	2: {
		"es": "¿Por qué me tocas? Te recuerdo que soy un orbe de sabiduría, no un botón antiestrés.",
		"en": "Why are you poking me? I'll have you know I'm an orb of wisdom, not a stress ball.",
		"fr": "Pourquoi tu me touches ? Je te rappelle que je suis un orbe de sagesse, pas une balle anti-stress.",
		"it": "Perché mi tocchi? Ti ricordo che sono un globo di saggezza, non un antistress.",
		"de": "Warum fasst du mich an? Ich erinnere dich daran: Ich bin eine Kugel der Weisheit, kein Stressball.",
		"zh": "你戳我干嘛？请记住我是智慧宝球，不是解压按键。",
		"ja": "なぜ突つくのですか？ 私は知恵の宝珠であり、ストレス解消ボタンではありません。"
	},
	3: {
		"es": "Si me manchas el cristal con los dedos te toca limpiarme a ti con un paño de gamuza.",
		"en": "If you smudge my crystal with your fingers, you're the one cleaning me with a microfiber cloth.",
		"fr": "Si tu salis mon cristal avec tes doigts, c'est toi qui me nettoies avec un chiffon doux.",
		"it": "Se mi ungi il cristallo con le dita tocca a te pulirmi con un panno di daino.",
		"de": "Wenn du mein Kristall mit den Fingern beschmierst, putzt du mich gefälligst mit einem Mikrofasertuch.",
		"zh": "要是用手指弄脏了我的水晶外壁，就得由你拿麂皮布擦干净。",
		"ja": "指で私の水晶を汚したら、セーム革の布で拭いてもらいますからね。"
	},
	4: {
		"es": "Oye, que tengo cosquillas místicas. Compórtate y concéntrate en la misión.",
		"en": "Hey, I have mystical tickles. Behave yourself and focus on the mission.",
		"fr": "Dis donc, j'ai des chatouilles mystiques. Tiens-toi bien et concentre-toi sur la mission.",
		"it": "Ehi, soffro di solletico mistico. Fai il bravo e concentrati sulla missione.",
		"de": "Hey, ich habe mystische Kitzligkeit. Benimm dich und konzentriere dich auf die Mission.",
		"zh": "喂，我有神秘搔痒症。规矩点，专心做任务。",
		"ja": "おい、私には神秘のくすぐったさがあるんです。行儀よく任務に集中してください。"
	},
	5: {
		"es": "Como me toques otra vez, le subo un veinte por ciento la vida al próximo boss del mapa.",
		"en": "Poke me one more time and I'll buff the next boss's HP by twenty percent.",
		"fr": "Touche-moi encore une fois, et j'augmente de vingt pour cent les PV du prochain boss.",
		"it": "Se mi tocchi un'altra volta, aumento del venti per cento la salute del prossimo boss.",
		"de": "Wenn du mich noch einmal anfasst, erhöhe ich die Boss-Lebenspunkte um zwanzig Prozent.",
		"zh": "你要是再碰我一下，我就给下一个首领增加百分之二十的生命值。",
		"ja": "もう一度触ったら、次のボスのHPを2割増しにしますよ。"
	}
}


func _pick_locale(val) -> String:
	if val is String:
		return val
	if val is Dictionary:
		if Locale != null:
			return Locale.pick(val)
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and tree.root.has_node("Locale"):
			return String(tree.root.get_node("Locale").call("pick", val))
		return String(val.get("es", val.get("en", "")))
	return ""


## Reacción inteligente e interactiva cuando el jugador pulsa la esfera directamente
func on_orb_clicked() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_last_poke_time = now
	_poke_count += 1

	match _poke_count:
		1, 2, 3, 4:
			play(_pick_locale(POKE_RESPONSES[_poke_count]), Mode.SMALL)
		5, 6, 7:
			play(_pick_locale(POKE_RESPONSES[5]), Mode.SMALL)
		_:
			# Tras insistir mucho, da el objetivo actual con tono exasperado
			_poke_count = 0
			var hint: String = ""
			var obm := _get_orb_barks_manager()
			var qm := _get_quest_manager()
			if obm != null and obm.has_method("get_small_hint"):
				hint = String(obm.call("get_small_hint"))
			elif qm != null and qm.has_method("get_active_quest"):
				var q: Dictionary = qm.call("get_active_quest")
				hint = _pick_locale(q.get("hint", {})) if q.has("hint") else ""
			if hint == "":
				hint = _pick_locale({
					"es": "Sigue explorando el valle hacia Celestia.",
					"en": "Keep exploring the valley towards Celestia.",
					"fr": "Continue d'explorer la vallée en direction de Célestia.",
					"it": "Continua a esplorare la valle verso Celestia.",
					"de": "Erkunde das Tal weiter in Richtung Celestia.",
					"zh": "继续探索山谷，前往塞莱斯蒂亚。",
					"ja": "セレスティアを目指して谷の探索を続けてください。"
				})
			var exasperated_msg := _pick_locale({
				"es": "Vale, veo que tu pasión es pulsar botones al azar. Aquí tienes tu objetivo: %s",
				"en": "Alright, I see your true passion is pressing buttons at random. Here's your objective: %s",
				"fr": "D'accord, je vois que ta passion est d'appuyer sur des boutons au hasard. Voici ton objectif : %s",
				"it": "D'accordo, vedo che la tua passione è premere tasti a caso. Ecco il tuo obiettivo: %s",
				"de": "Alles klar, deine Leidenschaft ist offenbar das wahllose Tastendrücken. Hier ist dein Ziel: %s",
				"zh": "好吧，看来你的爱好就是到处乱按。这是你的当前目标：%s",
				"ja": "はいはい、やたらとボタンを押すのがお好きなようですね。あなたの目標はこちらです：%s"
			})
			play(exasperated_msg % hint, Mode.SMALL)


## Reacción tras el desenlace de un combate
func on_combat_ended(victory: bool, fled: bool = false) -> void:
	if fled:
		trigger_bark("combat_fled")
		return

	if not victory:
		trigger_bark("player_defeat")
		return

	var gs := _get_global_state()
	if gs == null:
		trigger_bark("combat_win_generic")
		return

	var raw_cur = gs.get("hp")
	var raw_max = gs.get("max_hp")
	var cur_hp: int = int(raw_cur) if raw_cur != null else 0
	var max_hp: int = int(raw_max) if raw_max != null else 1

	if cur_hp == 1:
		trigger_bark("combat_win_1hp")
	elif float(cur_hp) / float(maxf(1.0, float(max_hp))) <= 0.20:
		trigger_bark("combat_win_low_hp")
	elif cur_hp >= max_hp:
		trigger_bark("combat_flawless")
	else:
		trigger_bark("combat_win_generic")

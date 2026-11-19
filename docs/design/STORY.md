---
Origen: docs/INDEX.md y especificación canónica del mundo.
Estado: VERSIÓN CANÓNICA DEFINITIVA — 5 Actos, 7 Zonas + Zona Extra, Niveles 50 / 30.
---

# STORY.md — Biblia Narrativa y Estructura de Historia

## 0. Premisa y la Verdad Oculta

El jugador vive, en apariencia, una aventura clásica de fantasía: despierta sin recuerdos en un valle desolado, ayuda a sus gentes, reabre una presa de agua, domina diversas profesiones y se enfrenta a criaturas cada vez más peligrosas. Sin embargo, este mundo de fantasía es un constructo mental onírico.

> **Revisión de canon (2026-09-08)**: versión definitiva basada en el libro *"La
> leyenda de las esferas"* narrado por el usuario. Sustituye a versiones previas en
> todos los puntos donde difieran.

### 0.0 Personajes de la Realidad

- **Aiden** — El protagonista. En la realidad es un brillante doctor/científico,
  investigador principal de un proyecto de **Arcanum** sobre unas esferas de energía
  halladas en un templo ancestral.
- **Roxas** — Amigo y colega investigador de Aiden. Juntos construyeron un barco y
  emprendieron la expedición que lo empezó todo; es quien **convence a Aiden de tocar
  las esferas**. Corresponsable de la tragedia (su firma está junto a la de Aiden en
  la orden de experimentación de Arcanum).
- **Elara** — Su hija pequeña (6 años). Toca una esfera y **enferma**; Aiden,
  desesperado por salvarla, le **inyecta** las propiedades de las esferas y la **mata**.
- **Elena** — Su esposa y madre de Elara. Incapaz de soportar la pérdida de la niña,
  **se suicida**.
- **Samy** — Una gran dragona. **Hunde el barco** de Aiden y Roxas en alta mar y, a
  cambio de devolverlos a su ciudad, les **obliga a robar un huevo de dragón** y
  llevarlo al templo de las esferas.
- **Los 6 Mentores** — En la fantasía son los maestros de las 6 profesiones; en la
  realidad son **compañeros de trabajo** del laboratorio de investigación de Aiden.

### 0.1 El Accidente y la Culpa (cadena canónica)

1. Aiden y su amigo **Roxas** construyen un barco y se hacen a la mar en una
   **expedición**.
2. En alta mar, la gran dragona **Samy** les **hunde el barco** y les **obliga** a
   **robar un huevo de dragón** y llevarlo al **templo de las esferas**, a cambio de
   ayudarles a regresar a su ciudad.
3. En el templo, **Roxas convence a Aiden de tocar las esferas**; al hacerlo
   **adquieren conocimientos secretos**.
4. Se llevan **4 de las 5 esferas** (las 4 pequeñas). La **5ª es enorme**: la
   **Esfera de la Verdad**, que un humano normal no puede tolerar al tocar.
5. De vuelta en **Arcanum**, investigan las 4 esferas en los laboratorios. La
   corporación **presiona a Aiden para experimentar con humanos** (memorándum:
   *"resultados o se cancela el proyecto"*, firmado por él y por Roxas).
6. En un **accidente** (Aiden distraído), Elara toca una esfera y **enferma**.
7. Aiden pierde la cabeza intentando salvarla: prueba las 4 esferas **en sí mismo**
   (sin éxito) y, desesperado, **inyecta las propiedades de las esferas en Elara**,
   lo que **provoca su muerte**.
8. Su esposa **Elena**, incapaz de soportar la pérdida, **se suicida**.
9. Aiden **culpa a Arcanum, a Roxas y a sí mismo**. Desesperado, va a por la **5ª
   esfera** (la de la Verdad) que quedó en el templo y, con enorme convicción, **la toca**.
10. **Todo lo que se juega es el efecto de tocar la Esfera de la Verdad**: un recorrido
    por su mente, traumas y recuerdos, atrapado en un **bucle mental** del que debe
    salir **decidiendo un camino**.

La **Esfera de la Verdad** es a la vez el ancla que encierra su mente y el único
artefacto capaz de hacerle afrontar lo sucedido. **Meta-nota**: todos los lugares del
juego son ciudades reales del continente, redistribuidas de otra forma.

### 0.2 Los 5 Impulsos Emocionales

Durante su travesía por los 5 actos, cinco fuerzas psicológicas luchan dentro de Aiden:

1. **Aceptación**: Asumir el duelo, perdonarse a sí mismo y despertar a la realidad con entereza.
2. **Locura**: Ceder a la pérdida de cordura y quedar atrapado para siempre en una fantasía rota.
3. **Negación**: Fingir que nada ocurrió y vivir en un bucle heroico eterno.
4. **Autodestrucción**: Dejarse consumir por el tormento y apagar su existencia.
5. **Venganza**: Culpar a Arcanium y al mundo entero por la presión destructiva que provocó la tragedia.

---

## 1. Estructura General de Actos y Zonas

| Acto | Zona | Nombre y Bioma | Nivel | Hito Narrativo y Jugable |
| :--- | :--- | :--- | :--- | :--- |
| **Prólogo** | **Zona 1** | **El Yelmo** (`bad`) | **1 – 5** | Despertar amnésico. Reapertura de la Presa del Agua. Salida por `dun_yelmo` (Boss Orco Berserker Lv 99). |
| **Acto 1** | **Zona 2** | **Hielo** (`ice`/`icy`) | **5 – 8** | Travesía por el laberinto helado resbaladizo (peligro de congelación). Salida por `dun_nieves` (Boss Eco Fragmentado Lv 7). |
| **Acto 1** | **Zona 3** | **Pradera** (`grs`/`gnd`) | **8 – 14** | Reino del agua y calma. Ciudad **Sylphrena** (`city_sylphrena`). Aprendizaje de las 3 primeras clases. Puente del Mono y `dun_bandidos` (Boss Lv 15). |
| **Acto 2** | **Zona 4** | **Celestia** (`grs`/templos) | **15 – 25** | Ciudadela de los sabios **Celestia** (`city_celestia`). Aprendizaje de las 3 clases avanzadas. Dominio de 6 clases y **Obtención del Barco**. |
| **Acto 3** | **Zona 5** | **Gloriam** (`sand`/`des`) | **25 – 35** | Navegación a ultramar. Gran desierto árido (peligro de insolación). Ciudad **Gloriam** (`city_gloriam`) y mazmorra `dun_desierto` (exige las 6 habilidades). |
| **Acto 4** | **Zona 6** | **Arcanum** (`bad`, arriba-izq) | **35 – 45** | La historia se vuelve **creepy**. Metrópolis tecnológica **Arcanum** (`city_arcanum`) y `dun_laboratorio`. Grietas de la realidad: Aiden sospecha de su culpa. |
| **Acto 5** | **Zona 7** | **Final** (`bad`/ruinas, abajo-izq) | **45 – 50** | Revelación total. Aiden lucha por no perder la cordura. Mazmorra final `dun_final` (Templo del Origen / Tribunal), **Guardián Supremo** (Lv 50) y juicio final. |
| **Opcional** | **Zona Extra** | **Zona Extra** (Isla marina) | **50** | Zona libre de alta dificultad para levear y conseguir cofres valiosos. |

---

## 2. Desarrollo Narrativo Detallado por Acto

### Prólogo: Zona 1. El Yelmo (Niveles 1 – 5)
- **Tema**: El despertar en el páramo marchito.
- **Narrativa**: El protagonista despierta sin identidad en `dun_inicial`. La Esfera emite un pulso que pone en marcha el mundo. Al explorar el páramo árido, colabora con los lugareños para restaurar la Presa del Agua. La reapertura de la presa simboliza el primer intento de la mente de Aiden por "hacer fluir la vida de nuevo".
- **Clímax del Prólogo**: El paso hacia el este está bloqueado por el Túnel de las Colinas (`dun_yelmo`). Aiden derrota al **Orco Berserker (Nivel 99)** para abrir la salida del valle.

### Acto 1: Zona 2. Hielo (Niveles 5 – 8) & Zona 3. Pradera (Niveles 8 – 14)
- **Zona 2 (Hielo)**: Travesía a través de un laberinto hostil de nieve y placas de hielo resbaladizo. El frío extremo amenaza con congelar al viajero si no busca calor en campamentos. Supera la Catacumba de las Nieves (`dun_nieves`, Boss Eco Fragmentado Nivel 7) para descender a las tierras bajas.
- **Zona 3 (Pradera - Sylphrena)**: Llegada al fértil Reino del Agua. La atmósfera transmite paz y serenidad.
  - **Ciudad Principal**: **Sylphrena** (`city_sylphrena`), bulliciosa capital comercial.
  - **Aprendizaje Inicial**: Encuentro con los 3 primeros maestros y superación de sus senderos (`Guerrero`, `Arquero`, `Sacerdote`).
  - **Puntos Clave**: Desbloqueo del puente mediante el acertijo del Mono y asalto a la Cueva de los Bandidos (`dun_bandidos`), derrotando al **Jefe Bandido (Nivel 15)** para despejar el paso hacia Celestia.

### Acto 2: Zona 4. Celestia (Niveles 15 – 25)
- **Tema**: La consagración del conocimiento y el acceso a los mares.
- **Narrativa**: Llegada a la gran meseta imperial de **Celestia** (`city_celestia`), sede de la corte y los grandes templos arcanos.
- **Senderos Avanzados**: Superación de los 3 senderos superiores (`Elementalista`, `Psíquico`, `Mago del Tiempo`).
- **El Gran Hito del Barco**: Al dominar las 6 profesiones, el Rey y el Maestro de Puerto otorgan el salvoconducto para abordar el **Barco** en el Puerto de Celestia (`poi_port_001`). El protagonista zarpa a mar abierto hacia continentes desconocidos.

### Acto 3: Zona 5. Gloriam (Niveles 25 – 35)
- **Tema**: La prueba del aislamiento y los peligros extremos.
- **Narrativa**: Navegación hacia el vasto continente desértico. El calor sofocante del desierto castiga a quien no esté preparado (peligro de insolación/sed).
- **Ciudad Oasis**: **Gloriam** (`city_gloriam`), civilización que sobrevive en medio de las dunas y las tormentas de arena.
- **Mazmorra del Desierto (`dun_desierto`)**: travesía de ruinas subterráneas que pone
  a prueba la exploración física. Sus inscripciones evocan **un barco, dos hombres y
  una promesa rota en alta mar** (eco de la expedición de Aiden y Roxas y del naufragio
  provocado por la dragona Samy). Su jefe, el **Devorador de Dunas**, custodia la
  **Reliquia del Núcleo Solar** (`reliquia_solar`), llave para calmar al Centinela de
  Frontera y abrir el paso a Arcanum.

### Acto 4: Zona 6. Arcanum (Niveles 35 – 45)
- **Tema**: La intrusión de la realidad y el giro "creepy".
- **Ubicación**: Meseta del páramo arcano (arriba a la izquierda del mapamundi).
- **Narrativa**: El mundo de fantasía empieza a quebrarse de forma visible y perturbadora:
  - **Ciudad de Arcanum** (`city_arcanum`): Una urbe extraña donde la arquitectura medieval se mezcla con maquinaria moderna, cables, terminales y autómatas de vigilancia.
  - **Laboratorio de Arcanum** (`dun_laboratorio`): Los muros de piedra dan paso a
    pasillos estériles de metal y cristal con instrumental ensangrentado y notas reales
    firmadas por Aiden. Al vencer a su jefe (el **Experimento de Arcanium**) se
    recuperan los 3 documentos de la tragedia (`informe_arcanum_04`, `dibujo_elara`,
    `registro_medico_elara`) y se desbloquean los **recuerdos de Aiden**
    (`recuerdos_aiden`): **la gran revelación**. Queda claro que **somos Aiden**, que
    **nuestra propia inyección mató a Elara** y precipitó **el suicidio de Elena**, y se
    instala el **odio a Arcanum**. Dispara la cinemática `arcanum_revelation`.
  - **Disonancia Cognitiva**: los NPCs sufren distorsiones (glitches), repiten frases
    entrecortadas y balbucean sobre "el accidente" y "la niña" (p. ej. **Nox**, el
    vagabundo). Aiden recuerda que no es un salvador, sino el causante de una catástrofe.

### Acto 5: Zona 7. Final (Niveles 45 – 50)
- **Tema**: La confrontación de la verdad y la batalla por la cordura.
- **Ubicación**: Abismo primordial del suroeste (abajo a la izquierda del mapamundi).
- **Narrativa**: Las máscaras de la fantasía caen por completo. Aiden recorre una tierra devastada por ecos de su propia mente fragmentada, luchando desesperadamente por mantener el control.
- **Mazmorra Final (`dun_final` - Templo del Origen / Tribunal)**:
  - Los enemigos son aberraciones y manifestaciones directas de la culpa, el pánico y el duelo.
  - **Batalla Final contra el Guardián Supremo (Nivel 50)**: No es un monstruo ajeno, sino la encarnación del trauma que custodia el núcleo de la Esfera.
  - **Juicio y Desenlace**: Tras la batalla, Aiden entabla el diálogo final ante la Esfera de la Verdad, donde sus decisiones y el estado de sus 5 Facetas determinan su destino.

---

## 3. Los Finales Múltiples

> **No hay "final verdadero".** Los 6 finales (A-F) se alcanzan según las **5 Facetas**
> del héroe (valor, bondad, aspecto, inteligencia, cordura); ninguno es el canónico
> (aunque el libro original culmina en el Final E — Venganza, en el juego no está
> privilegiado). Cada final se presenta como una **secuencia de 3 diapositivas**
> (imagen de fondo + texto) y revela un **fragmento único** del canon. Implementación:
> `data/scenes/epilogo_final.json` (ramificación en `branch_final`). Facetas que hoy
> deciden el final: **cordura, bondad, valor** (+ 6 profesiones para F); **aspecto** e
> **inteligencia** gobiernan contenido opcional, no el desenlace.

1. **Final A — Aceptación** (`cordura>=3 y bondad>=3`): Aiden asume la muerte de Elara y
   su responsabilidad, se perdona y **despierta en el hospital** (solo han pasado 11
   días); **Roxas, vivo**, ha velado a su lado. Fragmento único: la vigilia de Roxas.
2. **Final B — Locura** (`cordura<=-3`): la mente colapsa; entre el ruido oye a **Elena**
   cantar y el mundo se reinicia sin fin. Fragmento único: el bucle eterno ante la Esfera.
3. **Final C — Negación** (else): elige **no mirar** la verdad y vivir por siempre en la
   Sylphrena idealizada, donde una niña con la risa de Elara nunca envejece.
4. **Final D — Autodestrucción** (`bondad<=-3 y valor<=-3`): deposita las **4 esferas**
   robadas en el suelo del templo y deja que su mundo (su mente) se apague zona a zona.
5. **Final E — Venganza** (`bondad<=-3 y valor>=3`): recuerda la **orden de Arcanum** (y
   la firma de Roxas), arde la metrópolis en su mente y **lleva la Esfera a la vigilia**.
6. **Final F — Epílogo Oculto (Secreto)** (`cordura>=5 y bondad>=5` + las **6 profesiones**
   dominadas): un último recuerdo cálido de **Elara en el jardín** con su esfera de
   juguete y el dibujo *"para papá"*; Aiden despierta y abre una **clínica infantil**
   con su nombre. Cura en vez de destruir.

---

## 4. Don Nadie como Elemento Narrativo

"Don Nadie" representa la identidad honesta y vulnerable de Aiden antes de inventarse su máscara de héroe de fantasía. A medida que avanza la historia, sus habilidades aparentemente ridículas (suplicar, fingir la muerte, bailar) demuestran ser cruciales para superar amenazas específicas, simbolizando que la vulnerabilidad humana es más fuerte que el autoengaño bélico.

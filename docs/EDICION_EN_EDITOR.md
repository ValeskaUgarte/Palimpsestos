# Cómo mover y ajustar cosas desde el editor de Godot

Todo lo que se coloca a mano se hace en la vista 2D del editor, sin tocar código. Esta guía dice **qué nodo mover o qué propiedad
cambiar** para cada tipo de cosa, y qué calcula el juego solo al ejecutar.

## 1. Mover cosas de sitio

| Qué | Cómo moverlo |
|---|---|
| Personaje jugable (Elliot, Jhon, Thomas), enemigo, NPC, aldeano, animal | Selecciona el **nodo raíz** (el que aparece en la escena del nivel, ej. `NPC_Mama`, `Perro`, `Wolf1`) y arrástralo, o edita `Position` en el Inspector. |
| Zona de conversación de un NPC | Selecciona su `CollisionShape2D` (hijo del NPC) y muévelo o cambia su radio. Ya no hace falta que toque exactamente los pies del jugador: el juego deja un margen vertical (`interaction_vertical_slack` en el NPC, 320 px por defecto). |
| Carteles, objetos recogibles, disparadores de texto (`StoryTrigger`) | Mueve el nodo (es un `Area2D`) y su `CollisionShape2D`. Los disparadores también tienen `vertical_slack`. |
| Obstáculos de salto, vallas | Mueve el nodo raíz. |

**Si el nodo que quieres mover es hijo de una escena instanciada** (por ejemplo el `Motion` de un NPC dentro del nivel): clic
derecho sobre la instancia en el árbol de escena → **Hijos editables**. Sin eso solo puedes seleccionar la raíz.

### Posición de Elliot y de los aliados al empezar

En el **primer tramo de cada escena** el juego respeta exactamente donde pongas a Elliot, Jhon y Thomas en el editor: nada los recoloca.
Hay una casilla en el nodo raíz del nivel (`level.gd`):

* **`auto_place_party`** = desactivada (por defecto): manda el editor. Actívala si quieres que el juego recoloque siempre a Elliot al
  inicio del tramo y a los aliados junto a él.
* `snap_actors_to_path` = desactivada: NPC y enemigos tampoco se pegan al camino; se quedan donde los pongas.

Dos excepciones que no se pueden editar a mano, porque tu posición del editor no corresponde al sitio donde se entra:
tramos que empiezan **a mitad de la escena** (ej. "El rastro de las flores") y **llegadas desde otro tramo** al volver atrás.
Ahí el juego coloca a Elliot en la entrada y a los aliados detrás de él, sobre el camino. Los puntos de inicio de esos tramos
están en `GameSession.PARTS` (`start`).

Elliot siempre queda apoyado sobre la franja del camino (`WalkablePath`): puedes cambiar su X, pero su Y se ajusta al suelo.

## 2. Tamaño y apoyo en el suelo

El juego ajusta solo el tamaño y los pies de cada fotograma para que no "salten" entre animaciones. **El tamaño se cambia en el
propio recurso de animaciones (SpriteFrames)**, igual para jugables, NPC, enemigos, aldeanos y animales:

1. Selecciona el nodo de animación (`AnimatedSprite2D` en jugables, `Visual` en enemigos, `Motion` en NPC, `Sprite` en aldeanos).
2. En el Inspector, haz clic sobre el recurso **Sprite Frames** (es un `CharacterFrames`): se despliegan sus propiedades.
3. Cambia:
   * **`character_height`**: alto en pantalla (px) de la figura de pie. **Todas** las animaciones miden esto: el juego mide el
     cuadro más alto de cada animación y la escala sola (idle, caminar, golpe, bloqueo, muerte... del mismo tamaño).
   * **`animation_scale`**: retoque por animación, ej. `{"attack": 1.05}` si una animación se ve más chica. 1 = igual.
   * **`animation_offset`**: corrimiento fino por animación, ej. `{"death": Vector2(0, 8)}` para bajar los pies.
   * **`knockdown_frame`**: cuadro de `death` donde el personaje queda en el suelo al caer por un golpe fuerte (-1 = la mitad).

El panel **SpriteFrames** de abajo sigue funcionando igual para agregar o quitar cuadros. En los NPC y aldeanos el cambio se ve en
el editor; en jugables y enemigos se ve al ejecutar.

**Jugables (Elliot, Jhon, Thomas):** su SpriteFrames tiene `character_height = 0`, así que conservan su ajuste fino de siempre:
`clip_scale` en el nodo raíz (un valor por animación, incluidos `block` y `run`). Si algún día quieres pasarlos al sistema
parejo, basta con poner un `character_height` en su SpriteFrames.

Excepciones por instancia (un mismo personaje con otro tamaño solo en un lugar):

| Qué | Propiedad |
|---|---|
| Enemigo más grande que los de su especie (p. ej. el lobo gigante) | `size_multiplier` (también agranda su alcance y su radio de detección) y `health_multiplier` en el nodo raíz del enemigo. |
| NPC más chico o grande solo en una escena (p. ej. Stephy lejana entre las casas) | `standing_height` en su nodo **Motion** (0 = usa el del SpriteFrames). |

**Control total a mano:** en NPC (`Motion`) y en aldeanos/animales hay una casilla **`manual_placement`**. Márcala y el script
deja de tocar la posición y la escala de ese nodo, en el editor y en el juego: lo colocas y escalas tú.

## 3. Ver y elegir animaciones

1. Selecciona el nodo `Motion` (NPC) o `AnimatedSprite2D` / `Visual` / `Sprite` (personajes, enemigos, aldeanos).
2. Abajo se abre el panel **SpriteFrames**: a la izquierda están **todas** las animaciones (idle, walk, run, talk, hurt, death…).
   Las que aparecen vacías son ranuras sin dibujo todavía.
3. Haz clic en una animación y pulsa ▶ para verla. El script ya no la reinicia a *idle* en el editor.
4. Para añadir dibujos: arrastra imágenes o una hoja de sprites a esa animación.

Si una animación está vacía el juego usa la siguiente de la lista (ej. `run` → `walk` → `idle`), así que no se rompe nada.

## 4. Lo que el juego recalcula al ejecutar (no se edita a mano)

* Zonas de golpe y de daño de los enemigos (`Hurtbox`, `Hitbox`, `DetectionArea`) se ajustan al tamaño visible al cargar el nivel.
* Las posiciones de los acompañantes al empezar un tramo (junto a Elliot, sobre el camino).
* Los límites de cámara de cada tramo (`GameSession.PARTS`).

## 5. Dónde están las cosas

* Niveles: `scenes/levels/cuento1_escena1..4.tscn`.
* Personajes y NPC: `scenes/characters/{player,enemies,npc,pueblo}/`.
* Animaciones (SpriteFrames): `assets/characters`, `assets/enemies`, `assets/npc`.

# Modell-Credits

Dieses Repo ist öffentlich. Jede Datei unter `assets/models/` braucht deshalb einen
Eintrag mit belegter Herkunft und Lizenz — auch „Public Domain"/CC0 muss auf eine Quelle
zeigen, sonst lässt sich später nicht mehr nachweisen, dass die Datei hier stehen darf.
Neue Datei und Eintrag gehören in denselben Commit. (Für Audio gilt dasselbe, dort in
`assets/audio/CREDITS.md`.)

Alle Modelle hier sind **CC0 1.0** und stammen von zwei Autoren: **Kay Lousberg**
(KayKit) und **Quaternius**. Namensnennung fordert keiner von beiden — diese Datei ist
der Nachweis nach innen, nicht die Pflichtangabe nach außen.

Aufgeführt sind die Quelldateien. Die `.bin`-Dateien daneben sind die Geometrie der
gleichnamigen `.gltf`, die `.import`-Dateien erzeugt Godot selbst.

## `hexagon/` — Festung

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| alle `building_*.gltf`, `wall_*.gltf`, `flag_blue.gltf`, `hexagons_medieval.png` | https://kaylousberg.itch.io/kaykit-medieval-hexagon | CC0 | Kay Lousberg |

Die Festung ist aus diesen Teilen zusammengesetzt und wächst mit dem Lernfortschritt
(siehe `WaveRunner._spawn_fortress`). Die blaue Farbvariante ist bewusst gewählt, sie
passt zu den Sample-Renders des Packs.

## `props/` — Gelände, Deko, Schatzkiste, Münze

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `chest.gltf`, `coin.gltf` | https://kaylousberg.itch.io/kaykit-dungeon-remastered | CC0 | Kay Lousberg |
| `banner_red.gltf`, `barrel_large.gltf`, `crates_stacked.gltf`, `pillar.gltf`, `torch_lit.gltf`, `stairs_wide.gltf`, `floor_foundation_allsides.gltf`, `floor_tile_large.gltf`, `wall.gltf`, `wall_corner.gltf`, `wall_gated.gltf`, `wall_half.gltf`, `dungeon_texture.png` | https://kaylousberg.itch.io/kaykit-dungeon-remastered | CC0 | Kay Lousberg |
| `castle.glb` | https://quaternius.com/packs/ultimatefantasyrts.html | CC0 | Quaternius |
| `rock.glb`, `rock_PathRocks_Diffuse.png`, `tree.glb`, `tree_Bark_NormalTree.png`, `tree_Bark_NormalTree_Normal.png`, `tree_Leaves_NormalTree_C.png` | https://quaternius.com/packs/stylizednaturemegakit.html | CC0 | Quaternius |
| `grass.glb`, `grass_Atlas.png` | https://quaternius.com/ — **Pack nicht belegt**, s. u. | CC0 | Quaternius |

**Kiste und Münze teilen `dungeon_texture.png` mit dem übrigen Dungeon-Satz** — es ist
derselbe Atlas aus demselben Pack, byte-identisch (git-Blob `1bd3e9d4…`, 17 047 Bytes).
Deshalb kam mit ihnen keine neue Textur dazu, und deshalb sehen sie aus wie die Fässer im
Kampf. Wer ein weiteres Teil aus dem Pack nachholt (`chest_large`, `chest_mimic`,
`coin_stack_small/medium/large`), braucht ebenfalls nur `.gltf` + `.bin`.

**Der Atlas ist ein Raster aus 8×4 Farbfeldern**, jedes ein senkrechter Verlauf von hell
nach dunkel — die eingebackene Beleuchtung. Die Kiste benutzt genau zwei Felder (grauer
Beschlag, braunes Holz), die Münze genau eins (Gold). Weil die Felder deckungsgleich im
Raster liegen, lässt sich der Beschlag umfärben, indem seine UV-Koordinaten ein Feld
weiter rücken; die Güte der Kiste hängt daran (`TIER_METAL` in
`src/ui/treasure_chest.gd`), und der Beschlag der Goldkiste landet auf demselben Feld,
aus dem die Münze ihre Farbe nimmt.

Die Kiste besteht aus Korpus und einem eigenen Deckel-Knoten (`chest_lid`), dessen
Ursprung im Scharnier liegt — daran hängt die Öffnen-Animation in
`src/ui/treasure_chest.gd`. Eine eingebackene Animation liefert das Pack nicht.

**`chest_gold.gltf` fehlt hier mit Absicht.** Es ist keine goldene Kiste, sondern dieselbe
Kiste mit einem Münzhaufen darin (1052 ihrer 1571 Vertices; der Deckel ist Vertex für
Vertex der von `chest.gltf`). Dieser Haufen sind bei uns die Münzen, die herausfliegen —
er darf also nicht schon in der Kiste liegen.

**`grass.glb` ist der einzige Eintrag ohne belegtes Pack.** Autor und Lizenz sind
eindeutig (Quaternius, CC0, alle Packs des Autors stehen unter CC0), das Pack ließ sich
nachträglich nicht mehr feststellen: Mesh `Grass_1` und Material/Textur `Atlas.png`
kommen in mehreren Kits von Quaternius genauso vor. Wer es weiß, trägt es hier nach.

## `monsters/` — Skelette

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `Skeleton_Mage.glb`, `Skeleton_Minion.glb`, `Skeleton_Rogue.glb`, `Skeleton_Warrior.glb`, `skeleton_texture.png` | https://kaylousberg.itch.io/kaykit-skeletons | CC0 | Kay Lousberg |

Die vier `Skeleton_*_skeleton_texture.png` stehen nicht im Pack: die `.glb` tragen ihre
Textur eingebacken (glTF-Image `skeleton_texture`, ohne URI), und Godot zieht sie beim
Import als Datei daneben heraus. Alle fünf PNGs sind byte-identisch (git-Blob
`4097ba17…`, 17 037 Bytes) — dieselbe Textur, dieselbe Herkunft, dieselbe Lizenz.

## `animations/` — geteilte Rig-Animationen

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `Rig_Medium_General.glb`, `Rig_Medium_MovementBasic.glb` | https://kaylousberg.itch.io/kaykit-character-animations | CC0 | Kay Lousberg |

Die Skelette werden nicht mit eigenen Animationen ausgeliefert, sondern über diese
gemeinsame AnimationLibrary bewegt (dasselbe Rig „Medium"). Deshalb liegen die beiden
Dateien getrennt von den Monstern: sie gehören keinem einzelnen.

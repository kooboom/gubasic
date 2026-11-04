# Plan: v0.7 "Game tools" — Sprite, collisions, sound, keys held at once, milliseconds, a shooting game

[한국어](PLAN_V07.ko.md)

In the shape of [PLAN_TEMPLATE.md](../PLAN_TEMPLATE.md). It rests on DESIGN D121 (no detours: a game must be doable the way games are usually made), D100 (the Timer), D101 (the form's keys), D51 (pictures), D98 and D132 (controls as objects, `New … With`), D137 (`Visible`), and on what STAGE2_PLAN §7 found when it measured a game like Galaga: what such a game needs beyond stage 2 is several keys held at once, sound, pictures in turn, time in milliseconds and collision help. This is a plan written before implementation; §6 collects the questions for the author, each with a recommendation, and §7 the author's answers of 2026-11-04, which DESIGN D138 records.

## 1. What and why

**What the user will be able to do.** Draw a `Sprite` on a form, give it its frames (pictures of the project), a speed and a shape; move everything from one Timer's `Tick`; ask which keys are held right now; ask whether two sprites touch; play a sound. The usual shape of a small game, one Timer as the game loop, a state for each object, a timetable of when enemies come, is then written in GuBASIC as it is written elsewhere, without imitating a sprite with an `Image` and two variables, or a held key with `KeyDown` and `KeyUp` and a flag.

The smallest example (a ship that moves while a key is held and fires at an enemy):

```vb
Dim lastTime As Integer

Sub Form_Load()
    sprShip.Y = Me.Height - 60
    lastTime = Milliseconds()
    tmrGame.Start()
End Sub

Sub tmrGame_Tick()
    Dim dt As Integer = Milliseconds() - lastTime      ' how long since the last round
    lastTime = Milliseconds()
    sprShip.SpeedX = 0
    If Keyboard.IsDown(Keys.Left) Then sprShip.SpeedX = -200
    If Keyboard.IsDown(Keys.Right) Then sprShip.SpeedX = 200
    If Keyboard.IsDown(Keys.Space) And Not sprShot.Visible Then
        sprShot.X = sprShip.X + 12 : sprShot.Y = sprShip.Y
        sprShot.Visible = True
        Sound.Play("shot.wav")
    End If
    sprShip.Move(dt)
    sprShot.Move(dt)
    sprEnemy.Move(dt)
    If sprShot.Hits(sprEnemy) Then
        sprShot.Visible = False
        sprEnemy.Frames = "boom1.png, boom2.png, boom3.png"   ' an explosion, one frame after another
        Sound.Play("hit.wav")
    End If
End Sub
```

`tmrGame` is a Timer with `Interval` 16; `sprShot` starts with `SpeedY` -400 and `Visible` False; `sprEnemy` has `FrameTime` 120 so that its frames turn by themselves while it moves.

**Stage.** ROADMAP v0.7 "Game tools" (candidate, D121 a). When v0.7 is done there is the **Shooter** example (§2.6), and every item of the v0.7 list is ticked but the fighting game, which §6 Q9 recommends as the change right after.

**Why now.** v0.6 made "together" possible; the other kind of program the author named in D121, a shooter or a fighting game, is still written around the tools: STAGE2_PLAN's Galaga benchmark moves 61 `Image` controls with arrays of coordinates and checks overlaps with eight comparisons each, and holds no key, plays no sound. Everything in this plan is what that program had to go around.

## 2. How it is used

### 2.1 The `Sprite` control

A control seen on the form, drawn under the others like `Image` (`layer: graphic`), with Visual Basic .NET's names where it has them and its own where Visual Basic had nothing. It is placed in the designer, or made with `New Sprite` and `Me.Controls.Add` (§11.4), which is how a game makes twenty enemies.

| Member | What it does |
|---|---|
| `Frames` (`String`) | The names of the project's pictures that are its frames, separated by commas: `"enemy1.png, enemy2.png"`. One name is a still sprite; `""` draws nothing. A name that is not a picture of the project: A037 when written as text in the code, R013 at run time, F016 in a form file, as `Picture` today |
| `Frame` (`Integer`, 0 at first) | The frame shown, counted from 0 as arrays are (rule 10). Outside 0 to the last: R051. Setting `Frames` sets it back to 0 |
| `FrameTime` (`Integer`, milliseconds, 0 at first) | When above 0, `Move` turns the frames one after another every `FrameTime` milliseconds, going round to the first after the last. 0: the program sets `Frame` itself |
| `X`, `Y` (`Double`) | Where its top left corner is, in pixels from the form's (or its Frame's) top left corner, with fractions, so that a speed of 30 pixels a second moves it exactly 0.5 pixels in a 16 ms round. `Left` and `Top` (`Integer`), which every control has, are the same place rounded; setting any one sets the others |
| `SpeedX`, `SpeedY` (`Double`, pixels a second, 0 at first) | How fast `Move` moves it. A speed in pixels a second, not a round, is what keeps a game the same at 30 and at 60 rounds a second |
| `Width`, `Height` (`Integer`) | The frame is drawn filling them, as `Image` with `Stretch` does. When `Frames` is first chosen in the Properties window, they take the first frame's size; at run time nothing changes them but the program |
| `Shape` (`String`, `"Rectangle"` at first) | What `Hits` takes it for: `"Rectangle"`, its whole rectangle; `"Circle"`, the largest circle in its rectangle (an ellipse when it is not square); `"Pixels"`, the pixels of its frame whose alpha is 128 or more, scaled to its size. Another word: A038 and R014, as `Anchor` |
| `Anchor`, `Enabled`, `Visible`, `Tag` | As every control's (D57, D137, D98). It has no `BackColor`: what is behind it shows through its transparent pixels |
| `Move(ms As Integer)` | Moves it by its speed for `ms` milliseconds (`X = X + SpeedX * ms / 1000`, and `Y`), and turns its frame when `FrameTime` is above 0. Nothing moves by itself: a sprite moves only when the program's loop says so, which is what keeps a program deterministic and the parity tests possible |
| `Hits(other As Sprite) As Boolean` | Whether it touches `other`, by both their shapes; `False` when either is not `Visible`, or they are the same sprite. Rectangle with rectangle, circle with circle and circle with rectangle are computed; when either is `"Pixels"`, the overlap of their rectangles is tested pixel by pixel against the other's shape |
| `DistanceTo(other As Sprite) As Double` | Between their centres, for homing shots and "near enough" tests |
| Events `Click`, `MouseDown(e)`, `MouseUp(e)` | As `Image`'s (D111): a sprite can be a thing to click |

What other versions of BASIC call it: Visual Basic 6 had no sprite. Its games moved an `Image` or a `PictureBox` from a `Timer` and asked the keys through `Declare` ([Microsoft](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/declare-statement)), which GuBASIC does not have (D121 c: packages come as components). `Image` is still there for a picture that does not move; nothing of `Sprite` needs a name pointed to it.

### 2.2 `Keyboard.IsDown`

A built-in object, as `Debug` and `Color` are, with one function:

| Member | What it does |
|---|---|
| `Keyboard.IsDown(key As Integer) As Boolean` | Whether that key is held right now, `key` being a `Keys` value (D101): `Keyboard.IsDown(Keys.Left)`. Several keys can be down at once, which is the whole point. It is a question, not an event: it does not wait for a handler, does not re-enter anything, and asks nothing of the user. On phones (stage 3) it is always `False` |
| `Keys.ShiftKey`, `Keys.ControlKey`, `Keys.Menu` | Added so that Shift, Control and Alt can be fire or jump keys; Visual Basic .NET's names and numbers (16, 17, 18; [Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.keys)). They still raise no `KeyDown` or `KeyUp` alone (D101): only `IsDown` knows them |

What it is: the interpreter keeps the set of keys that are down from the `KeyDown` and `KeyUp` it is told, before they queue as events, so that `IsDown` is true from the `KeyDown` to the `KeyUp` whether or not the form's handlers ran, and also while a `TextBox` has the focus and `KeyPreview` is off (a state, not an event). When the window loses the focus, or a dialog opens, the host says that all keys are up, so that no key stays "held" after Alt+Tab or a `MsgBox`. In a parity script the same lines that drive `KeyDown` drive it: `Form.KeyDown Left` makes it true, `Form.KeyUp Left` false.

Visual Basic 6's `GetAsyncKeyState` through `Declare` is the thing this replaces. GuBASIC has no `Declare` and today the parser reports the line as it reports any unknown statement; P042 names it: packages come as components (COMPONENT_CHANNEL), and when the declared name is `GetAsyncKeyState` or `GetKeyState`, the message adds that keys held right now are asked with `Keyboard.IsDown`.

### 2.3 `Milliseconds()`

| Function | What it gives |
|---|---|
| `Milliseconds() As Integer` | The milliseconds since the program started, from a clock that only goes forward (a stopwatch, not the wall clock, so that a change of the computer's time does not jump a game). `Integer` is exact (D26), so it never wraps |

A game loop reads it at the top of every `Tick` and gives the difference to `Move`, as §1 shows; then the game is the same whether the Timer managed 60 rounds a second or 40. Visual Basic 6's `Timer` function (seconds since midnight) and Visual Basic .NET's `Environment.TickCount` are pointed to it (A080): in GuBASIC `Timer` is the control's name.

A parity script advances the clock with a new line, `Wait 16` (milliseconds), between ticks; the fake host's clock moves only on that line, so an `.out` is the same on every machine.

### 2.4 `Sound`

A built-in object with the project's sounds, which are files in its `sounds/` folder listed in the `.gbproj` as its pictures are (§11.3):

| Member | What it does |
|---|---|
| `Sound.Play(name)` | Plays an effect once, at once; several at once overlap, and a `Play` while the same one is playing starts it again over it. A name that is not a sound of the project: A082 as text in the code, R052 at run time |
| `Sound.PlayMusic(name)` | Plays one sound round and round until `StopMusic`, the program ends, or another `PlayMusic` replaces it. One at a time |
| `Sound.StopMusic()` | Stops it |
| `Sound.Volume` (`Integer`, 0 to 100, 100 at first) | For everything the program plays; outside the range R050 as for colours |

**Formats:** WAV and MP3 only (`.wav`, `.mp3`); both play in every browser the web player runs in and on Windows and macOS, and OGG does not play in Safari ([MDN: Web audio codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs#choosing_an_audio_codec)). Another extension: F024, as F014 for pictures; two names differing only in case: F025, as F015.

**On the web** a page may not play sound until the user has clicked or pressed a key on it ([Chrome's autoplay policy](https://developer.chrome.com/blog/autoplay)); a `Play` before that is dropped without an error. LANGUAGE and the reference say so and why: the browser's rule, not GuBASIC's, so that a program written on the desktop still runs on the web. A game that begins only when a Start button is pressed, as the Shooter does, never meets it.

**Project file.** `sounds:` lists them; a project with sounds is written as `formatVersion: 4`, which an older GuBASIC refuses to open rather than play nothing (rule 8; as `pictures` did with 2 and modules with 3, D102). Reading 3 as 4 needs no migrator: `sounds` is only added.

### 2.5 Diagnostics (draft)

Numbers follow today's last (A079, R050, F023, P041); the Korean ones in the documents' "~합니다" style, with no particle after a placeholder.

| Code | When | English | Korean |
|---|---|---|---|
| A080 | `Timer()` or `Environment.TickCount` as a function | `Timer` is a control in GuBASIC; the time in milliseconds is `Milliseconds()`. | GuBASIC에서 `Timer`는 컨트롤입니다. 밀리초 단위 시간은 `Milliseconds()`입니다. |
| A081 | `Beep`, `PlaySound`, `My.Computer.Audio.Play` | Write `Sound.Play("NAME.wav")` with a sound of the project. | 프로젝트의 소리로 `Sound.Play("NAME.wav")`라고 씁니다. |
| A082 | `Sound.Play("x.wav")` with a sound the project does not have (as A037 for a picture) | `{0}` is not a sound of this project. Add it to the project's sounds first. | `{0}` 소리가 이 프로젝트에 없습니다. 먼저 프로젝트의 소리에 더합니다. |
| P042 | a `Declare` statement; with `GetAsyncKeyState` or `GetKeyState`, the second sentence | GuBASIC has no `Declare`: outside abilities come as components. Keys held right now are asked with `Keyboard.IsDown(Keys.Left)`. | GuBASIC에는 `Declare`가 없습니다. 바깥의 기능은 컴포넌트로 들어옵니다. 지금 눌린 키는 `Keyboard.IsDown(Keys.Left)`로 묻습니다. |
| R051 | `Frame` outside 0 to the last frame | `Frame` must be from 0 to {0}; it is {1}. | `Frame` 값은 0에서 {0} 사이여야 하는데 {1}입니다. |
| R052 | a sound the project does not have, at run time | There is no sound named {0} in this project. | 이 프로젝트에 {0} 소리가 없습니다. |
| F024 | a sound name a sound cannot have | A sound is a `.wav` or `.mp3` file whose name has none of `/ \ : * ? " < > \|`: {0}. | 소리는 이름에 `/ \ : * ? " < > \|`가 없는 `.wav`나 `.mp3` 파일입니다: {0} |
| F025 | two sounds whose names differ only in case | Two sounds cannot have the same name in different cases: {0} and {1}. | 대소문자만 다른 같은 이름의 소리를 둘 둘 수 없습니다: {0}, {1} |

### 2.6 The Shooter example

`examples/shooter`, one form of 480×640, the keyboard being the controls. It shows the usual shape in order, with the comments teaching it:

- **One Timer as the game loop** (`tmrGame`, `Interval` 16): read `Milliseconds()`, read the keys, move everything, test the hits, draw the score.
- **A state for each object:** the ship, ten shots and twenty enemies are Sprites made in `Form_Load` with `New Sprite With {.Frames = "enemy1.png, enemy2.png", .FrameTime = 150, .Visible = False}` and kept in arrays (`Dim enemies(19) As Sprite`); `Visible` says whether one is in play.
- **A timetable of when enemies come:** a `Structure Wave` with `At` (milliseconds), `Lane` and `Kind`, in an array filled in `Form_Load`; the loop starts the next wave when `Milliseconds()` passes its `At`.
- **Sounds:** `shot.wav` and `hit.wav`; `music.mp3` with `PlayMusic` after the Start button (the web's rule, §2.4).
- **An explosion** is a sprite whose `Frames` are three pictures and whose `FrameTime` is 80; when its last frame has shown, `Visible = False`.
- Score and lives in Labels; Game Over. **Nothing moves and nothing sounds until the Start button is pressed:** `Form_Load` sets things up and the Timer starts in `btnStart_Click`, which is also what lets the web page play sound (§2.4); the button starts the game again after Game Over. A phone has no keys: the example says it is for the desktop and the web with a keyboard.

Pictures and sounds are made by a tool script as LiveQuiz's pictures are (`apps/ide/tool/draw_quiz_pictures.dart`): plain shapes, and sounds synthesised as WAV (a short square wave and a noise burst) so that no file comes from outside and nothing is licensed.

## 3. Design

### 3.1 Where things go

- **`components/Sprite/component.yaml`**, embedded by `tool/embed_components.dart`. `Frames` is a `String` with `picture: true` meaning several names (the Properties window's picker lets several be chosen and writes the text); `X`, `Y`, `SpeedX`, `SpeedY` are `Double`, which component.yaml already has; `Shape` is text like `Anchor`.
- **`gubasic_lang`** (pure Dart, rule 1):
  - the analyzer's members for `Sprite`, `Keyboard`, `Sound` and `Milliseconds`, with A080 to A082 and P042;
  - the interpreter: `Move`, the set of keys down, `Milliseconds` from `Host.milliseconds`, `Sound` through a `SoundHost` (`play`, `playMusic`, `stopMusic`, `volume`) beside `FileHost`, which the playground does not have (R038, as `Http`);
  - **`lib/src/forms/collision.dart`:** the geometry of `Hits` and `DistanceTo` in pure Dart (rectangle, circle, pixels), with the pixel masks from `FormHost.pictureMask(name)`: width, height and one bit per pixel for alpha ≥ 128. It is pure so that the parity tests run it on the VM and in Chrome, and so that the transpiler's generated code can use the same file;
  - the project file: `sounds`, `formatVersion: 4`, F024 and F025;
  - the event script: `Wait N`.
- **`gubasic_runtime`:** `sprite.dart` draws the frame, stretched, from the project's pictures (the same bytes `Image` uses); `picture_mask.dart` decodes a picture once (`instantiateImageCodec`, `toByteData` as raw RGBA) into the mask the interpreter asks for, cached by name; `sound.dart`, `GbSound`, over the package of §6 Q5, playing bytes the project gives it; `form_view.dart` tells "all keys up" when the form loses the focus or a dialog opens, as it already tells `KeyDown` and `KeyUp`. The runtime stays the only Flutter code the interpreter and generated apps use (rule 6).
- **`gubasic_player`:** the project model carries `sounds/` as it carries `pictures/`; the run window's host answers `pictureMask`, `milliseconds` (a `Stopwatch` started with the program) and the sound calls; the exported app's bundle and the web template serve the sounds.
- **The IDE:** `Sprite` in the toolbox with an icon; the designer draws the first frame (and a dashed box when `Frames` is empty); the Properties window's picker for `Frames` (several pictures, in order); a "Sounds" group in the project explorer beside "Pictures", with Add (a file dialog for `.wav` and `.mp3`) and Remove; the web IDE keeps sounds in the browser as it keeps pictures (D53).
- **Documents:** LANGUAGE §10 (`Milliseconds`), §11.1 (`Sprite`, `Keyboard`, `Keys.ShiftKey`…), §11.3 (`sounds`, `formatVersion: 4`), a new §11.13 `Sound`; the reference and `llms.txt` by `gen_reference.dart`; DESIGN D138 with the answers; ROADMAP ticks; KNOWN_ISSUES for what §4 leaves out.

### 3.2 Hard rules, and what stays open

- **One AST (rule 2):** nothing new in the grammar; `Sprite`, `Keyboard`, `Sound` and `Milliseconds` are members and a built-in function, resolved by the analyzer as `Http` and `Color` are, so the transpiler meets them as calls it maps to the runtime.
- **Async, no re-entry (rules 4, 5):** `Move`, `Hits`, `IsDown` and `Milliseconds` are plain calls inside the running handler; nothing new is an event. `Sound.Play` does not wait (the sound goes on while the loop goes on); it is the one call that does not, and §6 Q6 says why.
- **The runtime only (rule 6):** the drawing, the decoding and the sound are in `gubasic_runtime`; the geometry is pure Dart that both the interpreter and, later, generated code call.
- **Every control is a component (rule 7):** `Sprite` is `component.yaml`; `Keyboard` and `Sound` are built-in objects like `Debug`, not controls, since they have no place on a form and no state the designer sets.
- **The file format (rule 8):** `sounds` is added, `formatVersion` goes to 4 only for a project with sounds; nothing existing changes meaning.
- **Secrets (rule 12):** nothing new is sent anywhere.
- **The Galaga benchmark** (`test/bench/galaga`) is kept as it is, since it measures the interpreter's loop; the Shooter example is measured the same way once (STAGE2_PLAN §7's criteria) to see that `Move` and `Hits` cost less than the BASIC lines they replace.

## 4. No detours (D121)

- **Is there anywhere users would still have to go around?** Left for later, and going into KNOWN_ISSUES: rotating a sprite (`Angle`) and flipping it (a sprite looking left is a second picture for now); a tile map or a scrolling background (a wide `Image` moved by the loop does it for a start); a joystick or gamepad; music that fades; sound on phones before stage 3 has been tried on one. Not left: everything STAGE2_PLAN §7 listed as what the Galaga game went around.
- **Does it talk to the outside in a standard?** PNG, JPEG and GIF pictures as before; WAV ([RFC 2361](https://www.rfc-editor.org/rfc/rfc2361), the registration of the WAVE format) and MP3 (MPEG-1 Audio Layer III, [MDN](https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs)) sounds, both played by every browser and desktop system named above.
- **Is there a way in for what it does not do itself?** The component channel ([COMPONENT_CHANNEL.md](../COMPONENT_CHANNEL.md)): a package with a gamepad, a particle system or a physics engine would come as a component with the transpiler. `Sprite` itself is a component.
- **Documents and examples:** §3.1's list; the Shooter example; FIRST_APP gets a line pointing to it; the reference for AI assistants is generated.

## 5. Tests

- **Parity programs** (`test/parity/`, the VM, Chrome and the run window): `sprite_move` (speed, `Move`, `X` with fractions and `Left` rounded, `Anchor`), `sprite_frames` (`Frames`, `Frame`, `FrameTime`, R051), `sprite_hits` (rectangle, circle, pixels, with small pictures in `sprite_hits.pictures/` whose corners are transparent, `Visible` False, `DistanceTo`), `keyboard_isdown` (several keys at once, up on a dialog, in a TextBox), `milliseconds` (`Wait` lines, differences between ticks), `sound_play` (the transcript shows `Sound: shot.wav`, `Music: music.mp3`, `Music stopped`, as it shows a `MsgBox`; R052; `Volume` out of range), `shooter_example` (the example driven by a script of `Wait`, keys and ticks through a hit and a game over).
- **`gubasic_runtime`:** widget tests that a Sprite draws its frame stretched and nothing when `Frames` is `""`; that a mask from a PNG with transparent corners has the bits expected; that `GbSound` is asked to play the bytes of the named sound (a fake player); that losing the focus tells "all keys up".
- **`gubasic_player`:** the parity programs through the run window's widgets, as today; the exported bundle carries `sounds/`.
- **The IDE:** widget tests for the toolbox's Sprite, the `Frames` picker, the Sounds group and its dialogs; an integration test (Windows and macOS, in CI) that runs the Shooter example in the IDE's own window for two seconds with keys from the test, hears the sound calls through a fake, and keeps a picture of the window (D119).
- **The web:** `tool/web_check/shooter.mjs` (Playwright) plays the built web player's Shooter with the keyboard, checks that the score changes and that the page made an `AudioContext` only after the first key, and, on this PC, runs with `--channel chrome`.
- **By hand:** the example on the Mac and on Windows, by the author, with a real keyboard, for the feel of the movement and the latency of the sound.

## 6. Questions for the author

Each with a recommendation; the answers go into DESIGN D138.

1. **A new `Sprite`, or more properties on `Image`?** Recommended: a new control. `Image` stays what a work program expects (a picture that never resizes itself, integer position), and a Sprite's `X`/`Y` with fractions, speed, frames and shape would be twelve properties a photo in a form never uses.
2. **`Frames` as text (`"a.png, b.png"`) or a list with its own picker?** Recommended: text, as `Anchor` is text, with the Properties window offering a picker that writes it: a program can then build it with `&`, a form file stays readable, and no new property type is needed.
3. **Position: `X`/`Y` as `Double` beside the Integer `Left`/`Top`?** Recommended: yes. A sprite at 30 pixels a second must move half a pixel a round; Integer `Left` alone would make it stand still. `Left`/`Top` stay for everything written for other controls.
4. **Collision shape: a property of each sprite (`Shape`), or an argument of `Hits`?** Recommended: the property, so that a shot is "Circle" once and every `Hits` is one short call; pixels count when alpha ≥ 128, the usual threshold that ignores anti-aliased edges.
5. **Sound package:** `audioplayers` (a plugin with Windows, macOS, Linux, web, iOS and Android; MIT) or `flutter_soloud` (lower latency through FFI, but on the web it needs its own WASM files and script, which the web template and the Pages deploy would have to carry) or Web Audio through `package:web` on the web plus platform code of our own on the desktop. Recommended: `audioplayers`, one package for every platform the player has, with plugin registrants committed as CLAUDE.md says; if its latency on an effect proves too long on Windows in the integration test, `flutter_soloud` is the fallback, and the `GbSound` interface hides the choice. **The author's answer (§7): measure first.**
6. **`Sound.Play` does not wait.** Recommended: right, unlike `Http` and `Room` (D124 A, D136): a game loop cannot stop for 200 ms of a sound, and there is nothing to come back with. `PlayMusic` and `StopMusic` likewise.
7. **The name and the zero of the clock: `Milliseconds()`, counted from the program's start.** Recommended; `TickCount` would collide in a reader's mind with the Timer's `Tick`, and `Timer()` is the control's name (A080 says so).
8. **Shift, Control and Alt as keys for `IsDown`** (`Keys.ShiftKey`, `Keys.ControlKey`, `Keys.Menu`, Visual Basic .NET's). Recommended: add them for `IsDown` only; `KeyDown` and `KeyUp` keep D101's rule that they come with another key.
9. **Examples: the Shooter in v0.7, the fighting game right after as its own change.** Recommended: so that v0.7 lands as small changes (§6 Q11) and the fighting game, which needs two players on one keyboard, punch and kick frames and a health bar, exercises the same tools once they are in rather than widening this plan.
10. **The web's autoplay rule: a `Play` before the first click or key is dropped silently.** Recommended; the alternative, an error, would stop a program on the web that runs on the desktop, and the Shooter starts with a button anyway. **The author's answer (§7): yes, with the reason written down and the Shooter waiting for Start.**
11. **The order of the changes**, each merged on its own with its parity programs: (1) `Milliseconds` and `Wait`; (2) `Keyboard.IsDown` and the three keys; (3) `Sprite` with `Move` and frames; (4) `Hits` and `DistanceTo`, rectangle, circle, pixels; (5) `Sound`, the project file and the IDE's Sounds group; (6) the Shooter example, the web check, the documents and D138. Recommended as listed: each step is usable alone, and the example comes when everything it needs is in.
12. **Sizes when `Frames` is chosen:** the Properties window sets `Width` and `Height` to the first frame's size the first time, and never again (the author may resize). Recommended; `Image`'s rule that the control never resizes itself (D51) stays for `Image`.

## 7. The author's answers (2026-11-04)

Every recommendation of §6 is taken, with two changes; DESIGN D138 records them.

- **Q5, the sound package, is chosen by measurement, not by this plan.** Before the Sound change (§6 Q11, step 5), the latency from `Play` to the first sound of `audioplayers` and of `flutter_soloud` is measured on the web, on macOS and on Windows, in three cases: one short effect, the same short effect many times in quick succession, and several different sounds at once. The results go into a table in this section when they are in, and the better package is taken without another question. The `GbSound` interface is the same for both.
- **Q10, sound on the web before the first click, is dropped silently as recommended, and the reason is written down:** LANGUAGE §11.13 and the reference say that it is the browser's rule and why a program is not stopped for it. The Shooter example begins only when its Start button is pressed (§2.6), so that its first sound comes after the click.
- Q1 to Q4, Q6 to Q9, Q11 and Q12: as recommended.

### 7.1 The sound packages measured (2026-11-04, Windows and the web)

`packages/gubasic_runtime/tool/sound_probe` plays five sounds it makes itself (a 50 ms shot, an 80 ms noise, a 30 ms beep, a tone, a chord) through each package and takes the milliseconds from the call to the first progress the package reports; `tool/web_check/sound_probe.mjs` runs its web build in Chrome. Windows 11 with the Windows app; the web in headless Chrome 155 (the browser's own buffer comes on top, the same for both). The median is of what started; "started" counts what reported progress within a second.

| Case | audioplayers 6.8.1, Windows | flutter_soloud 5.2.2, Windows | audioplayers, web | flutter_soloud, web |
|---|---|---|---|---|
| One short effect (5 times) | median 53 ms, max 61 | median 27 ms, max 30 | median 23 ms, max 28 | median 24 ms, max 29 |
| The same effect 20 times, 10 ms apart | median 452 ms, max 990, **17 of 20 started** | median 27 ms, max 49, 20 of 20 | median 385 ms, max 497, 20 of 20 | median 26 ms, max 53, 20 of 20 |
| Five different sounds at once | 260 ms each | 2 ms each | 308 ms each | 9 ms each |

Each `audioplayers` play is a player of its own (what a new effect over a playing one needs) and it queues them: the twentieth shot starts a second late, and three were lost on Windows. `flutter_soloud` mixes voices itself and starts each within a frame. **Chosen: `flutter_soloud`**, as the author allowed without another question; the macOS run is taken on the Mac with the same probe, and if it contradicts this the choice is looked at again. What comes with it: its `init_soloud.js` script line in the web pages (the IDE's, the player's and the web template's `index.html`), its WASM files served with the app, and its native plugin registered on Windows and macOS.

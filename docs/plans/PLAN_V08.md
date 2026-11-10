# Plan: v0.8 "Fighting game"

[한국어](PLAN_V08.ko.md)

Written 2026-11-10 as [PLAN_TEMPLATE.md](../PLAN_TEMPLATE.md) says; the questions in §6 wait for the author's answers before any work starts.

## 1. What and why

**What.** A fighting game for two people on one keyboard, written the way such games are written: each fighter is a state machine (standing, walking, jumping, crouching, attacking, blocking, hit, knocked out); each attack has its frame data (how long before it hits, how long it hits, how long to recover); the body and the attack are boxes apart from the picture (hurtbox and hitbox); a hit stops both for a moment (hit stop), pushes back and takes health shown in a bar; rounds have a clock and end in a KO. The example is called **Duel**.

The smallest program that shows the new tools:

```vb
Sub tmrGame_Tick()
    ' The fighters face each other: one picture, drawn the other way round.
    sprP1.FlipX = sprP1.X > sprP2.X
    ' An attack starts on the press, not while the key is held.
    If Keyboard.WasPressed(Keys.F) Then StartAttack(0, Punch)
    If Keyboard.WasPressed(Keys.OemPeriod) Then StartAttack(1, Punch)
    ' The one attacking is drawn in front.
    If attacking(1) Then sprP2.BringToFront()
End Sub
```

**Stage.** ROADMAP "After v0.6 (candidates)": "Example: a fighting game, the next candidate after v0.7" (D138, plans/PLAN_V07.md §6 Q9), named here v0.8. It rests on D121 a (no detours), D138 (Sprite, Hits, Keyboard.IsDown, Milliseconds, Sound) and D137 (BackColor for the health bars).

**Why these tools.** Written with v0.7's tools alone, the game would have to go around four things, each of which the usual tools of the trade have built in:

1. **Facing the other way.** A fighter turns round whenever the two cross. Without a flip, every frame is drawn twice, mirrored, and the program picks the left or right set; KNOWN_ISSUES ("What v0.7's game tools leave for later") said this comes back with the fighting game.
2. **A key just pressed.** A punch starts when its key goes down, once; held, it must not punch again. With `IsDown` alone a program keeps last tick's state of every key and compares, and a tap that goes down and up between two ticks is lost.
3. **Which is drawn in front.** The attacker's fist must cover the other fighter; sprites are drawn in the order they were made, which nothing can change.
4. **The second player's keys.** One keyboard for two: the usual layout puts the second player on the arrows with `,` `.` `/` beside them. `Keys` has letters, digits, the numeric pad and F keys, but none of the punctuation keys, so they cannot be read.

The boxes (hurtbox and hitbox) need nothing new: a `Sprite` with `Frames = ""` draws nothing and still `Hits` as a rectangle, so a box is a sprite placed each tick from its fighter. The example shows it, with a switch that draws the boxes, as fighting-game makers do to tune them.

## 2. How it is used

### 2.1 `Sprite.FlipX`

| Member | What |
|---|---|
| `FlipX` (`Boolean`, `False` at first) | The frame is drawn mirrored left to right, in the same place and size. `Hits` by `"Pixels"` uses the mirrored pixels; `"Rectangle"` and `"Circle"` are the same either way. |

Only left to right: a fighter, a walker or a ship turns round; upside down (`FlipY`) and rotation (`Angle`) stay in KNOWN_ISSUES. The designer's Properties window shows it as a check box, as `Visible`.

### 2.2 `Keyboard.WasPressed(key)`

| Member | What |
|---|---|
| `Keyboard.WasPressed(key)` → `Boolean` | Whether `key` went down since the program last asked `WasPressed` of that key (since the program started, the first time). A key held does not count again, nor does the system's key repeat; a press and a release between two ticks counts once. |

`IsDown` stays the question "is it held now" (walking, blocking); `WasPressed` is "was it pressed" (an attack, a jump, a menu choice). Asked of one key, it answers once per press; two places asking of the same key share it, which the reference says. When the window loses the focus or a dialog opens, nothing is pressed meanwhile. On phones always `False`, as `IsDown`.

### 2.3 `BringToFront()` and `SendToBack()`

| Member | What |
|---|---|
| `spr.BringToFront()` | Draws the sprite in front of every other sprite and image on the form (it is still under buttons and labels, D138's layer). |
| `spr.SendToBack()` | Behind them all. |

Visual Basic .NET's names ([Microsoft: Control.BringToFront](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.control.bringtofront), [Control.SendToBack](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.control.sendtoback)). On `Sprite` and `Image`, the controls of the picture layer; the other controls do not overlap in the designer's usual forms, and get them when a program needs it. `Me.Controls` keeps its order (the order of the form file and of adding), so a loop over it is unchanged; only the drawing changes.

### 2.4 The punctuation keys

`Keys.Oemcomma`, `Keys.OemPeriod`, `Keys.OemQuestion`, `Keys.OemSemicolon`, `Keys.OemQuotes`, `Keys.OemMinus`, `Keys.Oemplus`, `Keys.OemOpenBrackets`, `Keys.OemCloseBrackets`, `Keys.OemPipe`, `Keys.Oemtilde`, with Visual Basic .NET's names and numbers (188, 190, 191, 186, 222, 189, 187, 219, 221, 220, 192; [Microsoft: Keys](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.keys)). They are the keys' places on a US keyboard, as .NET's are; on another layout the same place has another letter printed, and the reference says so. They raise `KeyDown` and `KeyUp` as other keys, and `IsDown` and `WasPressed` answer them.

### 2.5 The Duel example

`examples/duel`, one form of 640×400.

- **Keys.** Player 1: `A` `D` walk, `W` jump, `S` crouch, `F` punch, `G` kick. Player 2: `←` `→` walk, `↑` jump, `↓` crouch, `.` punch, `/` kick. Holding back (away from the other) blocks. Both sets are read with `IsDown` and `WasPressed`, so they work at once.
- **One Timer as the loop** (16 ms), with `Milliseconds()`: read the keys, run each fighter's state machine, move, place the boxes, test the hits, then the health bars, the clock and the round.
- **One routine for both fighters:** arrays indexed 0 and 1 (`state(1)`, `health(1)`, `facing(1)`, …) and the sprites in arrays, so the same code drives both.
- **Frame data in a table:** `Structure Attack` with `Startup`, `Active`, `Recovery` (milliseconds), `Damage`, `Reach` and `Height` of the hitbox, `Frames`; a punch and a kick, high and low by crouching.
- **Boxes:** each fighter has a hurtbox sprite and a hitbox sprite with no frames; "Show boxes" (a CheckBox) gives them a translucent picture.
- **A hit:** hit stop of 80 ms (nothing moves), push back, health down, a sound; blocked, less push and a different sound, and no damage.
- **Rounds:** 60 seconds; a KO or the clock ends a round; two rounds win; Start begins and starts again.
- **Pictures and sounds** made by a tool script, as the Shooter's (`apps/ide/tool/draw_duel_assets.dart`): plain shapes in two colours, one set of frames each, facing right; WAV sounds synthesised.

### 2.6 Messages

No new diagnostics. `WasPressed` of a number that is no key answers `False`, as `IsDown` does today; a new property, method or key name misspelt is the analyzer's unknown member, with its "did you mean" (D50).

## 3. Design

### 3.1 Where things go

- **`gubasic_lang`:** `WasPressed` in the interpreter, beside the set `IsDown` uses: a second set of keys pressed and not yet asked, filled on an up-to-down change only (a repeated `KeyDown` while held adds nothing), cleared for a key when asked, and cleared wholly when "all keys up" comes (focus lost, a dialog). The punctuation keys in `forms/keys.dart`. `FlipX`, `BringToFront` and `SendToBack` in `components/Sprite/component.yaml` and `components/Image/component.yaml`; the analyzer knows them from there. The event script's key steps take the new key names.
- **`gubasic_runtime`:** the Sprite draws its frame mirrored with `Transform.flip` when `FlipX`; the pixel mask of `Hits` is read mirrored (geometry stays pure Dart). The picture layer draws in an order the model keeps (a number per control, raised by `BringToFront`), not only the order of the file.
- **`gubasic_player`:** the keys the window hears map to the punctuation keys (`LogicalKeyboardKey.comma`, `.period`, `.slash`, …).
- **The IDE:** `FlipX` in the Properties window; the Duel example in the Examples menu; the asset script.

### 3.2 Hard rules, and what stays open

- **One AST (rule 2):** nothing new in the grammar; `FlipX`, `WasPressed`, `BringToFront`, `SendToBack` and the keys are members and values resolved by the analyzer, as v0.7's were.
- **Async, no re-entry (rules 4, 5):** `WasPressed` is a question that waits for nothing, like `IsDown`; nothing new is an event.
- **The runtime only (rule 6):** drawing and the pixel masks are in `gubasic_runtime`.
- **Every control is a component (rule 7):** the new members are in the components' YAML.
- **The file format (rule 8):** `FlipX` is a new property with a default; nothing existing changes meaning and `formatVersion` stays 4. The drawing order is not saved: a form is drawn in its file's order when it starts, as today.
- **Secrets (rule 12):** nothing is sent anywhere.

## 4. No detours (D121)

- **Is there anywhere users would still have to go around?** Left for later, into KNOWN_ISSUES: `FlipY` and `Angle`; a gamepad (two players on one keyboard is the usual way without one; some keyboards cannot report many keys held at once, which no program can change); online play between two computers (`Room` carries messages, but a fighting game over a network needs rollback, a subject of its own); a computer opponent if §6 Q6 says so. Not left: the four things in §1.
- **Does it talk to the outside in a standard?** Pictures PNG as before, sounds WAV ([RFC 2361](https://www.rfc-editor.org/rfc/rfc2361)); the keys by .NET's `Keys` numbers.
- **Is there a way in for what it does not do itself?** The component channel ([COMPONENT_CHANNEL.md](../COMPONENT_CHANNEL.md)), as for v0.7: a gamepad or a physics engine would come that way.
- **Documents and examples:** LANGUAGE §11.1 (`WasPressed`, the keys), the Sprite paragraph (`FlipX`, the drawing order, a sprite with no frames as a box); the reference and `llms-full.txt` generated; the Duel example; ROADMAP v0.8.

## 5. Tests

- **Parity programs** (`test/parity/`, the VM, Chrome and the run window): `keyboard_waspressed` (a press counts once, held does not, a repeat does not, two keys at once, a dialog clears it, a key asked twice); `keys_punctuation` (the new `Keys` values as numbers and in `KeyDown`); `sprite_flip` (`Hits` by pixels with a picture that is not symmetric, flipped and not); `sprite_order` (`BringToFront` and `SendToBack`, and `Me.Controls` unchanged); `duel_example` (the example driven by a script of keys, `Wait` and ticks through a hit, a block, a KO and a round).
- **`gubasic_runtime`:** a widget test that a flipped sprite's pixels are mirrored on the screen and in its mask; that `BringToFront` draws it on top (a picture of overlapping sprites).
- **`gubasic_player`:** the punctuation keys from the window reach `IsDown` and `WasPressed`.
- **The IDE:** an integration test (Windows and macOS in CI) that plays a round in the IDE's own window with keys from the test, and keeps a picture (D119).
- **The web:** `tool/web_check/duel.mjs` (Playwright) plays the built web player's Duel with the keyboard, including `.` and `/`.
- **Speed:** measured once as STAGE2_PLAN §7 measures the Shooter (benchmark 7).
- **By hand:** the author plays it with someone on the Mac and on Windows, for the feel of the keys.

## 6. Questions for the author

1. **The version.** Recommended: **v0.8 "Fighting game"**, since it adds members to the language and keys, not only an example; the ROADMAP gets a v0.8 list.
2. **`FlipX`.** Recommended: add it (left to right only), as §2.1. The alternative, every frame drawn twice, is the detour D121 asks to avoid.
3. **`Keyboard.WasPressed`.** Recommended: add it, "since last asked of that key", as §2.2. Alternatives: a "pressed this tick" rule would need the language to know what a tick is, which it does not; leaving it to the program loses quick taps.
4. **`BringToFront` and `SendToBack`.** Recommended: on `Sprite` and `Image` now, as §2.3, with .NET's names; on other controls when a program needs it.
5. **The punctuation keys.** Recommended: add the eleven of §2.4 with .NET's names and numbers, so that the second player can use `.` and `/`. Alternative: player 2 on the numeric pad, which laptops lack.
6. **A computer opponent.** Recommended: **yes, a simple one**, chosen with a "1 player / 2 players" choice on the start screen, so that one person can try the example: it walks toward the other, attacks when in reach and blocks now and then, about 40 lines of the same state machine. Alternative: two players only, and the computer opponent later.
7. **Order of the work.** Recommended, each merged on its own with its parity programs: (a) the punctuation keys and `WasPressed`; (b) `FlipX`; (c) `BringToFront` and `SendToBack`; (d) the Duel example with its assets, the web check, the integration test and the documents; then the speed measured.

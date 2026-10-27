# Ideas

[한국어](IDEAS.ko.md)

Ideas worth keeping that no stage has taken on yet. Nothing here is decided or planned: an idea moves into the ROADMAP, with a plan and its decisions, only when the author chooses it.

---

## Adventure game controls

**Goal:** a set of controls for making point-and-click adventure games: a picture of a place, things in it to look at and click, a character who walks there, people to talk to, and a bag of things to use on other things. Visual Basic 6 had nothing like it; with these, anyone could make the kind of game that is drawn and clicked rather than typed.

**When:** a candidate for after stage 3. It changes neither the stage 2 plan nor the project bundle format (STAGE2_PLAN.md).

### Candidates

| Control | What it does |
|---|---|
| **Scene** | A place: a background picture that fills the form, and going from one scene to another (with a fade, say). A game is a set of scenes |
| **Hotspot** | An invisible area of the scene that can be clicked; with the mouse over it, its name shows ("old door"). Events: `Click`, `MouseEnter`, `MouseLeave` |
| **Sprite** | A character drawn from several pictures in turn (walking left, right, towards, away). `WalkTo x, y` makes it walk there, choosing the pictures by direction; `Arrived` comes when it gets there |
| **Dialog** | Speech bubbles over a sprite, and a list of choices for the player, each leading on to the next lines |
| **Inventory** | The player's bag: pictures of the things carried; a thing dragged out of it and dropped on a Hotspot, a Sprite or another thing raises an event that says what was used on what (`UseOn`) |

### What must come first

- **Timer** (STAGE2_PLAN step 2-9): walking, animation and fades move a little every tick.
- **Key events** (step 2-10): moving or skipping dialogue from the keyboard.
- **Several forms, or scenes** (steps 2-7, 2-8): a game moves between places; a Scene could be built on forms or be its own thing, to be decided then.
- **Many pictures:** a sprite's walking needs sets of pictures in order (frames) per direction; the project's pictures today are single images (LANGUAGE §11.3), so a way to group them comes first.

### How an existing tool does it: Adventure Game Studio

Adventure Game Studio (AGS), a tool made for such games, builds them from a few ideas that match the candidates above:

- **Rooms:** "games are made up of several rooms, which the player moves between"; "each room is one screen that has its own background, hotspots, and objects" ([AGS manual, part 2](https://adventuregamestudio.github.io/ags-manual/v3/acintro2.html)). → Scene.
- **Hotspots, objects and characters:** the three kinds of thing the player can interact with. "A hotspot is an area of the background image that the player can look at and interact with", for parts that do not change; an object "can move around the screen, and be switched on and off" ([part 3](https://adventuregamestudio.github.io/ags-manual/v3/acintro3.html), [part 4](https://adventuregamestudio.github.io/ags-manual/v3/acintro4.html)). → Hotspot; an Image already plays the object's part.
- **Inventory:** "each character in the game can carry their own set of inventory items", set up separately from the objects in rooms ([part 5](https://adventuregamestudio.github.io/ags-manual/v3/acintro5.html)). → Inventory.
- **Views and loops:** "a view is a set of one or more loops. A loop is a set of frames which, when played in sequence, give the illusion of movement", used for a character's walking ([part 7](https://adventuregamestudio.github.io/ags-manual/v3/acintro7.html)). → Sprite, and the grouped pictures it needs.
- **Conversations:** from one fixed line to "complete dialog trees through which you could choose your topics" ([part 8](https://adventuregamestudio.github.io/ags-manual/v3/acintro8.html)). → Dialog.
- **Cursor modes:** each mouse cursor is a different way to interact, "Walk to" among them, and "Use inventory" when an item is chosen ([part 9](https://adventuregamestudio.github.io/ags-manual/v3/acintro9.html)). GuBASIC would rather keep one pointer: click to walk or look, drag a thing from the bag to use it.

What GuBASIC would keep of its own: the controls are drawn on a form in the designer, and the game is written as event handlers (`hsDoor_Click`, `sprHero_Arrived`, `invKey_UseOn`), as everything else in GuBASIC is.

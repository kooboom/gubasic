# The component channel

> The three questions at the end were answered as recommended (DESIGN D123). The first components, `Http` (D125) and `Database` (D126), came through it in v0.5; the rest is design.

[한국어](COMPONENT_CHANNEL.ko.md)

How abilities from outside GuBASIC, Dart and Flutter packages, come in as GuBASIC components (DESIGN D121 c).

## Why

Visual Basic let a program call any function of a Windows library with `Declare` ([Microsoft](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/declare-statement)). It was what made VB programs able to do what VB itself could not, and also where they broke: the declarations were written by hand, a wrong type crashed the program, and nothing outside Windows had the same libraries. GuBASIC wants the first part without the second: one official way, with types, that works on every platform GuBASIC runs on.

## What there is today

- Every control is a component described by `components/NAME/component.yaml` (hard rule 7): its properties, methods and events. The analyzer, the IDE's toolbox and the Properties window read it.
- What a control does is written in Dart in two places: the interpreter (`gubasic_lang`) and the widgets (`gubasic_runtime`). Non-visual objects such as `File`, `Csv` and `PdfDocument` are built into the language.
- **The channel's first component, `Http` (v0.5, D125):** `components/Http/component.yaml` says `object: true`, a built-in object used by its name, and names its `platforms`. The interpreter asks its host (`ComponentHost.createComponent`) for an instance and talks to it through `ComponentInstance`: `getProperty`, `setProperty`, `call`, `assign`, GuBASIC's values on both sides, and a `ComponentProblem` with an R code for what goes wrong. The component's own code (`HttpComponent`) is pure Dart in `gubasic_lang`; the sending is a subclass where the program runs: the player's on package:http, the tests' from a script. The interface is not public yet (question 3).
- **The second, `Database` (v0.5, D126):** the same channel over package:sqlite3, and the first component that wraps a package: `component.yaml` says `ParamArray values As Value` for the values after the SQL, the runtime's `GbSqlite` holds the package (the desktop's library from its build hooks, the web's WebAssembly loaded only when used), and the platform-neutral part, `DatabaseComponent`, is pure Dart in `gubasic_lang`.
- Exported apps are a prebuilt player with the project put into it (D80). The player carries only the Dart code compiled into it.

## The design

A component that wraps a package is three things in one folder:

1. **`component.yaml`**, as today, plus the package it needs (`package: sqlite3: ^2.0.0`) and the platforms it runs on (`platforms: [web, macos, windows]`).
2. **An adapter in Dart** that implements one small interface, the same for the interpreter and for the transpiled code later: make an instance, get and set a property, call a method, and tell GuBASIC about an event through a callback. The adapter turns GuBASIC's values (Integer, Double, String, Boolean, Date, Table, …) into the package's types and back, so that a wrong type is caught by the analyzer from `component.yaml`, not at run time.
3. **Documents and an example**: the component's page in the reference, and its lines in `llms.txt` (D121 d).

The analyzer, the toolbox and the IDE treat it as any built-in control; a program cannot tell the difference.

## The constraint: a prebuilt player carries only what is compiled in

An interpreter cannot load a Dart package at run time, and neither can the prebuilt player. So a component reaches an app in one of three ways:

| Route | How | When |
|---|---|---|
| **Built in** | GuBASIC itself ships the component through the channel: compiled into the IDE and the players. | Components many programs need: `Http`, `Database` (SQLite), `WebSocket`, `Room`, game tools. The first users of the channel, so that it is tested by GuBASIC's own components |
| **Built for the project** | The project names a package that GuBASIC does not ship; a build compiles it in: the transpiler's native build (D79, D95), or a player built by CI with that component. | Packages one project needs. Comes with the transpiler |
| **Loaded later, on the web** | A built-in component that is large is compiled as a deferred library and loaded only by a program that uses it ([Dart](https://dart.dev/language/libraries#lazily-loading-a-library)). | Keeps the web player small, as the PDF font is kept out of apps that do not use it (D117) |

## The steps it suggests

1. **v0.5:** write `Http` (done, D125) and `Database` (done, D126) as components through the adapter interface, not as more built-in objects. The interface is then proved by GuBASIC's own components.
2. **v0.6:** `WebSocket` and `Room` the same way, the first components with events: an instance reports an event through a callback and the interpreter runs its handler in turn, as for a Timer tick (D136).
3. **With the transpiler:** the "built for the project" route, and a guide "How to wrap a package as a GuBASIC component".
4. **UserControl** (IDEAS) is the other half: a component made of GuBASIC controls and code, where this one is made of Dart. Both end in the same toolbox.

## Rules that come with it

- A component that needs a key or a secret warns, and never puts it into an app (hard rule 12).
- A component lists its platforms; the analyzer says when a program uses one on a platform it does not support, before the export, not after.
- The package's licence goes into the open source licences (D120).

## Questions for the author (answered as recommended, D123)

1. Should `Http` and `Database` in v0.5 be the first components through the channel (recommended), or built in first and moved later?
2. For the "built for the project" route before the transpiler: is a player built by CI for one project worth it (it needs a GitHub account and a wait), or should it wait for the transpiler (recommended)?
3. Should the adapter interface be public from the start, so that others can write components, or only once the "built for the project" route exists (recommended: then)?

# GuBASIC

**A Visual Basic–style RAD tool, built with Flutter™.**
Draw your interface, double-click a control, write a few lines of BASIC — and ship it to macOS, Windows, iOS, Android and the web.

[한국어](README.ko.md)

> **Status: stage 1 complete** (v0.1.0, a development build). Draw a form, double-click a control, write BASIC and press F5, all inside the IDE, with no Flutter installed. Building your own apps for each platform (the transpiler) is [stage 2](docs/ROADMAP.md).
>
> - **Web IDE:** https://kooboom.github.io/gubasic/ide/ (also as an app for macOS and Windows: [apps/ide](apps/ide))
> - **Playground:** https://kooboom.github.io/gubasic (the language on its own, for development)
>
> **What you can do now**
> - Draw forms with `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox` and `Image`, set their properties in the Properties window, and use `Anchor` and the phone, tablet and desktop sizes.
> - Double-click a control to write its event handler. The code editor colours the code, completes names and closes blocks.
> - Press F5 to run the app in the IDE. Errors are explained in English or Korean, and a click goes to the line.
> - Keep projects in the browser, or as folders on macOS and Windows, and download them as `.zip`. Start from the examples: hello, quiz and typing.
>
> **Known limits:** your apps cannot be built yet (stage 2); a project has one form; the macOS and Windows apps are unsigned development builds, and the Windows app has been checked only by CI builds and widget tests. The full list: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).

---

## Why

Classic Visual Basic had a workflow nobody has really replaced:

1. Drag a button onto a form.
2. Set its caption in the Properties window.
3. Double-click it.
4. Write `Label1.Caption = "Hello"` inside `Command1_Click`.
5. Press F5.

Modern cross-platform toolkits are far more powerful, but that *draw → double-click → write → run* loop is gone. GuBASIC brings it back, on a Mac first, and uses Flutter underneath so the same project can be released on every major platform.

GuBASIC is also a deliberately fun project: it is a language, an interpreter, a transpiler and an IDE built by one person for the joy of building tools that build things.

## How it works (in one picture)

```
 ┌───────────────────────── GuBASIC IDE (Flutter desktop app) ─────────────────────────┐
 │  Form designer  →  form.yaml          Code editor  →  .gbas (BASIC)                 │
 │                          │                                │                          │
 │                          └──────────────┬─────────────────┘                          │
 │                                   parser → AST                                       │
 │                          ┌──────────────┴─────────────────┐                          │
 │                   Interpreter (F5)                 Transpiler (Build)                │
 │                runs instantly inside              generates a Flutter project        │
 │                     the IDE                       → macOS / Windows / iOS /          │
 │                                                     Android / Web                    │
 └──────────────────────────────────────────────────────────────────────────────────────┘
```

- **While developing**, press F5: the interpreter runs your app inside the IDE immediately. No Flutter installation needed.
- **When releasing**, the transpiler turns your BASIC into Dart and builds a native app with Flutter.

## A taste of the language

```vb
Dim clickCount As Integer

Sub Form_Load()
    lblMessage.Caption = "Press the button"
End Sub

Sub btnHello_Click()
    clickCount = clickCount + 1
    Dim name = InputBox("What is your name?")
    MsgBox("Hello, " & name & "! (" & clickCount & ")")
End Sub
```

No `await`, no widgets, no build context. Just events and code, the way it used to be. The same program, with its form, is in [examples/hello](examples/hello).

## Documents

| Document | What it covers |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Architecture and every design decision, with the reasons |
| [docs/LANGUAGE.md](docs/LANGUAGE.md) | Draft specification of the GuBASIC language |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Stages, milestones and what 1.0 will *not* do |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Problems deliberately left unfixed for now, and when they will be revisited |
| [CLAUDE.md](CLAUDE.md) | Rules for AI coding assistants working on this repo |

## Platforms

| | Develop on | Release to |
|---|---|---|
| macOS | ✅ (primary) | ✅ |
| Windows | ✅ | ✅ |
| iOS | — | ✅ (requires a Mac, Xcode and an Apple Developer account) |
| Android | — | ✅ |
| Web | — | ✅ |

## How GuBASIC is built

GuBASIC is designed and directed by **Jungmo Gu**. AI coding assistants (Claude) help draft documents and code; every change is reviewed by the author. AI-assisted commits carry a `Co-Authored-By` line, so the history shows exactly where AI was involved.

Building a language and an IDE together with an AI is part of the fun of this project, and part of what it records.

## License

MIT — see [LICENSE](LICENSE). © 2026 Jungmo Gu

## Trademarks and affiliation

GuBASIC is an independent personal project. It is **not affiliated with, endorsed by, or sponsored by Microsoft or Google**.

- Visual Basic is a trademark of Microsoft Corporation. "Visual Basic–style" describes the programming workflow GuBASIC is inspired by.
- Flutter and the related logo are trademarks of Google LLC. GuBASIC is built with the Flutter SDK.

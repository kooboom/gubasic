# Form

[All of the reference](../README.md)

The form a program's controls sit on (docs/DESIGN.md §5). Width and Height are the size of the area inside the window. Resize runs when it changes, and once when the form is first shown (D58). Integer properties are 32-bit (min and max narrow that); a value outside is a run-time error (R007) or, in a form file, F012. A project's forms are shown one over another (docs/DESIGN.md D88): Show puts the form in front, ShowDialog puts it in front as a dialog and waits until it goes, Hide takes it away keeping its values, Close takes it away and starts it again the next time it is shown. Closed runs after Close.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Load`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Width` | Integer | `480` |  |
| `Height` | Integer | `360` |  |
| `FontSize` | Double | `(not set)` | not set: its Frame's or its form's |
| `FontBold` | Boolean | `(not set)` | not set: its Frame's or its form's |
| `ForeColor` | Color | `(not set)` | not set: its Frame's or its form's |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |
| `KeyPreview` | Boolean | `False` |  |
| `DialogResult` | Integer | `0` | set only while the program runs |

## Methods

- `Show()`
- `ShowDialog() As Integer`
- `Hide()`
- `Close()`
- `PopupMenu(menu As Menu)`

## Events

- `Load()`
- `Resize()`
- `Closed()`
- `KeyDown(e As KeyEventArgs)`
- `KeyUp(e As KeyEventArgs)`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `text` → `Caption`

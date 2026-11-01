# SaveFileDialog

[All of the reference](../README.md)

The dialog that asks for a file to save to (docs/DESIGN.md D113), as Visual Basic .NET's SaveFileDialog. Not seen on the form: the designer keeps it in the tray. ShowDialog() shows it and gives DialogResult.OK with the file in FileName, after FileOk has run, or DialogResult.Cancel. Filter is "Text files|*.txt|All files|*.*": a label and its patterns, in pairs. On the web FileName is the file's name, which the File functions take in the same run; saving downloads the file under it.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Not seen on the form: kept in the designer's tray.

Default event (made by a double-click): `FileOk`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Title` | String | `""` |  |
| `Filter` | String | `""` |  |
| `FileName` | String | `""` |  |
| `Tag` | String | `""` |  |

## Methods

- `ShowDialog() As Integer`

## Events

- `FileOk()`

## Names other versions of BASIC use

- `index` → `Tag`

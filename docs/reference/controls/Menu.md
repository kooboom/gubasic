# Menu

[All of the reference](../README.md)

An item of a form's menu bar (docs/DESIGN.md D106), made in the menu editor and written under menus: in the form file. A menu with items in it opens them; an item without opens nothing and raises Click. A Caption of "-" is a line between items. Ctrl in a Shortcut is the Command key on macOS. Not seen on the form: the window draws the menu bar, or on macOS the system's menu bar does.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Checked` | Boolean | `False` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `Shortcut` | String | `""` |  |
| `Tag` | String | `""` |  |

## Events

- `Click()`

## Names other versions of BASIC use

- `index` → `Tag`
- `text` → `Caption`

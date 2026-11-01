# Timer

[All of the reference](../README.md)

A Timer runs its Tick every Interval milliseconds while Enabled (docs/DESIGN.md D82, D100). It is not seen on the form: the designer keeps it in a tray under the form, so it has no place or size. A tick is an event like a click: it does not re-enter, and waits while another handler runs. Start and Stop set Enabled.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Not seen on the form: kept in the designer's tray.

Default event (made by a double-click): `Tick`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Interval` | Integer | `100` |  |
| `Enabled` | Boolean | `False` |  |
| `Tag` | String | `""` |  |

## Methods

- `Start()`
- `Stop()`

## Events

- `Tick()`

## Names other versions of BASIC use

- `timer` → `Tick`

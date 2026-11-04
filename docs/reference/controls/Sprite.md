# Sprite

[All of the reference](../README.md)

A picture that moves (docs/DESIGN.md D138): a game's ship, shot or enemy. Frames names the project's pictures it is drawn from, separated by commas; Frame is the one shown, from 0, and with FrameTime above 0 Move turns them one after another. X and Y are where it is, with fractions, Left and Top the same place rounded down; SpeedX and SpeedY are pixels a second, and Move(ms) moves it by them, nothing moving by itself. The frame is drawn filling Width and Height. Drawn under the other controls, like an Image; what is behind shows through its transparent pixels. Hits(other) says whether two sprites touch, by their Shape: Rectangle, Circle or Pixels; DistanceTo(other) is the distance between their centres.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Frames` | String | `""` |  |
| `Frame` | Integer | `0` |  |
| `FrameTime` | Integer | `0` |  |
| `X` | Double | `0.0` | set only while the program runs |
| `Y` | Double | `0.0` | set only while the program runs |
| `Shape` | String | `"Rectangle"` |  |
| `SpeedX` | Double | `0.0` |  |
| `SpeedY` | Double | `0.0` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `32` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `Tag` | String | `""` |  |

## Methods

- `Move(ms As Integer)`
- `Hits(other As Sprite) As Boolean`
- `DistanceTo(other As Sprite) As Double`

## Events

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `index` → `Tag`
- `picture` → `Frames`

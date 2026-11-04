# Sprite

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Click`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Frames` | String | `""` |  |
| `Frame` | Integer | `0` |  |
| `FrameTime` | Integer | `0` |  |
| `X` | Double | `0.0` | 실행 중에만 정함 |
| `Y` | Double | `0.0` | 실행 중에만 정함 |
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

## 메서드

- `Move(ms As Integer)`

## 이벤트

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `index` → `Tag`
- `picture` → `Frames`

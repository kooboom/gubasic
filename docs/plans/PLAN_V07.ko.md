# 계획서: v0.7 "게임 도구" — Sprite, 충돌 검사, 소리, 동시에 누른 키, 밀리초, 슈팅 게임

[English](PLAN_V07.md)

[PLAN_TEMPLATE.ko.md](../PLAN_TEMPLATE.ko.md)의 형식입니다. DESIGN D121(돌아가지 않기: 게임은 게임을 보통 만드는 방식대로 만들 수 있어야 함), D100(Timer), D101(폼의 키), D51(그림), D98과 D132(객체로서의 컨트롤, `New … With`), D137(`Visible`), 그리고 STAGE2_PLAN §7이 Galaga 같은 게임을 재면서 알아낸 것(2단계 너머에 그런 게임이 필요로 하는 것은 동시에 누른 키, 소리, 차례로 바뀌는 그림, 밀리초 단위 시간, 충돌 도움)에 기댑니다. 구현 전에 쓴 계획서이고, 6절에 작성자에게 묻는 질문을 권장안과 함께, 7절에 2026-11-04 작성자의 답을 모았습니다. 답은 DESIGN D138이 기록합니다.

## 1. 무엇을, 왜

**사용자가 할 수 있게 되는 것.** 폼에 `Sprite`를 그리고 프레임(프로젝트의 그림), 속도, 모양을 주고, Timer 하나의 `Tick`에서 모두 움직이고, 지금 어떤 키가 눌려 있는지 묻고, 두 스프라이트가 닿았는지 묻고, 소리를 냅니다. 작은 게임의 정석(Timer 하나의 게임 루프, 물체마다 상태, 적이 나오는 시간표)을 다른 곳에서 쓰듯 GuBASIC으로 쓰고, `Image` 하나와 변수 둘로 스프라이트를 흉내 내거나 `KeyDown`·`KeyUp`과 플래그로 누른 키를 흉내 내지 않습니다.

가장 작은 예(키를 누르는 동안 움직이고 적에게 쏘는 우주선):

```vb
Dim lastTime As Integer

Sub Form_Load()
    sprShip.Y = Me.Height - 60
    lastTime = Milliseconds()
    tmrGame.Start()
End Sub

Sub tmrGame_Tick()
    Dim dt As Integer = Milliseconds() - lastTime      ' 지난 라운드부터 흐른 시간
    lastTime = Milliseconds()
    sprShip.SpeedX = 0
    If Keyboard.IsDown(Keys.Left) Then sprShip.SpeedX = -200
    If Keyboard.IsDown(Keys.Right) Then sprShip.SpeedX = 200
    If Keyboard.IsDown(Keys.Space) And Not sprShot.Visible Then
        sprShot.X = sprShip.X + 12 : sprShot.Y = sprShip.Y
        sprShot.Visible = True
        Sound.Play("shot.wav")
    End If
    sprShip.Move(dt)
    sprShot.Move(dt)
    sprEnemy.Move(dt)
    If sprShot.Hits(sprEnemy) Then
        sprShot.Visible = False
        sprEnemy.Frames = "boom1.png, boom2.png, boom3.png"   ' 폭발: 프레임이 차례로
        Sound.Play("hit.wav")
    End If
End Sub
```

`tmrGame`은 `Interval`이 16인 Timer이고, `sprShot`은 `SpeedY` -400, `Visible` False로 시작하며, `sprEnemy`는 `FrameTime`이 120이라 움직이는 동안 프레임이 저절로 바뀝니다.

**단계.** ROADMAP v0.7 "게임 도구"(후보, D121 a). v0.7이 끝나면 **Shooter** 예제(2.6절)가 있고, v0.7 목록은 모두 체크됩니다. 6절 Q9가 바로 다음 변경으로 권한 격투 게임은 v0.7.0 공개 전 작성자의 말로 ROADMAP의 다음 후보가 되었습니다(D138).

**왜 지금인가.** v0.6은 "함께 쓰기"를 가능하게 했습니다. 작성자가 D121에서 이름 붙인 다른 한 종류, 슈팅 게임과 격투 게임은 아직 도구를 돌아서 씁니다. STAGE2_PLAN의 Galaga 벤치마크는 좌표 배열로 `Image` 61개를 움직이고 겹침을 비교 여덟 번으로 검사하며, 누른 키를 알지 못하고 소리도 없습니다. 이 계획서의 모든 것이 그 프로그램이 돌아가야 했던 것입니다.

## 2. 어떻게 쓰는가

### 2.1 `Sprite` 컨트롤

폼에 보이는 컨트롤로, `Image`처럼 다른 컨트롤 아래에 그립니다(`layer: graphic`). 이름은 Visual Basic .NET에 있는 것은 그것을, 없던 것은 GuBASIC의 것을 씁니다. 디자이너에 놓거나 `New Sprite`와 `Me.Controls.Add`로 만듭니다(§11.4). 게임이 적 스무 개를 만드는 방법입니다.

| 멤버 | 하는 일 |
|---|---|
| `Frames` (`String`) | 프레임이 되는 프로젝트 그림들의 이름을 쉼표로 나눠 적음: `"enemy1.png, enemy2.png"`. 이름 하나면 멈춘 스프라이트, `""`이면 아무것도 그리지 않음. 프로젝트에 없는 그림 이름: 코드에 글자로 적으면 A037, 실행 중엔 R013, 폼 파일이면 F016. 지금의 `Picture`와 같음 |
| `Frame` (`Integer`, 처음 0) | 보이는 프레임. 배열처럼 0부터 셈(규칙 10). 0에서 마지막 사이를 벗어나면 R051. `Frames`를 바꾸면 0으로 돌아감 |
| `FrameTime` (`Integer`, 밀리초, 처음 0) | 0보다 크면 `Move`가 `FrameTime` 밀리초마다 프레임을 차례로 넘기고 마지막 다음은 처음으로 돌아감. 0이면 프로그램이 `Frame`을 직접 정함 |
| `X`, `Y` (`Double`) | 왼쪽 위 모서리가 폼(또는 Frame)의 왼쪽 위에서 몇 픽셀인지, 소수 포함. 초당 30픽셀의 속도가 16 ms 라운드에 정확히 0.5픽셀 움직이게 함. 모든 컨트롤에 있는 `Left`·`Top`(`Integer`)은 같은 자리를 반올림한 것이고, 어느 하나를 정하면 나머지도 정해짐 |
| `SpeedX`, `SpeedY` (`Double`, 초당 픽셀, 처음 0) | `Move`가 얼마나 빨리 움직이는지. 라운드당이 아니라 초당 픽셀이어야 초당 30라운드와 60라운드에서 게임이 같음 |
| `Width`, `Height` (`Integer`) | 프레임을 여기에 꽉 채워 그림(`Image`의 `Stretch`처럼). 속성 창에서 `Frames`를 처음 고를 때 첫 프레임의 크기를 받고, 실행 중엔 프로그램 말고는 아무것도 바꾸지 않음 |
| `Shape` (`String`, 처음 `"Rectangle"`) | `Hits`가 무엇으로 보는지: `"Rectangle"`은 사각형 전체, `"Circle"`은 사각형에 들어가는 가장 큰 원(정사각형이 아니면 타원), `"Pixels"`는 프레임에서 알파가 128 이상인 픽셀을 크기에 맞춰 늘린 것. 다른 낱말은 코드에서 A081, 실행 중 R052, 폼 파일에서 F024 |
| `Anchor`, `Enabled`, `Visible`, `Tag` | 모든 컨트롤과 같음(D57, D137, D98). `BackColor`는 없음: 투명한 픽셀로는 뒤가 비침 |
| `Move(ms As Integer)` | 속도로 `ms` 밀리초만큼 움직이고(`X = X + SpeedX * ms / 1000`, `Y`도), `FrameTime`이 0보다 크면 프레임을 넘김. 저절로 움직이는 것은 없음: 프로그램의 루프가 말할 때만 움직임. 그래야 프로그램이 결정적이고 동일성 테스트가 가능함 |
| `Hits(other As Sprite) As Boolean` | `other`와 닿았는지, 둘의 모양으로. 어느 쪽이든 `Visible`이 아니거나 같은 스프라이트면 `False`. 사각형과 사각형, 원과 원, 원과 사각형은 계산으로; 어느 쪽이든 `"Pixels"`면 두 사각형이 겹치는 부분을 픽셀마다 상대의 모양과 견줌 |
| `DistanceTo(other As Sprite) As Double` | 중심 사이의 거리. 유도탄과 "가까우면" 검사용 |
| 이벤트 `Click`, `MouseDown(e)`, `MouseUp(e)` | `Image`와 같음(D111): 스프라이트도 클릭할 수 있는 것 |

다른 BASIC은 무엇이라 부르나: Visual Basic 6에는 스프라이트가 없었습니다. 게임은 `Timer`로 `Image`나 `PictureBox`를 옮기고 `Declare`로 키를 물었는데([Microsoft](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/declare-statement)), GuBASIC에는 `Declare`가 없습니다(D121 c: 패키지는 컴포넌트로 들어옴). 움직이지 않는 그림에는 `Image`가 그대로 있고, `Sprite`의 어떤 것도 가리켜 줄 이름이 필요 없습니다.

### 2.2 `Keyboard.IsDown`

`Debug`와 `Color`처럼 내장 객체이고 함수 하나가 있습니다.

| 멤버 | 하는 일 |
|---|---|
| `Keyboard.IsDown(key As Integer) As Boolean` | 그 키가 지금 눌려 있는지. `key`는 `Keys` 값(D101): `Keyboard.IsDown(Keys.Left)`. 여러 키가 동시에 눌려 있을 수 있고, 그것이 요점. 이벤트가 아니라 질문이라 핸들러를 기다리지 않고, 다시 들어가지 않으며, 사용자에게 아무것도 묻지 않음. 폰(3단계)에서는 늘 `False` |
| `Keys.ShiftKey`, `Keys.ControlKey`, `Keys.Menu` | Shift, Control, Alt를 발사나 점프 키로 쓸 수 있도록 더함. Visual Basic .NET의 이름과 숫자(16, 17, 18; [Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.keys)). 여전히 혼자서는 `KeyDown`·`KeyUp`을 일으키지 않음(D101): `IsDown`만 앎 |

무엇인가: 인터프리터는 호스트가 알려 주는 `KeyDown`·`KeyUp`에서, 이벤트로 줄을 서기 전에, 눌린 키의 집합을 유지합니다. 그래서 폼의 핸들러가 돌았든 아니든 `KeyDown`부터 `KeyUp`까지 `IsDown`이 참이고, `TextBox`에 포커스가 있고 `KeyPreview`가 꺼져 있어도 그렇습니다(이벤트가 아니라 상태). 창이 포커스를 잃거나 대화 상자가 열리면 호스트가 "모든 키가 떼어짐"을 알려, Alt+Tab이나 `MsgBox` 뒤에 키가 "눌린 채" 남지 않습니다. 동일성 대본에서는 `KeyDown`을 움직이는 같은 줄이 이것도 움직입니다: `Form.KeyDown Left`로 참, `Form.KeyUp Left`로 거짓.

Visual Basic 6이 `Declare`로 부르던 `GetAsyncKeyState`를 이것이 대신합니다. GuBASIC에는 `Declare`가 없고 지금은 파서가 모르는 문장으로 보고하는데, P042가 이름을 붙입니다: 패키지는 컴포넌트로 들어오고(COMPONENT_CHANNEL), 선언한 이름이 `GetAsyncKeyState`나 `GetKeyState`면 지금 눌린 키는 `Keyboard.IsDown`으로 묻는다고 덧붙입니다.

### 2.3 `Milliseconds()`

| 함수 | 주는 것 |
|---|---|
| `Milliseconds() As Integer` | 프로그램이 시작한 뒤 흐른 밀리초. 앞으로만 가는 시계(벽시계가 아니라 스톱워치)라 컴퓨터의 시각을 바꿔도 게임이 튀지 않음. `Integer`는 정확하므로(D26) 넘치지 않음 |

게임 루프는 `Tick`마다 맨 위에서 이것을 읽고 차이를 `Move`에 줍니다(1절). 그러면 Timer가 초당 60라운드를 해냈든 40라운드를 해냈든 게임이 같습니다. Visual Basic 6의 `Timer` 함수(자정부터의 초)와 Visual Basic .NET의 `Environment.TickCount`는 여기로 가리킵니다(A080): GuBASIC에서 `Timer`는 컨트롤의 이름입니다.

동일성 대본은 새 줄 `Wait 16`(밀리초)으로 틱 사이에 시계를 앞으로 돌립니다. 가짜 호스트의 시계는 그 줄에서만 움직이므로 `.out`이 어느 기계에서나 같습니다.

### 2.4 `Sound`

프로젝트의 소리를 가진 내장 객체입니다. 소리는 그림처럼(§11.3) 프로젝트의 `sounds/` 폴더에 있는 파일이고 `.gbproj`에 적힙니다.

| 멤버 | 하는 일 |
|---|---|
| `Sound.Play(name)` | 효과음을 한 번, 바로 냄. 여럿이 겹쳐 나고, 같은 소리가 나는 중에 `Play`하면 그 위에 다시 시작함. 프로젝트에 없는 소리 이름: 코드에 글자로 적으면 A082, 실행 중엔 R053 |
| `Sound.PlayMusic(name)` | 소리 하나를 `StopMusic`, 프로그램 끝, 또는 다른 `PlayMusic`이 바꿀 때까지 되풀이함. 한 번에 하나 |
| `Sound.StopMusic()` | 멈춤 |
| `Sound.Volume` (`Integer`, 0에서 100, 처음 100) | 프로그램이 내는 모든 소리에. 범위 밖은 R010 |

**형식:** WAV와 MP3만(`.wav`, `.mp3`). 둘 다 웹 플레이어가 도는 모든 브라우저와 Windows, macOS에서 나고, OGG는 Safari에서 나지 않습니다([MDN: Web audio codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs#choosing_an_audio_codec)). 다른 확장자는 그림의 F014처럼 F024, 대소문자만 다른 두 이름은 F015처럼 F025.

**웹에서는** 사용자가 페이지를 클릭하거나 키를 누르기 전에는 소리를 낼 수 없습니다([Chrome의 autoplay 정책](https://developer.chrome.com/blog/autoplay)). 그 전의 `Play`는 오류 없이 버려집니다. LANGUAGE와 참조가 그렇게 말하고 이유도 말합니다: GuBASIC이 아니라 브라우저의 규칙이고, 데스크톱에서 쓴 프로그램이 웹에서도 돌게 하려는 것입니다. Shooter처럼 시작 버튼을 눌러야 비로소 시작하는 게임은 이것을 만나지 않습니다.

**프로젝트 파일.** `sounds:`에 적습니다. 소리가 있는 프로젝트는 `formatVersion: 4`로 쓰고, 옛 GuBASIC은 아무 소리도 안 내는 대신 열기를 거부합니다(규칙 8; `pictures`가 2로, 모듈이 3으로 한 것처럼, D102). 3을 4로 읽는 데 이행기는 필요 없습니다: `sounds`는 더해질 뿐입니다.

### 2.5 진단(초안)

번호는 그때의 마지막(A079, R050, F023, P041) 다음이었습니다. **구현에서는** 이 초안과 다릅니다: 모양이 아닌 낱말이 A081(코드), R052(실행 중), F024(폼 파일)를 가져가서, 프로젝트에 없는 소리는 R053, 소리의 이름은 F025, 대소문자만 다른 두 이름은 F026입니다. 범위 밖 `Volume`은 다른 속성처럼 R010입니다. `Beep` 안내는 A083, 소리 API의 `Declare`는 P044가 되었고 v0.7.0 다음에 더했습니다. `My.Computer.Audio.Play`는 안내하지 않습니다(DESIGN D138). 한국어는 문서의 "~합니다" 체이고, 자리 표시자 바로 뒤에 조사를 붙이지 않습니다.

| 코드 | 언제 | 영어 | 한국어 |
|---|---|---|---|
| A080 | 함수로 쓴 `Timer()`나 `Environment.TickCount` | `Timer` is a control in GuBASIC; the time in milliseconds is `Milliseconds()`. | GuBASIC에서 `Timer`는 컨트롤입니다. 밀리초 단위 시간은 `Milliseconds()`입니다. |
| A081(구현: A083, `Beep`만) | `Beep`, `PlaySound`, `My.Computer.Audio.Play` | Write `Sound.Play("NAME.wav")` with a sound of the project. | 프로젝트의 소리로 `Sound.Play("NAME.wav")`라고 씁니다. |
| A082 | 프로젝트에 없는 소리로 `Sound.Play("x.wav")`(그림의 A037처럼) | `{0}` is not a sound of this project. Add it to the project's sounds first. | `{0}` 소리가 이 프로젝트에 없습니다. 먼저 프로젝트의 소리에 더합니다. |
| P042 | `Declare` 문. `GetAsyncKeyState`나 `GetKeyState`면 둘째 문장까지 | GuBASIC has no `Declare`: outside abilities come as components. Keys held right now are asked with `Keyboard.IsDown(Keys.Left)`. | GuBASIC에는 `Declare`가 없습니다. 바깥의 기능은 컴포넌트로 들어옵니다. 지금 눌린 키는 `Keyboard.IsDown(Keys.Left)`로 묻습니다. |
| R051 | 0에서 마지막 프레임 사이를 벗어난 `Frame` | `Frame` must be from 0 to {0}; it is {1}. | `Frame` 값은 0에서 {0} 사이여야 하는데 {1}입니다. |
| R052 | 실행 중 프로젝트에 없는 소리 | There is no sound named {0} in this project. | 이 프로젝트에 {0} 소리가 없습니다. |
| F024 | 소리가 가질 수 없는 이름 | A sound is a `.wav` or `.mp3` file whose name has none of `/ \ : * ? " < > \|`: {0}. | 소리는 이름에 `/ \ : * ? " < > \|`가 없는 `.wav`나 `.mp3` 파일입니다: {0} |
| F025 | 대소문자만 다른 두 소리 | Two sounds cannot have the same name in different cases: {0} and {1}. | 대소문자만 다른 같은 이름의 소리를 둘 둘 수 없습니다: {0}, {1} |

### 2.6 Shooter 예제

`examples/shooter`, 480×640 폼 하나, 조작은 키보드. 정석을 차례로 보이고 주석이 가르칩니다.

- **Timer 하나의 게임 루프**(`tmrGame`, `Interval` 16): `Milliseconds()`를 읽고, 키를 읽고, 모두 움직이고, 충돌을 검사하고, 점수를 그림.
- **물체마다 상태:** 우주선, 탄 열 개, 적 스무 개는 `Form_Load`에서 `New Sprite With {.Frames = "enemy1.png, enemy2.png", .FrameTime = 150, .Visible = False}`로 만들어 배열(`Dim enemies(19) As Sprite`)에 둠. `Visible`이 살아 있는지를 말함.
- **적이 나오는 시간표:** `At`(밀리초), `Lane`, `Kind`가 있는 `Structure Wave`의 배열을 `Form_Load`에서 채우고, 루프는 `Milliseconds()`가 다음 `At`을 지나면 그 웨이브를 시작함.
- **소리:** `shot.wav`와 `hit.wav`; 시작 버튼 뒤에 `PlayMusic`으로 `music.mp3`(웹의 규칙, 2.4절).
- **폭발**은 `Frames`가 그림 셋이고 `FrameTime`이 80인 스프라이트. 마지막 프레임이 보이고 나면 `Visible = False`.
- 점수와 목숨은 Label에, Game Over. **시작 버튼을 누르기 전에는 아무것도 움직이지 않고 소리도 나지 않음:** `Form_Load`는 준비만 하고 Timer는 `btnStart_Click`에서 시작하며, 그것이 웹 페이지가 소리를 낼 수 있게 하는 클릭이기도 함(2.4절). Game Over 뒤에는 같은 버튼으로 다시 시작. 폰에는 키가 없음: 예제는 키보드가 있는 데스크톱과 웹용이라고 말함.

그림과 소리는 LiveQuiz의 그림처럼 도구 스크립트가 만듭니다(`apps/ide/tool/draw_quiz_pictures.dart`): 단순한 도형과, WAV로 합성한 소리(짧은 사각파와 잡음 한 토막). 바깥에서 오는 파일이 없고 라이선스가 걸리는 것이 없습니다.

## 3. 설계

### 3.1 어디에 두나

- **`components/Sprite/component.yaml`**, `tool/embed_components.dart`가 묻음. `Frames`는 `picture: true`가 여러 이름을 뜻하는 `String`(속성 창의 선택기가 여럿을 고르게 하고 글자로 씀); `X`, `Y`, `SpeedX`, `SpeedY`는 component.yaml에 이미 있는 `Double`; `Shape`는 `Anchor`처럼 글자.
- **`gubasic_lang`**(순수 Dart, 규칙 1):
  - 분석기의 `Sprite`, `Keyboard`, `Sound`, `Milliseconds` 멤버와 A080~A083, P042~P044;
  - 인터프리터: `Move`, 눌린 키의 집합, `Host.milliseconds`에서 오는 `Milliseconds`, `FileHost` 옆의 `SoundHost`(`play`, `playMusic`, `stopMusic`, `volume`)를 거치는 `Sound`. 플레이그라운드에는 없음(`Http`처럼 R038);
  - **`lib/src/forms/collision.dart`:** `Hits`와 `DistanceTo`의 기하(사각형, 원, 픽셀)를 순수 Dart로. 픽셀 마스크는 `FormHost.pictureMask(name)`에서: 너비, 높이, 알파 ≥ 128인 픽셀마다 비트 하나. 순수여야 동일성 테스트가 VM과 Chrome에서 돌고, 트랜스파일러가 만든 코드도 같은 파일을 쓸 수 있음;
  - 프로젝트 파일: `sounds`, `formatVersion: 4`, F025와 F026;
  - 이벤트 대본: `Wait N`.
- **`gubasic_runtime`:** `sprite.dart`는 프로젝트의 그림(`Image`가 쓰는 같은 바이트)으로 프레임을 늘려 그림; `picture_mask.dart`는 그림을 한 번 디코드해(`instantiateImageCodec`, raw RGBA의 `toByteData`) 인터프리터가 묻는 마스크를 만들고 이름으로 캐시; `sound.dart`의 `GbSound`는 6절 Q5의 패키지 위에서 프로젝트가 준 바이트를 냄; `form_view.dart`는 이미 `KeyDown`·`KeyUp`을 알리듯 폼이 포커스를 잃거나 대화 상자가 열리면 "모든 키 떼어짐"을 알림. 런타임은 인터프리터와 생성된 앱이 쓰는 유일한 Flutter 코드로 남음(규칙 6).
- **`gubasic_player`:** 프로젝트 모델이 `pictures/`처럼 `sounds/`를 지님; 실행 창의 호스트가 `pictureMask`, `milliseconds`(프로그램과 함께 시작하는 `Stopwatch`), 소리 호출에 답함; 내보낸 앱의 번들과 웹 템플릿이 소리를 서비스함.
- **IDE:** 툴박스의 `Sprite`와 아이콘; 디자이너는 첫 프레임을 그리고(`Frames`가 비면 점선 상자); 속성 창의 `Frames` 선택기(그림 여럿, 순서대로); 프로젝트 탐색기의 "그림" 옆 "소리" 묶음과 더하기(`.wav`·`.mp3` 파일 대화 상자)·빼기; 웹 IDE는 그림처럼 소리도 브라우저에 보관(D53).
- **문서:** LANGUAGE §10(`Milliseconds`), §11.1(`Sprite`, `Keyboard`, `Keys.ShiftKey`…), §11.3(`sounds`, `formatVersion: 4`), 새 §11.13 `Sound`; `gen_reference.dart`의 참조와 `llms.txt`; 답을 담은 DESIGN D138; ROADMAP 체크; 4절이 남기는 것은 KNOWN_ISSUES.

### 3.2 하드 규칙과 열어 두는 것

- **AST 하나(규칙 2):** 문법에 새것은 없음. `Sprite`, `Keyboard`, `Sound`, `Milliseconds`는 `Http`와 `Color`처럼 분석기가 푸는 멤버와 내장 함수라, 트랜스파일러는 런타임으로 대응하는 호출로 만남.
- **비동기, 다시 들어가지 않음(규칙 4, 5):** `Move`, `Hits`, `IsDown`, `Milliseconds`는 도는 핸들러 안의 보통 호출이고 새 이벤트는 없음. `Sound.Play`는 기다리지 않음(루프가 도는 동안 소리가 남). 기다리지 않는 유일한 호출이고 6절 Q6이 이유를 말함.
- **런타임만(규칙 6):** 그리기, 디코드, 소리는 `gubasic_runtime`에; 기하는 인터프리터와, 나중에는 생성된 코드가 함께 부르는 순수 Dart.
- **모든 컨트롤은 컴포넌트(규칙 7):** `Sprite`는 `component.yaml`. `Keyboard`와 `Sound`는 폼에 자리가 없고 디자이너가 정하는 상태가 없으므로 `Debug` 같은 내장 객체이지 컨트롤이 아님.
- **파일 형식(규칙 8):** `sounds`가 더해지고, 소리가 있는 프로젝트만 `formatVersion`이 4로 감. 있던 것의 뜻은 바뀌지 않음.
- **비밀(규칙 12):** 새로 어디로 보내는 것 없음.
- **Galaga 벤치마크**(`test/bench/galaga`)는 인터프리터의 루프를 재므로 그대로 둠. Shooter 예제를 같은 방법으로 한 번 재어(STAGE2_PLAN §7의 기준) `Move`와 `Hits`가 대신하는 BASIC 줄보다 싼지 봄.

## 4. 돌아가지 않기(D121)

- **사용자가 여전히 돌아가야 하는 곳이 있나?** 나중으로 미루고 KNOWN_ISSUES에 적는 것: 스프라이트 회전(`Angle`)과 뒤집기(왼쪽을 보는 스프라이트는 당분간 두 번째 그림); 타일 맵이나 스크롤 배경(우선은 루프가 옮기는 넓은 `Image`); 조이스틱·게임패드; 점점 작아지는 음악; 3단계가 폰에서 해 보기 전의 폰 소리. 남기지 않는 것: STAGE2_PLAN §7이 Galaga 게임이 돌아갔다고 적은 모든 것.
- **바깥과 표준으로 이야기하나?** 그림은 전처럼 PNG, JPEG, GIF; 소리는 WAV([RFC 2361](https://www.rfc-editor.org/rfc/rfc2361), WAVE 형식의 등록)와 MP3(MPEG-1 Audio Layer III, [MDN](https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs)). 둘 다 위에 든 모든 브라우저와 데스크톱이 냄.
- **스스로 하지 않는 것이 들어올 길이 있나?** 컴포넌트 통로([COMPONENT_CHANNEL.ko.md](../COMPONENT_CHANNEL.ko.md)): 게임패드, 파티클, 물리 엔진 패키지는 트랜스파일러와 함께 컴포넌트로 들어옴. `Sprite` 자체가 컴포넌트.
- **문서와 예제:** 3.1절의 목록; Shooter 예제; FIRST_APP에 가리키는 한 줄; AI 보조 도구용 참조는 생성.

## 5. 테스트

- **동일성 프로그램**(`test/parity/`, VM·Chrome·실행 창): `sprite_move`(속도, `Move`, 소수 있는 `X`와 반올림한 `Left`, `Anchor`), `sprite_frames`(`Frames`, `Frame`, `FrameTime`, R051), `sprite_hits`(사각형, 원, 픽셀. 모서리가 투명한 작은 그림을 `sprite_hits.pictures/`에; `Visible` False; `DistanceTo`), `keyboard_isdown`(동시에 여러 키, 대화 상자에서 떼어짐, TextBox 안), `milliseconds`(`Wait` 줄, 틱 사이 차이), `sound_play`(`MsgBox`를 보이듯 기록에 `Sound: shot.wav`, `Music: music.mp3`, `Music stopped`; R053; 범위 밖 `Volume`), `shooter_example`(예제를 `Wait`·키·틱 대본으로 명중과 게임 오버까지).
- **`gubasic_runtime`:** 위젯 테스트: Sprite가 프레임을 늘려 그리고 `Frames`가 `""`이면 아무것도 안 그림; 모서리가 투명한 PNG의 마스크 비트가 기대대로; `GbSound`가 이름의 소리 바이트를 내라고 요청받음(가짜 플레이어); 포커스를 잃으면 "모든 키 떼어짐"을 알림.
- **`gubasic_player`:** 지금처럼 실행 창의 위젯으로 동일성 프로그램; 내보낸 번들이 `sounds/`를 지님.
- **IDE:** 툴박스의 Sprite, `Frames` 선택기, 소리 묶음과 대화 상자의 위젯 테스트; 통합 테스트(Windows와 macOS, CI에서)는 IDE 자기 창에서 Shooter 예제를 테스트가 보낸 키로 2초 돌리고, 가짜로 소리 호출을 듣고, 창의 그림을 남김(D119).
- **웹:** `tool/web_check/shooter.mjs`(Playwright)가 빌드한 웹 플레이어의 Shooter를 키보드로 하고, 점수가 바뀌는지와 첫 키 뒤에야 `AudioContext`를 만들었는지 확인. 이 PC에서는 `--channel chrome`.
- **손으로:** 맥과 Windows에서 작성자가 실제 키보드로 예제를 해 보고 움직임의 느낌과 소리의 지연을 봄.

## 6. 작성자에게 묻는 것

각각 권장안과 함께. 답은 DESIGN D138로 갑니다.

1. **새 `Sprite`인가, `Image`에 속성을 더하는가?** 권장: 새 컨트롤. `Image`는 업무 프로그램이 기대하는 것(스스로 크기를 바꾸지 않는 그림, 정수 위치)으로 남고, 소수 있는 `X`/`Y`, 속도, 프레임, 모양은 폼의 사진이 한 번도 쓰지 않을 속성 열둘입니다.
2. **`Frames`는 글자(`"a.png, b.png"`)인가, 선택기가 있는 목록인가?** 권장: `Anchor`처럼 글자, 속성 창이 그것을 써 주는 선택기를 내놓음. 프로그램이 `&`로 만들 수 있고, 폼 파일이 읽히고, 새 속성 형이 필요 없습니다.
3. **위치: 정수 `Left`/`Top` 옆에 `Double`인 `X`/`Y`?** 권장: 예. 초당 30픽셀의 스프라이트는 라운드에 반 픽셀을 가야 하는데 정수 `Left`만으로는 제자리에 섭니다. `Left`/`Top`은 다른 컨트롤용으로 쓴 모든 것을 위해 남습니다.
4. **충돌 모양: 스프라이트마다의 속성(`Shape`)인가, `Hits`의 인자인가?** 권장: 속성. 탄을 한 번 "Circle"로 두면 모든 `Hits`가 짧은 호출 하나입니다. 픽셀은 알파 ≥ 128일 때 세고, 안티에일리어싱 가장자리를 무시하는 보통의 문턱입니다.
5. **소리 패키지:** `audioplayers`(Windows, macOS, Linux, 웹, iOS, Android의 플러그인; MIT), `flutter_soloud`(FFI로 지연이 더 짧지만 웹에서 자기 WASM 파일과 스크립트가 필요해 웹 템플릿과 Pages 배포가 지녀야 함), 또는 웹은 `package:web`의 Web Audio, 데스크톱은 우리의 플랫폼 코드. 권장: `audioplayers`. 플레이어가 있는 모든 플랫폼에 패키지 하나이고, CLAUDE.md대로 플러그인 등록 파일을 커밋합니다. 통합 테스트에서 Windows의 효과음 지연이 너무 길면 `flutter_soloud`가 대안이고, `GbSound` 인터페이스가 선택을 감춥니다. **작성자의 답(7절): 먼저 잰다.**
6. **`Sound.Play`는 기다리지 않음.** 권장: 그렇게. `Http`·`Room`(D124 A, D136)과 다르지만, 게임 루프는 소리 200 ms를 멈출 수 없고 돌아올 것도 없습니다. `PlayMusic`과 `StopMusic`도 같습니다.
7. **시계의 이름과 영점: 프로그램 시작부터 세는 `Milliseconds()`.** 권장. `TickCount`는 읽는 사람 머릿속에서 Timer의 `Tick`과 부딪히고, `Timer()`는 컨트롤의 이름입니다(A080이 말함).
8. **`IsDown`용 키로서의 Shift, Control, Alt**(`Keys.ShiftKey`, `Keys.ControlKey`, `Keys.Menu`, Visual Basic .NET의 것). 권장: `IsDown`용으로만 더함. `KeyDown`·`KeyUp`은 다른 키와 함께 온다는 D101의 규칙을 지킵니다.
9. **예제: v0.7에 Shooter, 격투 게임은 바로 다음 자기 변경으로.** 권장. v0.7이 작은 변경들로 들어가고(6절 Q11), 한 키보드에 두 사람, 주먹·발차기 프레임, 체력 바가 필요한 격투 게임은 도구가 들어온 뒤 같은 도구를 쓰는 것이지 이 계획서를 넓히는 것이 아닙니다.
10. **웹의 autoplay 규칙: 첫 클릭이나 키 전의 `Play`는 조용히 버림.** 권장. 대안인 오류는 데스크톱에서 도는 프로그램을 웹에서 멈추게 하고, Shooter는 어차피 버튼으로 시작합니다. **작성자의 답(7절): 그렇게 하되 이유를 적고, Shooter는 시작 버튼을 기다린다.**
11. **변경의 순서**, 각각 동일성 프로그램과 함께 따로 병합: (1) `Milliseconds`와 `Wait`; (2) `Keyboard.IsDown`과 키 셋; (3) `Move`와 프레임이 있는 `Sprite`; (4) `Hits`와 `DistanceTo`, 사각형·원·픽셀; (5) `Sound`, 프로젝트 파일, IDE의 소리 묶음; (6) Shooter 예제, 웹 확인, 문서, D138. 권장: 적은 대로. 단계마다 혼자서도 쓸 수 있고, 예제는 필요한 것이 다 들어온 뒤에 옵니다.
12. **`Frames`를 고를 때의 크기:** 속성 창이 처음 한 번만 `Width`·`Height`를 첫 프레임의 크기로 두고 다시는 안 둠(작성자가 크기를 바꿀 수 있음). 권장. 컨트롤이 스스로 크기를 바꾸지 않는다는 `Image`의 규칙(D51)은 `Image`에 그대로입니다.

## 7. 작성자의 답(2026-11-04)

6절의 권장안을 모두 받되 둘을 바꿉니다. DESIGN D138이 기록합니다.

- **Q5, 소리 패키지는 이 계획서가 아니라 측정으로 고릅니다.** Sound 변경(6절 Q11의 5단계) 전에 `audioplayers`와 `flutter_soloud`의 `Play`부터 첫 소리까지의 지연을 웹·macOS·Windows에서 셋으로 잽니다: 짧은 효과음 하나, 같은 짧은 효과음을 연달아 빠르게 여러 번, 서로 다른 소리 여럿을 겹쳐서. 결과가 나오면 이 절에 표로 넣고, 더 나은 쪽을 다시 묻지 않고 택합니다. `GbSound` 인터페이스는 어느 쪽이든 같습니다.
- **Q10, 웹에서 첫 클릭 전의 소리는 권장대로 조용히 버리되 이유를 적습니다:** LANGUAGE §11.13과 참조가 브라우저의 규칙이라는 것과 그 때문에 프로그램을 멈추지 않는 이유를 말합니다. Shooter 예제는 시작 버튼을 눌러야 비로소 시작해(2.6절) 첫 소리가 클릭 뒤에 옵니다.
- Q1~Q4, Q6~Q9, Q11, Q12: 권장안대로.
- **5단계는 변경 둘로:** (5a) 프로그램 쪽. 컴포넌트 통로의 `Sound`, flutter_soloud 위의 런타임, 프로젝트 파일의 `sounds`와 버전 4, 플레이어의 번들과 앱, 이미 소리가 있는 프로젝트를 돌리는 데스크톱 IDE. (5b) IDE 쪽. 더하기·빼기가 있는 소리 창, 탐색기의 묶음, 브라우저 보관, `.zip`, A082.

### 7.1 소리 패키지 측정(2026-11-04, Windows, 웹, macOS)

`packages/gubasic_runtime/tool/sound_probe`가 스스로 만든 소리 다섯(50 ms 발사음, 80 ms 잡음, 30 ms 삐, 음, 화음)을 두 패키지로 내고, 호출부터 패키지가 처음 진행을 알릴 때까지의 밀리초를 잽니다. `tool/web_check/sound_probe.mjs`가 웹 빌드를 Chrome에서 돌립니다. Windows 11의 Windows 앱, 웹은 헤드리스 Chrome 155(브라우저 자체 버퍼는 둘에 똑같이 더해짐). 중앙값은 시작한 것들의 값이고, "시작"은 1초 안에 진행을 알린 것입니다.

| 경우 | audioplayers 6.8.1, Windows | flutter_soloud 5.2.2, Windows | audioplayers, 웹 | flutter_soloud, 웹 |
|---|---|---|---|---|
| 짧은 효과음 하나(5번) | 중앙값 53 ms, 최대 61 | 중앙값 27 ms, 최대 30 | 중앙값 23 ms, 최대 28 | 중앙값 24 ms, 최대 29 |
| 같은 효과음 20번, 10 ms 간격 | 중앙값 452 ms, 최대 990, **20 중 17 시작** | 중앙값 27 ms, 최대 49, 20 중 20 | 중앙값 385 ms, 최대 497, 20 중 20 | 중앙값 26 ms, 최대 53, 20 중 20 |
| 서로 다른 소리 다섯을 한꺼번에 | 각 260 ms | 각 2 ms | 각 308 ms | 각 9 ms |

`audioplayers`는 재생마다 플레이어를 따로 두는데(나는 소리 위에 새 효과음을 내려면 그래야 함) 그것들을 줄 세웁니다: 스무 번째 발사음은 1초 늦고, Windows에서는 셋이 사라졌습니다. `flutter_soloud`는 스스로 섞어서 각각을 한 프레임 안에 시작합니다. **`flutter_soloud`로 정합니다.** 작성자가 다시 묻지 않고 정해도 된다고 했습니다. 같은 날 맥에서 같은 탐침으로 잰 아래의 macOS 결과도 같습니다. 따라오는 것: 웹 페이지들(IDE, 플레이어, 웹 템플릿의 `index.html`)에 `init_soloud.js` 스크립트 줄, 앱과 함께 서비스하는 WASM 파일, Windows와 macOS에 등록하는 네이티브 플러그인.

**macOS**(작성자의 맥, macOS 27.0.1, 탐침의 릴리스 앱, 세 번). 첫 번째에는 `audioplayers`가 하나도 시작하지 못했습니다. 바이트로 받은 소리를 앱의 캐시 폴더에 파일로 쓰는데, 샌드박스 앱에서 그 폴더가 아직 없었습니다(재생마다 `PathNotFoundException`). 그 사이 `flutter_soloud`가 폴더를 만들어 다음부터는 있었습니다. 두 번째와 세 번째:

| 경우 | audioplayers 6.8.1, macOS | flutter_soloud 5.2.2, macOS |
|---|---|---|
| 짧은 효과음 하나(5번) | 중앙값 13과 15 ms, 최대 16 | 중앙값 4 ms, 최대 18과 40(첫 재생) |
| 같은 효과음 20번, 10 ms 간격 | 중앙값 268과 220 ms, 최대 364와 528, 20 중 **19**와 20 시작 | 중앙값 22와 27 ms, 최대 43과 73, 20 중 20 |
| 서로 다른 소리 다섯을 한꺼번에 | 각 37~39 ms | 각 42와 7 ms |

Windows와 웹에서처럼 `audioplayers`는 연달은 재생을 줄 세우고(많으면 0.5초 늦음) `flutter_soloud`는 각각을 제때 시작합니다. macOS에서 `flutter_soloud`의 숫자가 2, 33, 22, 11, 43, …으로 가는 것은 10 ms 간격의 호출이 약 45 ms마다 오는 진행 알림 사이에 떨어지기 때문이라, 늦게 시작한 것이 아니라 다음 알림까지 기다린 시간입니다. **선택은 그대로입니다.**

### 7.2 Shooter 측정(2026-11-04, 맥)

3.2절대로 Shooter를 STAGE2_PLAN 7절이 게임을 재는 방법으로, 플레이어와 IDE, Chrome, WebKit, macOS 앱에서 쟀습니다: [STAGE2_PLAN 7절](../STAGE2_PLAN.ko.md#7-속도-2-2에서-잴-것과-트랜스파일러를-다시-볼-때)의 기준 프로그램 6. Timer의 초당 62틱을 지키고(WebKit은 타이머가 20 ms마다 와서 50), 틱 하나는 16 ms 가운데 1.3~6.5 ms가 필요해 어디서나 기준 아래입니다. `Move`와 `Hits`가 그것이 대신하는 BASIC 줄보다 싼지는 이것으로 보이지 않습니다. Shooter와 갤러그 벤치마크는 하는 일이 다릅니다.

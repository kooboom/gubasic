# 아이디어

[English](IDEAS.md)

간직할 만하지만 아직 어느 단계도 맡지 않은 아이디어입니다. 여기 있는 것은 결정된 것도 계획된 것도 아닙니다. 작성자가 고를 때에만 아이디어가 계획과 결정을 갖추고 ROADMAP으로 옮겨 갑니다.

---

## 어드벤처 게임 컨트롤

**목표:** 포인트 앤 클릭 어드벤처 게임을 만들 수 있는 컨트롤 묶음. 어떤 장소의 그림, 그 안에서 살펴보고 누를 것들, 그곳을 걸어 다니는 캐릭터, 말을 거는 사람들, 그리고 다른 것에 쓸 물건이 든 가방이 들어갑니다. Visual Basic 6에는 이런 것이 없었습니다. 이 컨트롤이 있으면 누구나 글자를 치는 대신 그리고 누르는 게임을 만들 수 있습니다.

**시기:** 3단계 이후의 후보입니다. 2단계 계획과 프로젝트 묶음 형식(STAGE2_PLAN.ko.md)은 바꾸지 않습니다.

### 후보

| 컨트롤 | 하는 일 |
|---|---|
| **Scene** | 장소. 폼을 채우는 배경 그림과, 한 장면에서 다른 장면으로 넘어가기(예: 서서히 바뀌기). 게임은 장면의 모음 |
| **Hotspot** | 장면 안의 보이지 않는 누를 곳. 마우스를 올리면 이름이 보임("낡은 문"). 이벤트: `Click`, `MouseEnter`, `MouseLeave` |
| **Sprite** | 여러 장의 그림을 차례로 보여 주는 캐릭터(왼쪽, 오른쪽, 앞, 뒤로 걷기). `WalkTo x, y`로 그곳까지 걸어가며 방향에 맞는 그림을 고르고, 도착하면 `Arrived` 이벤트가 옴 |
| **Dialog** | 스프라이트 위의 말풍선과, 다음 대사로 이어지는 플레이어의 선택지 목록 |
| **Inventory** | 플레이어의 가방. 가지고 있는 물건의 그림. 가방에서 끌어 Hotspot, Sprite, 다른 물건 위에 놓으면 무엇을 무엇에 썼는지 알리는 이벤트(`UseOn`)가 옴 |

### 먼저 있어야 할 것

- **Timer**(STAGE2_PLAN 2-9 단계): 걷기, 애니메이션, 장면 전환은 틱마다 조금씩 움직입니다.
- **키 이벤트**(2-10 단계): 키보드로 움직이거나 대사를 넘깁니다.
- **여러 폼, 또는 장면**(2-7, 2-8 단계): 게임은 장소를 옮겨 다닙니다. Scene을 폼 위에 만들지 따로 둘지는 그때 정합니다.
- **그림 여러 장 다루기:** 스프라이트가 걸으려면 방향마다 차례가 있는 그림 묶음(프레임)이 필요합니다. 지금 프로젝트의 그림은 한 장씩이므로(LANGUAGE §11.3), 그림을 묶는 방법이 먼저입니다.

### 기존 도구는 어떻게 하나: Adventure Game Studio

이런 게임을 만들기 위한 도구인 Adventure Game Studio(AGS)는 위 후보와 맞아떨어지는 몇 가지 개념으로 게임을 짭니다.

- **방(Room):** "게임은 여러 개의 방으로 이루어지고, 플레이어는 그 사이를 옮겨 다닌다", "방 하나는 자기 배경, 핫스팟, 오브젝트를 가진 화면 하나다"([AGS 매뉴얼 2부](https://adventuregamestudio.github.io/ags-manual/v3/acintro2.html)). → Scene
- **핫스팟, 오브젝트, 캐릭터:** 플레이어가 상호작용할 수 있는 세 가지입니다. "핫스팟은 플레이어가 살펴보고 상호작용할 수 있는 배경 그림의 한 영역"이고, 바뀌지 않는 부분에 씁니다. 오브젝트는 "화면에서 움직이고, 켜고 끌 수 있다"([3부](https://adventuregamestudio.github.io/ags-manual/v3/acintro3.html), [4부](https://adventuregamestudio.github.io/ags-manual/v3/acintro4.html)). → Hotspot. 오브젝트 역할은 이미 Image가 합니다.
- **인벤토리:** "게임의 캐릭터마다 자기 인벤토리 물건을 가지고 다닐 수 있다". 방 안의 오브젝트와는 따로 만듭니다([5부](https://adventuregamestudio.github.io/ags-manual/v3/acintro5.html)). → Inventory
- **뷰와 루프:** "뷰는 하나 이상의 루프의 모음이다. 루프는 차례로 보여 주면 움직이는 것처럼 보이는 프레임의 모음이다". 캐릭터가 걷는 데 씁니다([7부](https://adventuregamestudio.github.io/ags-manual/v3/acintro7.html)). → Sprite와, 그것이 필요로 하는 그림 묶음
- **대화:** 고정된 대사 한 줄부터 "이야기할 주제를 고를 수 있는 완전한 대화 트리"까지([8부](https://adventuregamestudio.github.io/ags-manual/v3/acintro8.html)). → Dialog
- **커서 모드:** 마우스 커서마다 상호작용하는 방식이 다르고, 그 가운데 "걸어가기"가 있으며, 물건을 고르면 "인벤토리 쓰기"가 됩니다([9부](https://adventuregamestudio.github.io/ags-manual/v3/acintro9.html)). GuBASIC은 포인터를 하나로 두는 쪽이 낫습니다: 누르면 걸어가거나 살펴보고, 가방에서 물건을 끌어 씁니다.

GuBASIC답게 지킬 것: 컨트롤은 디자이너에서 폼 위에 그리고, 게임은 GuBASIC의 다른 모든 것처럼 이벤트 처리기로 씁니다(`hsDoor_Click`, `sprHero_Arrived`, `invKey_UseOn`).

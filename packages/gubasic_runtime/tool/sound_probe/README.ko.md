# 소리 탐침

[English](README.md)

`Sound` 뒤에 둘 패키지를 고르려고 두 오디오 패키지가 소리를 얼마나 빨리 내기 시작하는지 잽니다(docs/plans/PLAN_V07.ko.md 7절, DESIGN D138): `audioplayers`와 `flutter_soloud`. 소리는 앱 안에서 만들므로(50 ms 발사음, 80 ms 잡음, 30 ms 삐, 음 하나, 화음, 모두 WAV) 바깥에서 오는 것이 없습니다.

세 경우를 재고, 각각 호출부터 패키지가 처음 진행을 알릴 때까지의 밀리초입니다(0보다 큰 위치, 또는 그보다 먼저 오면 재생 중 상태). 1초 안에 아무것도 알리지 않으면 -1입니다.

1. 짧은 효과음 하나를 사이를 두고 다섯 번;
2. 같은 효과음을 10 ms 간격으로 스무 번, 각각 따로;
3. 서로 다른 소리 다섯을 한꺼번에.

이것은 패키지 자체의 지연이고 마이크가 듣는 값이 아닙니다. 엔진의 버퍼는 둘에 똑같이 더해집니다.

## 실행

먼저 고정한 Flutter를 씁니다(`packages/gubasic_runtime`에서 `dart tool/check_flutter.dart`). 그다음:

```sh
cd packages/gubasic_runtime/tool/sound_probe
flutter pub get
flutter run -d windows --release    # 또는 -d macos: 저절로 시작하고 다운로드 폴더에 sound-probe-<시스템>.json을 씀
flutter build web --release
node ../../../../tool/web_check/sound_probe.mjs build/web --channel chrome   # 결과 줄을 출력
```

브라우저에서는 페이지가 클릭 뒤에만 소리를 낼 수 있어서 Start를 기다리고, 스크립트가 눌러 줍니다. 데스크톱에서는 1초 뒤 저절로 시작하고 결과를 다운로드 폴더에 씁니다.

## 결과

지금까지의 결과는 계획서 7절의 표에 있습니다. 모든 플랫폼을 같은 방법으로 재고, macOS는 맥에서 잽니다.

# 초코야 타다닥 (구 Ticklings)

> **타다닥** 은 기계식 키보드를 두드릴 때 나는 경쾌한 소리를 의성어로 표현한 한국어입니다. **Chocoya Tadadak** 은 그 "타다닥" 감성을 macOS 메뉴바 앱으로 되살려 줍니다.

---

## 특징

* 전역 키보드 이벤트 감지(손쉬운 사용 권한 필요)
* 버블 · 타자기 · 기계식 등 다양한 사운드 테마
* 설정 창에서 실시간 테마/볼륨 변경
* 100% 로컬 동작 – 로그인·자동 실행·텔레메트리 없음
* 메뉴바 아이콘: `chocoya-tadadak.png` 기본 제공

---

## 준비 사항

| 도구 | 권장 버전 | 설치 명령 |
|------|-----------|-----------|
| macOS | 12 Monterey 이상 | 기본 제공 |
| Swift | 5.9 이상 | `brew install swift` |
| Xcode 명령줄 도구 | 최신 | `xcode-select --install` |

---

## 로컬 빌드 & 실행

```bash
# 1) 저장소 클론
$ git clone https://github.com/yourname/chocoya-tadadak.git
$ cd chocoya-tadadak

# 2) 디버그 빌드
$ swift build

# 3) 실행
$ swift run
```

첫 실행 시 *시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용* 에서 **Chocoya Tadadak** 에 접근성 권한을 허용해야 키 입력이 감지됩니다.

---

## 릴리즈 빌드 패키징

```bash
$ swift build -c release
# 결과 앱 번들은
.build/release/ChocoyaTadadak.app
```

메뉴바 아이콘은 `Resources/chocoya-tadadak.png` 를 사용합니다. 템플릿 PNG(단색, 투명 배경)로 교체해 원하는 디자인을 적용하세요.

---

## 폴더 구조 (발췌)

```
Sources/
  └─ TicklingsApp/
      ├─ Resources/           # 사운드 테마 & 아이콘
      │   ├─ chocoya-tadadak.png
      │   └─ ...             # Bubble/, Mechanical/ 등
      ├─ AppDelegate.swift   # 메뉴바 / 이벤트 탭 설정
      └─ ...
Package.swift                # SwiftPM 매니페스트
```

---

## 라이선스

MIT © 2025 Jelly

# ColonySurvival

# Colony Survival - Lab Xmas Edition 🎄  
킬링타임용 크리스마스 에디션 셀 컬처 생존 게임

---

##  소개 (Korean)
**Colony Survival - Lab Xmas Edition** 은  
세포배양실을 배경으로, 크리스마스 시즌에 정신없이 돌아가는 연구실에서  
HEK293T(산타 모자 쓴 깜찍한 주인공)를 조종해  
컨탐(contamination)과 이상 증식한 세포들을 막아내는 탑다운 액션 생존 게임입니다.

- 배경: 인큐베이터, CO₂ 배양기, 벤치, 책상이 복잡하게 놓인 실제 랩 느낌 맵  
- 주인공: 산타 모자를 쓴 HEK293T 셀 캐릭터  
- 목표: 10개의 웨이브(스테이지)를 버티면서 랩을 지키는 것

이 프로젝트는 Python + pygame 으로 작성되었고,  
macOS / Windows 모두 실행 파일을 제공합니다.

release에 업로드 되어있습니다.
거기서 다운받아서 사용하세요.

---
## 주요 특징 (Korean)

- **탑다운 액션 생존 게임**
  - 사방에서 몰려오는 컨탐(곰팡이, 세균, 이상 증식 세포 등)을 회피/제거
  - 웨이브가 진행될수록 점점 강해지는 몹과 보스

- **랩 무기 시스템**
  - qPCR Beam
  - CRISPR Lance
  - Lentiviral Orb  
  등 각종 “실험 무기”를 장착해 한 번에 여러 발사체를 난사

- **버프/디버프 시스템**
  - High-throughput qPCR (화력 증가 느낌의 버프)
  - Fragile Cells (내구도 낮아지는 디버프)  
  등 랩스러운 효과들이 런마다 랜덤하게 등장

- **가볍게 즐기는 실험실 풍자**
  - 연구실 책상, 팁박스, 플라스크, 배양 플레이트 사이를 파고드는 플레이
  - 크리스마스 시즌에 더 바빠지는 현실 랩 분위기 반영

---
## 다운로드 & 실행 (유저용)

### 1) Windows

1. GitHub Releases 탭에서  
 'ColonySurvival-Windows.zip' 다운로드
2. 압축 해제 후 아래 폴더 구조를 확인:
   ```text
   ColonySurvival/
     ColonySurvival.exe
     _internal/ ...

3. 실행 방법:
    ColonySurvival.exe 더블클릭
    또는
     Run_Colony_Windows.bat (만들어 두었다면) 더블클릭
     Windows SmartScreen 경고가 뜰 수 있습니다.
    “추가 정보 → 실행” 을 눌러 진행해야 할 수 있습니다.


### 2) macOS
1. GitHub Releases 탭에서
'ColonySurvival-macOS.zip 다운로드
2. 압축 해제 후:

colony survival/
  Run_Colony.command
  bin/
  src/
  ...

3. 실행 방법:
  Run_Colony.command 더블클릭
  처음 실행 시 “확인되지 않은 개발자” 경고가 뜨면:
  Run_Colony.command 를 Control + 클릭 → 열기 를 선택


======================================================================================================

개발용 (소스에서 실행)

1) 요구 사항
Python 3.10 이상
pygame 라이브러리


pip install -r requirements.txt
# 또는
pip install pygame

2) 실행 (공통)
프로젝트 루트(예: colony survival/)에서:

python -m colony.main

또는 직접:
python src/colony/main.py


======================================================================================================

빌드 (개발자용)
Windows 빌드 (PyInstaller)
cd "D:\CSW\colony survival\colony survival"
bin\build_windows.bat


결과: dist\ColonySurvival\ColonySurvival.exe
이 폴더 전체를 ColonySurvival-Windows.zip 으로 압축해 배포

macOS 빌드
cd /path/to/colony\ survival
bin/build_macos.sh
# 또는 이미 준비된 Run_Colony.command 사용


결과물 폴더를 ColonySurvival-macOS.zip 으로 압축해 배포

======================================================================================================
제작 / 저작권 (Korean)

개발: 채승원 (Seung Won Chae)
소속: 서울대학교병원 진단검사의학과 분자진단검사실

논문/발표/블로그 등에 게임을 언급하고 싶다면
“Colony Survival - Lab Xmas Edition, by Seung-Won Chae (SNUH Laboratory Medicine)”
정도로 표기해 주시면 좋습니다.


라이선스 (Korean)

아직 공개 라이선스를 명시하지 않았다면,
MIT / Apache-2.0 / GPL 등 원하는 라이선스를 선택해
LICENSE 파일을 추가하고
여기에 라이선스 이름을 적어 주세요.

예시:
License: MIT



==================================================================================================================================================================================================================================================================================================================

##  Introduce (English)

# ColonySurvival

# Colony Survival - Lab Xmas Edition 🎄  
A small Christmas-edition cell culture survival game

---

##  Introduction (English)

**Colony Survival - Lab Xmas Edition** is a  
top-down action survival game set in a busy cell culture room during the Christmas season.

You control a cute **HEK293T cell wearing a Santa hat**,  
fighting off contamination and abnormally proliferating cells to protect the lab.

- **Setting:** a realistic lab-style map with incubators, CO₂ tanks, benches, and desks cluttered around  
- **Main character:** a HEK293T cell character wearing a Santa hat  
- **Goal:** survive 10 waves (stages) and keep the lab safe

This project is written in **Python + pygame**,  
and provides binaries for both **macOS** and **Windows**.

Prebuilt binaries are uploaded in the **GitHub Releases** section.  
Please download and use the version for your platform from there.

---

##  Key Features (English)

- **Top-down action survival gameplay**
  - Dodge and eliminate contaminants (fungi, bacteria, overgrown cells, etc.) coming from all directions
  - Enemies and bosses get stronger as the waves progress

- **Lab-themed weapon system**
  - qPCR Beam  
  - CRISPR Lance  
  - Lentiviral Orb  
  Various “experimental weapons” can be equipped to fire multiple projectiles at once.

- **Buff / debuff system**
  - High-throughput qPCR (buff that feels like increased firepower)
  - Fragile Cells (debuff that reduces survivability)  
  Lab-themed effects appear randomly in each run.

- **Lightweight lab satire**
  - Weave between lab desks, tip boxes, flasks, and culture plates while playing  
  - Captures the reality that labs often get *busier* around Christmas, not quieter

---

##  Download & Run (For Players)

### 1) Windows

1. Go to the GitHub **Releases** tab and download  
   'ColonySurvival-Windows.zip'.
2. Extract the zip and confirm the folder structure:
   ```text
   ColonySurvival/
     ColonySurvival.exe
     _internal/ ...


   Run:
Double-click ColonySurvival.exe, or

If provided, double-click Run_Colony_Windows.bat

Windows SmartScreen may show a warning.
Click “More info → Run anyway” to proceed.

### 2) macOS

Go to the GitHub Releases tab and download
ColonySurvival-macOS.zip.

Extract the zip. You should see something like:

colony survival/
  Run_Colony.command
  bin/
  src/
  ...


Run:

Double-click Run_Colony.command

On first launch, if you see an “unidentified developer” warning:

Control + Click → Open on Run_Colony.command and confirm

======================================================================================================

**Development (Run from Source)**
1) Requirements

Python 3.10+
pygame library
Install dependencies:

pip install -r requirements.txt
# or
pip install pygame


2) Run (common)
From the project root (e.g. colony survival/):
python -m colony.main

Or directly:

python src/colony/main.py

🛠 Build (For Developers)
Windows build (PyInstaller)
cd "D:\CSW\colony survival\colony survival"
bin\build_windows.bat

Output: dist\ColonySurvival\ColonySurvival.exe

Zip the entire dist\ColonySurvival folder as
ColonySurvival-Windows.zip for distribution.

macOS build
cd /path/to/colony\ survival
bin/build_macos.sh
# or use the existing Run_Colony.command wrapper


Zip the resulting folder as
ColonySurvival-macOS.zip for distribution.


======================================================================================================
Author / Copyright

Developer: Seung Won Chae

Affiliation: Molecular Diagnostics Laboratory,
Department of Laboratory Medicine,
Seoul National University Hospital (SNUH)

If you would like to mention this game in a paper, talk, or blog post,
please credit it as:

“Colony Survival - Lab Xmas Edition, by Seung-Won Chae (SNUH Laboratory Medicine)”

======================================================================================================
License

A public open-source license has not yet been explicitly specified.
Please choose whichever license you prefer (e.g. MIT, Apache-2.0, GPL) and:
Add a LICENSE file to the repository.
Write the license name here.
Example: License: MIT




Email: csm0578@naver.com/snu.ac.kr 입니다.
^^ enjoy!


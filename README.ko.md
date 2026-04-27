[English](README.md)

# save-your-token

Claude Code를 사용하게 되면 토큰소모량이 심해져서 순식간에 토큰 사용량 한계에 도달할 때가 있습니다.
이 문제를 해결하기 위한 token 절약 기능을 구현해봤습니다.

---

## 어떻게 작동하나요?

`/token-diet`에서는 두 가지 기능이 구현되어 있습니다.

**첫째, 내 기록을 분석합니다.**

Claude Code가 로컬에 저장한 세션 파일을 파싱해서, 내가 어떤 명령어에 토큰을 얼마나 썼는지 수치로 보여줍니다.
실제 내부 파일들을 들여다 보고 진행됩니다.

```
명령어당 평균 토큰: 36,700 tok

카테고리별 사용량
  코드 생성      8건   52,400 tok   평균 6,550/건   41% 🔴
  수정/리팩토링  4건   31,800 tok   평균 7,950/건   25% 🟡
  설명/질문      5건   14,200 tok   평균 2,840/건   11% 🟢

토큰 많이 쓴 명령어 TOP 3
  1. [코드 생성] 이 기능 전체를 새로 작성해줘 → 18,400 tok
  2. [수정]      전체 파일 리팩토링해줘       → 15,200 tok
  3. [코드 생성] API 연동 코드 만들어줘       → 12,600 tok
```

**둘째, 환경을 진단하고 개선을 안내합니다.**

CLAUDE.md 크기, MCP 서버 수, .claudeignore 설정, ReadOnce 훅, rules 여부를 자동으로 스캔합니다.
대화형으로 문제가 있으면 이유를 설명하고, 해결 방법을 직접 안내합니다.
확인하기 전까지는 적용되지 않습니다.

---

## 설치

```bash
git clone https://github.com/Sunro1994/save-your-token.git
cd save-your-token

# 커맨드 등록
mkdir -p ~/.claude/commands
cp commands/token-diet.md ~/.claude/commands/token-diet.md
```

**ReadOnce 훅 (선택, 권장)**

같은 파일을 반복해서 읽는 낭비를 자동으로 차단합니다.

```bash
mkdir -p ~/.claude/hooks
cp hooks/readonce-hook.sh ~/.claude/hooks/readonce-hook.sh
chmod +x ~/.claude/hooks/readonce-hook.sh
```

`~/.claude/settings.json`에 아래 내용을 추가하세요.
파일이 이미 있다면 `hooks` 키만 병합하면 됩니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/readonce-hook.sh"
          }
        ]
      }
    ]
  }
}
```

---

## 실행

Claude Code 세션에서 입력하세요.

```
/token-diet
```

---

## 단계별 안내

분석 후 아래 4단계를 순서대로 또는 골라서 진행할 수 있습니다.
각 단계는 이유를 먼저 설명하고, 선택은 사용자가 합니다.

| 단계  | 내용 |
|------|----------|------|
| 1 | `/compact`, `/clear` 사용 타이밍 잡기 |
| 2 | MCP 정리, `.claudeignore` 적용 |
| 3 | `rules/` 분리, Extended Thinking 조정 |
| 4 | 메모리 구조 개선, ReadOnce 훅 설치 |

---

## 함께 제공되는 파일

### .claudeignore 템플릿

Claude Code는 프로젝트를 탐색할 때 이미지, 빌드 결과물, 설정 파일까지 읽으려 합니다.
`.claudeignore`를 프로젝트 루트에 두면 그 범위를 제한할 수 있습니다.

```bash
# 프로젝트 유형에 맞는 템플릿을 복사하세요
cp examples/claudeignore-nextjs   ./my-nextjs-project/.claudeignore
cp examples/claudeignore-python   ./my-python-project/.claudeignore
cp examples/claudeignore-obsidian ./my-vault/.claudeignore
```

### ReadOnce 훅

Claude Code가 같은 파일을 여러 번 읽을 때마다 전체 내용이 컨텍스트에 다시 쌓입니다.
이 훅은 5분 이내 동일 파일 재읽기를 자동으로 차단합니다.
macOS · Linux · Windows 모두 지원합니다.

### context-watch 훅

Claude 응답이 끝날 때마다 컨텍스트 사용량을 자동으로 확인합니다.
`/context`를 직접 실행하지 않아도 임계값 도달 시 자동으로 알려줍니다.

- 🟡 60% 이상: `/compact` 권고
- 🔴 80% 이상: `/clear` 또는 `/compact` 경고

자세한 설치 방법은 [`hooks/SETUP.md`](hooks/SETUP.md)를 참고하세요.

---

## 기술 구조

- `/token-diet` 커맨드: `~/.claude/projects/` 하위 JSONL 세션 파일을 파싱해 실제 토큰 사용량을 집계합니다.
- ReadOnce 훅: Claude Code의 `PreToolUse` 이벤트를 감지해 중복 읽기를 차단합니다. SHA-256 해시로 파일 경로를 관리하며 python3 외 별도 의존성이 없습니다.
- 모든 처리는 로컬에서 이루어집니다. 외부 서버나 API를 사용하지 않습니다.

---

## 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.0 이상
- python3 (macOS · Linux 기본 포함, 토큰 분석 및 ReadOnce 훅에 필요)

---

## 기여

이슈와 PR을 환영합니다. 큰 변경 사항은 이슈를 먼저 열어 논의해 주세요.

## 원작자 표기

이 프로젝트는 [jjoa68/claude-token-diet](https://github.com/jjoa68/claude-token-diet)에서 영감을 받아 제작되었습니다.
ReadOnce 훅의 핵심 아이디어, 단계별 환경 진단 구조, `.claudeignore` 템플릿 개념은 원작에서 가져왔습니다.
원작은 MIT 라이선스로 공개되어 있습니다.

이 버전에서 새로 추가한 것:
- 실제 세션 JSONL 파싱을 통한 토큰 사용량 분석
- 카테고리별 명령어 분류 및 TOP 5 리포트
- ReadOnce 훅 SHA-256 해시 적용 및 stdin 파싱 버그 수정
- 한국어 전용 인터페이스

## 라이선스

[MIT](LICENSE)

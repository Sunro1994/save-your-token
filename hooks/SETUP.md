> 이 문서에서 제공하는 훅은 세 가지다.
> - **ReadOnce**: 동일 파일 중복 읽기 자동 차단 (PreToolUse)
> - **context-watch**: 컨텍스트 임계값 도달 시 경고 (Stop)
> - **report-save**: 일별 토큰 사용량 자동 저장 (Stop)
>
> settings.json의 hooks 키 안에 함께 등록한다. 전부 설치하는 것을 권장한다.

# 훅 설치 가이드

## 동작 원리

- Claude Code의 `Read` 도구 호출을 PreToolUse 훅으로 감시
- 같은 파일을 5분 이내에 다시 읽으려 하면 차단하고 "이미 읽었다"고 안내
- offset이 지정된 분할 읽기는 허용 (대규모 편집 시 필요하므로)
- 캐시는 `/tmp/claude-read-cache-<uid>/`에 사용자별로 저장되며, 시스템 재부팅 시 초기화
- 해시 알고리즘: SHA-256 (python3 hashlib 사용, 외부 명령 의존 없음)

---

## macOS / Linux 설치

### 1. 훅 파일 복사

```bash
# 훅 디렉토리 생성 (없으면)
mkdir -p ~/.claude/hooks

# 훅 파일 복사
cp hooks/readonce-hook.sh ~/.claude/hooks/readonce-hook.sh

# 실행 권한 부여
chmod +x ~/.claude/hooks/readonce-hook.sh
```

### 2. settings.json에 훅 등록

`~/.claude/settings.json` 파일을 열고 아래 내용을 추가한다.
파일이 없으면 새로 만든다. 이미 있으면 `hooks` 키만 병합한다.

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

> **⚠️ JSON 편집이 처음이라면**: 수정 전 백업을 먼저 만드세요.
> ```bash
> cp ~/.claude/settings.json ~/.claude/settings.json.bak
> ```
> 수정 후 Claude Code가 실행되지 않으면 JSON 문법 오류일 가능성이 높다.
> `cp ~/.claude/settings.json.bak ~/.claude/settings.json` 으로 복원할 수 있다.
>
> 흔한 실수: 쉼표(`,`) 누락, 중괄호(`{}`) 불일치, 따옴표(`"`) 빠짐.

---

## Windows 설치

### 1. 훅 파일 복사

```powershell
# 훅 디렉토리 생성 (없으면)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\hooks"

# PowerShell 훅 파일 복사
Copy-Item hooks\readonce-hook.ps1 "$env:USERPROFILE\.claude\hooks\readonce-hook.ps1"
```

### 2. settings.json에 훅 등록

`%USERPROFILE%\.claude\settings.json` 파일을 열고 아래 내용을 추가한다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\hooks\\readonce-hook.ps1\""
          }
        ]
      }
    ]
  }
}
```

---

## context-watch 훅 설치 (macOS / Linux)

Claude 응답이 끝날 때마다 컨텍스트 사용량을 확인하고 임계값 초과 시 경고한다.
- 🟡 60% 이상: `/compact` 권고
- 🔴 80% 이상: `/clear` 또는 `/compact` 경고

### 1. 훅 파일 복사

```bash
cp hooks/context-watch.sh ~/.claude/hooks/context-watch.sh
chmod +x ~/.claude/hooks/context-watch.sh
```

### 2. settings.json에 등록

세 훅을 모두 함께 쓴다면 아래처럼 한 파일에 등록한다.
`Stop` 배열에 여러 훅을 나열하면 순서대로 실행된다.

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
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/context-watch.sh"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/report-save.sh"
          }
        ]
      }
    ]
  }
}
```

context-watch만 단독으로 쓴다면 `Stop` 블록에 해당 항목만 남기면 된다.

---

## report-save 훅 설치 (macOS / Linux)

Claude 응답이 끝날 때 하루 1회 토큰 사용 스냅샷을 자동 저장한다.
저장 위치: `~/.claude/token-diet-reports/YYYY-MM-DD.json`
`/token-diet` 실행 시 이 파일을 읽어 7일 트렌드를 비교해 보여준다.

### 1. 훅 파일 복사

```bash
cp hooks/report-save.sh ~/.claude/hooks/report-save.sh
chmod +x ~/.claude/hooks/report-save.sh
```

### 2. settings.json에 등록

위 context-watch 설치 안내의 `Stop` 블록에 함께 추가한다. (위 전체 예시 참고)

### 3. 동작 확인

Claude Code 세션 사용 후 아래 경로에 파일이 생성되면 정상이다.

```bash
ls ~/.claude/token-diet-reports/
# 2026-04-27.json

cat ~/.claude/token-diet-reports/2026-04-27.json
```

하루 1회만 저장되므로 당일 파일이 이미 있으면 덮어쓰지 않는다.
수동으로 오늘 파일을 삭제하면 다음 Stop 이벤트에서 다시 생성된다.

### 3. 동작 확인

Claude Code 세션에서 몇 가지 요청을 주고받은 후 응답이 끝날 때 아래 메시지가 표시되면 정상이다.

```
🟡 컨텍스트 63% 사용 중  (126,000 / 200,000 tokens)
   /compact 실행을 권장합니다.
```

---

## ReadOnce 훅 동작 확인

1. Claude Code를 실행한다.
2. 아무 파일을 읽는다. (정상 허용)
3. 같은 파일을 다시 읽으려 한다.
4. 아래 메시지가 표시되면 정상 동작이다.

```
이 파일은 N초 전에 이미 읽었습니다.
컨텍스트에 있는 내용을 그대로 사용하세요: /path/to/file
```

## ReadOnce 캐시 수동 초기화

5분 기다리지 않고 즉시 캐시를 초기화하려면:

```bash
# macOS / Linux
rm -rf /tmp/claude-read-cache-$(id -u)

# Windows (PowerShell)
Remove-Item -Recurse -Force "$env:TEMP\claude-read-cache-$env:USERNAME"
```

## 훅 비활성화

일시적으로 끄려면 `settings.json`에서 해당 훅 항목을 삭제한다.
(JSON은 주석을 지원하지 않으므로 항목 자체를 삭제해야 한다.)

---

## 주의사항

- ReadOnce 훅은 `Read` 도구만 감시한다. `Grep`, `Glob` 등 다른 도구에는 영향 없다.
- context-watch 훅은 python3가 필요하다. (macOS · Linux 기본 포함)
- context-watch 훅은 `~/.claude/projects/` 경로의 가장 최근 세션 파일을 기준으로 계산한다.
- 캐시는 `/tmp/`에 저장되므로 시스템 재부팅 시 자동 초기화된다.

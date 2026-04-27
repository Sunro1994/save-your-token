#!/bin/bash
# prompt-lint 훅 — 토큰 낭비 패턴 사전 감지 및 리라이팅 제안
# 이벤트: UserPromptSubmit
# 동작: 고비용 패턴 감지 시 경고 출력 (요청은 차단하지 않음, exit 0)

if ! command -v python3 &>/dev/null; then
  exit 0
fi

# ── stdin 저장 ────────────────────────────────────────────────
INPUT=$(cat)

# ── Python 코드를 임시 파일에 기록 후 실행 ───────────────────
# (heredoc과 stdin 충돌을 피하기 위해 tempfile 사용)
TMPPY=$(mktemp /tmp/prompt-lint-XXXXXX.py)
trap "rm -f $TMPPY" EXIT

cat > "$TMPPY" << 'PYEOF'
import sys, json

try:
    data = json.load(sys.stdin)
    prompt = data.get("prompt", "")
except Exception:
    sys.exit(0)

if not prompt.strip():
    sys.exit(0)

# ── 고비용 패턴 정의 ─────────────────────────────────────────
PATTERNS = [
    {
        "keywords": [
            "전체 파일", "모든 파일", "파일 전체", "파일들을 전부",
            "all files", "every file", "whole file", "entire file",
        ],
        "reason": "파일 전체를 컨텍스트에 올리면 토큰이 급격히 증가합니다",
        "suggest": (
            "특정 함수나 클래스명을 지정해보세요\n"
            "     예) \"`AuthService`의 `login` 메서드만 수정해줘\""
        ),
    },
    {
        "keywords": [
            "처음부터 다시", "새로 작성해", "전부 다시 써", "싹 다 새로",
            "from scratch", "rewrite everything", "rewrite the whole",
            "rebuild everything", "start over",
        ],
        "reason": "전체 재작성은 기존 코드를 모두 컨텍스트에 올려 토큰을 크게 소모합니다",
        "suggest": (
            "변경이 필요한 부분만 구체적으로 지정해보세요\n"
            "     예) \"이 함수의 에러 처리 로직만 개선해줘\""
        ),
    },
    {
        "keywords": [
            "전면 리팩토링", "전체 리팩토링", "전부 리팩토링",
            "full refactor", "refactor everything",
            "refactor the whole", "refactor all",
        ],
        "reason": "전체 리팩토링은 파일을 전부 읽어야 해 토큰 소모가 큽니다",
        "suggest": (
            "목적을 구체화해보세요\n"
            "     예) \"이 파일의 중복된 DB 호출 부분만 줄여줘\""
        ),
    },
    {
        "keywords": [
            "모든 에러", "모든 버그", "에러 다 고쳐", "버그 다 잡아",
            "전체 오류", "오류 전부",
            "fix everything", "fix all errors", "fix all bugs", "fix all issues",
        ],
        "reason": "에러 전체 수정 요청은 전체 파일 스캔을 유발합니다",
        "suggest": (
            "에러 메시지나 위치를 함께 전달해보세요\n"
            "     예) \"line 42의 TypeError 고쳐줘\""
        ),
    },
    {
        "keywords": [
            "전부 다 해줘", "모두 다 해줘", "전체적으로 다", "한번에 다",
            "do everything", "do it all", "handle everything", "do all of it",
        ],
        "reason": "범위가 불명확한 요청은 과도한 파일 탐색을 유발합니다",
        "suggest": (
            "작업 범위를 좁혀서 요청해보세요\n"
            "     예) \"A 기능만 먼저 구현해줘\""
        ),
    },
    {
        "keywords": [
            "프로젝트 전체", "전체 프로젝트", "모든 코드", "코드 전체",
            "entire project", "entire codebase", "whole project", "all the code",
        ],
        "reason": "프로젝트 전체 범위 요청은 수십 개의 파일을 컨텍스트에 올릴 수 있습니다",
        "suggest": (
            "작업 대상 파일이나 모듈을 특정해주세요\n"
            "     예) \"`src/api/` 폴더의 라우터 파일들만 검토해줘\""
        ),
    },
]

p = prompt.lower()
hits = [pat for pat in PATTERNS if any(kw.lower() in p for kw in pat["keywords"])]

if not hits:
    sys.exit(0)

# ── 경고 출력 ─────────────────────────────────────────────────
sep = "─" * 54
print(f"\n🔍 prompt-lint  토큰 낭비 패턴 {len(hits)}개 감지", file=sys.stderr)
print(sep, file=sys.stderr)
for i, h in enumerate(hits, 1):
    print(f"  {i}. ⚠️  {h['reason']}", file=sys.stderr)
    print(f"     💡 {h['suggest']}", file=sys.stderr)
    if i < len(hits):
        print("", file=sys.stderr)
print(sep, file=sys.stderr)
print("요청은 그대로 진행됩니다. 위 제안을 참고해 다음 번엔 더 좁혀서 요청해보세요.\n", file=sys.stderr)

sys.exit(0)
PYEOF

echo "$INPUT" | python3 "$TMPPY"
exit 0

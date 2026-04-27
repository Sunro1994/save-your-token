#!/bin/bash
# ReadOnce 훅 — 동일 파일 중복 읽기 차단
# 동작: 5분 이내 같은 파일을 다시 읽으려 하면 차단
# 허용: offset이 지정된 분할 읽기 (대규모 파일 편집 시 필요)

CACHE_DIR="/tmp/claude-read-cache-$(id -u)"
mkdir -p "$CACHE_DIR"

# ── python3 확인 ──────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "⚠️  python3가 없어 ReadOnce 훅이 동작하지 않습니다." >&2
  echo "    macOS: xcode-select --install" >&2
  echo "    Linux: sudo apt install python3" >&2
  exit 0
fi

# ── stdin을 먼저 변수에 저장 후 python3에 전달 ────────────────
INPUT=$(cat)

PARSED=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tool  = data.get('tool_name', '')
    inp   = data.get('tool_input') or {}
    fpath = inp.get('file_path', '')
    off   = str(inp.get('offset') or '')
    print(tool + '\t' + fpath + '\t' + off)
except Exception:
    print('\t\t')
")

TOOL_NAME=$(echo "$PARSED" | cut -f1)
FILE_PATH=$(echo "$PARSED" | cut -f2)
OFFSET=$(echo "$PARSED" | cut -f3)

# ── Read 호출만 처리 ──────────────────────────────────────────
if [ "$TOOL_NAME" != "Read" ] || [ -z "$FILE_PATH" ]; then
  exit 0
fi

# ── offset 있으면 분할 읽기 → 항상 허용 ──────────────────────
if [ -n "$OFFSET" ] && [ "$OFFSET" != "None" ] && [ "$OFFSET" != "0" ]; then
  exit 0
fi

# ── 경로 정규화 + SHA-256 해시 (외부 명령 의존 없음) ─────────
CACHE_KEY=$(echo "$FILE_PATH" | python3 -c "
import sys, hashlib, os
path = os.path.realpath(sys.stdin.read().strip())
print(hashlib.sha256(path.encode()).hexdigest())
" 2>/dev/null)

if [ -z "$CACHE_KEY" ]; then
  exit 0
fi

CACHE_FILE="$CACHE_DIR/$CACHE_KEY"
NOW=$(date +%s)

# ── 5분 이내 재읽기 → 차단 ───────────────────────────────────
if [ -f "$CACHE_FILE" ]; then
  CACHED_TIME=$(cat "$CACHE_FILE" 2>/dev/null || echo 0)
  DIFF=$(( NOW - CACHED_TIME ))

  if [ "$DIFF" -lt 300 ]; then
    echo "이 파일은 ${DIFF}초 전에 이미 읽었습니다." >&2
    echo "컨텍스트에 있는 내용을 그대로 사용하세요: $FILE_PATH" >&2
    exit 2
  fi
fi

# ── 현재 시각 기록 후 허용 ───────────────────────────────────
echo "$NOW" > "$CACHE_FILE"
exit 0

# ReadOnce 훅 — 동일 파일 중복 읽기 차단 (Windows PowerShell)
# 동작: 5분 이내 같은 파일을 다시 읽으려 하면 차단
# 허용: offset이 지정된 분할 읽기 (대규모 파일 편집 시 필요)

$CacheDir = "$env:TEMP\claude-read-cache-$env:USERNAME"
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

# ── stdin JSON 파싱 ───────────────────────────────────────────
# $input은 PowerShell 예약어 → $RawInput 사용
$RawInput = $input | Out-String
try {
    $Json = $RawInput | ConvertFrom-Json
} catch {
    exit 0
}

$ToolName = $Json.tool_name
$FilePath = $Json.tool_input.file_path
$Offset   = $Json.tool_input.offset

# ── Read 호출만 처리 ──────────────────────────────────────────
if ($ToolName -ne "Read" -or [string]::IsNullOrEmpty($FilePath)) {
    exit 0
}

# ── offset 있으면 분할 읽기 → 항상 허용 ──────────────────────
if ($Offset -and $Offset -ne "None" -and $Offset -ne "0") {
    exit 0
}

# ── 경로 정규화 ───────────────────────────────────────────────
try {
    $NormPath = [System.IO.Path]::GetFullPath($FilePath)
} catch {
    $NormPath = $FilePath
}

# ── SHA-256 해시 (외부 명령 의존 없음) ───────────────────────
$Bytes    = [System.Text.Encoding]::UTF8.GetBytes($NormPath)
$HashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)
$CacheKey  = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
$CacheFile = Join-Path $CacheDir $CacheKey

# ── 5분 이내 재읽기 → 차단 ───────────────────────────────────
$Now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

if (Test-Path $CacheFile) {
    try {
        $CachedTime = [int](Get-Content $CacheFile -Raw).Trim()
        $Diff = $Now - $CachedTime

        if ($Diff -lt 300) {
            [Console]::Error.WriteLine("이 파일은 ${Diff}초 전에 이미 읽었습니다.")
            [Console]::Error.WriteLine("컨텍스트에 있는 내용을 그대로 사용하세요: $FilePath")
            exit 2
        }
    } catch {
        # 캐시 파일 읽기 실패 시 그냥 허용
    }
}

# ── 현재 시각 기록 후 허용 ───────────────────────────────────
$Now | Set-Content $CacheFile
exit 0

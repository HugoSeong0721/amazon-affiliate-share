#!/usr/bin/env bash
# src/ 의 Lua 스크립트로 place 파일 두 개를 만든다.
#
#   build/CatGame-v{N}.rbxlx  XML 형식 (텍스트, git diff가 읽힌다)
#   build/CatGame-v{N}.rbxl   바이너리 형식 (공유 링크용 — 브라우저에서 바로 다운로드됨)
#
# 사용법:  bash tools/build.sh
# 필요:    python3, Rust(cargo)  — cargo가 없으면 .rbxlx 까지만 만든다.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

python3 "$HERE/build_rbxlx.py"

RBXLX="$(ls -t "$ROOT"/build/*.rbxlx | head -1)"
RBXL="${RBXLX%.rbxlx}.rbxl"

if ! command -v cargo >/dev/null 2>&1; then
	echo "cargo가 없어 XML(.rbxlx)까지만 만들었습니다. Studio는 이 파일도 그대로 엽니다."
	echo "바이너리 .rbxl이 필요하면 Rust를 설치하거나 Rojo로 'rojo build -o out.rbxl' 하세요."
	exit 0
fi

cargo build --release --quiet --manifest-path "$HERE/rbxlx2rbxl/Cargo.toml"
"$HERE/rbxlx2rbxl/target/release/rbxlx2rbxl" "$RBXLX" "$RBXL"

ls -lh "$RBXLX" "$RBXL"

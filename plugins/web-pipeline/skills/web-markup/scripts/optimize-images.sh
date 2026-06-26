#!/usr/bin/env bash
# 1MB 초과 래스터 이미지(png/jpg/jpeg)를 webp로 변환한다. 원본은 보존.
# 사용: bash optimize-images.sh [대상폴더] [최소바이트] [품질]
# 예:   bash optimize-images.sh ./assets 1048576 80
set -euo pipefail

DIR="${1:-.}"
MIN_BYTES="${2:-1048576}"   # 기본 1MB
QUALITY="${3:-80}"

have() { command -v "$1" >/dev/null 2>&1; }
filesize() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

convert_one() {
  local src="$1" out="$2"
  if have cwebp; then
    cwebp -quiet -q "$QUALITY" "$src" -o "$out"
  elif have magick; then
    magick "$src" -quality "$QUALITY" "$out"
  elif have convert; then
    convert "$src" -quality "$QUALITY" "$out"
  elif have python3 && python3 -c "import PIL" >/dev/null 2>&1; then
    python3 - "$src" "$out" "$QUALITY" <<'PY'
import sys
from PIL import Image
src, out, q = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src)
if im.mode in ("P", "LA"):
    im = im.convert("RGBA")
elif im.mode not in ("RGB", "RGBA"):
    im = im.convert("RGB")
im.save(out, "WEBP", quality=q, method=6)
PY
  else
    echo "ERROR: 변환 도구가 없습니다 (cwebp / ImageMagick / Pillow 중 하나 설치 필요)" >&2
    return 2
  fi
}

found=0; converted=0
while IFS= read -r -d '' f; do
  found=$((found+1))
  out="${f%.*}.webp"
  if [ -f "$out" ]; then echo "skip(이미 존재): $out"; continue; fi
  before=$(filesize "$f")
  if convert_one "$f" "$out"; then
    after=$(filesize "$out")
    converted=$((converted+1))
    printf "OK: %s (%d KB) -> %s (%d KB)\n" "$f" $((before/1024)) "$out" $((after/1024))
  fi
done < <(find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -size +"${MIN_BYTES}"c -print0)

echo "---"
echo "대상 ${found}개 중 ${converted}개 변환 완료. 원본은 보존됨."
echo "다음: 참조를 .webp로 갱신(rename-image.sh 또는 수동) → 확인 후 원본 정리."

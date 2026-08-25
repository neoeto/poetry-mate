#!/usr/bin/env bash
# 端到端验收(任务 5.1) —— 对照 specs/data-distribution-api 全部 Scenario。
#
# 用法:
#   ./scripts/acceptance.sh <base-url>
# 例(本地 miniflare):
#   ./scripts/acceptance.sh http://127.0.0.1:8799
#
# 依赖: curl, shasum 或 sha256sum, python3(JSON 断言)
set -euo pipefail

BASE="${1:?用法: acceptance.sh <base-url>}"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "✗ $1"; }
check(){ if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1 (期望 $3 实得 $2)"; fi; }

CURL=(curl -s --noproxy '*' --max-time 30)

# ---- L1 健康与守卫 ------------------------------------------------------
code=$("${CURL[@]}" -o /dev/null -w "%{http_code}" "$BASE/health")
check "健康检查 200" "$code" "200"

for m in POST PUT DELETE; do
  code=$("${CURL[@]}" -o /dev/null -w "%{http_code}" -X $m "$BASE/api/v1/catalog")
  check "方法守卫 $m → 405" "$code" "405"
done

# ---- L2 catalog ---------------------------------------------------------
BODY=$("${CURL[@]}" "$BASE/api/v1/catalog")
echo "$BODY" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["version"], "缺 version"
assert len(d["collections"]) >= 3, "集子不足"
ids = {c["id"] for c in d["collections"]}
assert {"tangshi","songshi","songci"} <= ids, f"缺核心集子: {ids}"
seed = next(c for c in d["collections"] if c["id"] == "seed")
assert seed.get("builtin") is True, "seed 缺 builtin 标记"
print(d["version"])
' > /tmp/acc_version.txt || bad "catalog 结构断言" 
VERSION=$(cat /tmp/acc_version.txt 2>/dev/null || echo "")
if [[ -n "$VERSION" ]]; then ok "catalog 结构与版本 ($VERSION)"; fi

CC=$("${CURL[@]}" -o /dev/null -w "%{header_json}" "$BASE/api/v1/catalog" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cache-control",""))')
[[ "$CC" == *"max-age=60"* ]] && ok "catalog 分钟级缓存头" || bad "catalog 缓存头 ($CC)"

# ---- L3 分卷清单 --------------------------------------------------------
code=$("${CURL[@]}" -o /tmp/acc_manifest.json -w "%{http_code}" \
  "$BASE/api/v1/collections/tangshi/manifest")
check "tangshi manifest 200" "$code" "200"

python3 - <<PYEOF || FAILED_MANIFEST=1
import json
m = json.load(open("/tmp/acc_manifest.json"))
entry = m["collection"]
assert entry["id"] == "tangshi"
v = entry["volumes"][0]
assert v["file"] and len(v["sha256"]) == 64 and v["bytes"] > 0 and v["records"] > 0
open("/tmp/acc_first_volume", "w").write(v["file"] + "\n" + v["sha256"])
print(f"首卷 {v['file']} ({v['records']} 条)")
PYEOF
[[ "${FAILED_MANIFEST:-0}" != "1" ]] && ok "manifest 结构完整(含 sha256/bytes/records)" || bad "manifest 结构"
FIRST_VOLUME=$(head -1 /tmp/acc_first_volume 2>/dev/null || echo "")
FIRST_SHA=$(sed -n 2p /tmp/acc_first_volume 2>/dev/null || echo "")

code=$("${CURL[@]}" -o /dev/null -w "%{http_code}" \
  "$BASE/api/v1/collections/notexist/manifest")
check "未知集子 manifest → 404" "$code" "404"

# ---- L4 分卷下载 --------------------------------------------------------
if [[ -n "$FIRST_VOLUME" ]]; then
  DL=/tmp/acc_volume.zst
  code=$("${CURL[@]}" -o "$DL" -w "%{http_code}" "$BASE/$FIRST_VOLUME")
  check "分卷下载 200" "$code" "200"

  ACTUAL=$( { shasum -a 256 "$DL" 2>/dev/null || sha256sum "$DL"; } | cut -d' ' -f1 )
  check "分卷 sha256 与 manifest 登记一致" "$ACTUAL" "$FIRST_SHA"

  CC=$("${CURL[@]}" -o /dev/null -w "%{header_json}" "$BASE/$FIRST_VOLUME" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cache-control",""))')
  [[ "$CC" == *"immutable"* ]] && ok "卷 immutable 缓存头" || bad "卷缓存头 ($CC)"

  code=$("${CURL[@]}" -o /dev/null -w "%{http_code}" "$BASE/volumes/tangshi/EVIL_PATH.json.zst")
  check "未登记路径 → 404" "$code" "404"

  CL=$("${CURL[@]}" -I --noproxy '*' -o /dev/null -w "%{header_json}" -X HEAD "$BASE/$FIRST_VOLUME" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("content-length","MISS"))' 2>/dev/null || echo "ERR")
  [[ "$CL" != "MISS" && "$CL" != "ERR" ]] && ok "HEAD 返回 content-length ($CL)" || bad "HEAD content-length"
fi

# ---- 汇总 ---------------------------------------------------------------
echo
echo "验收结果: 通过 $PASS, 失败 $FAIL"
[[ $FAIL -eq 0 ]]

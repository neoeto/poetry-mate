#!/usr/bin/env bash
# 上传一个构建版本到 R2 并切换 /current 指针。
#
# 用法:
#   ./scripts/upload-version.sh <dist版本目录> [bucket名]
# 例:
#   ./scripts/upload-version.sh ../etl/dist-full/v20260825.b8594f81
#
# 前置: npx wrangler login 已完成(或 CLOUDFLARE_API_TOKEN 已设置);
#       wrangler.toml 的 bucket_name 与目标 bucket 一致(或用第二参数覆盖)。
set -euo pipefail

DIST_DIR="${1:?用法: upload-version.sh <dist版本目录> [bucket名]}"
BUCKET="${2:-poetry-mate-data}"
VERSION="$(basename "$DIST_DIR")"

if [[ ! "$VERSION" =~ ^v[0-9]{8}\.[0-9a-f]{8}$ ]]; then
  echo "错误: 目录名不符合版本格式 vYYYYMMDD.aaaaaaaa: $VERSION" >&2
  exit 1
fi

command -v npx >/dev/null || { echo "缺少 npx" >&2; exit 1; }
[[ -f "$DIST_DIR/manifest.json" ]] || { echo "错误: $DIST_DIR 缺少 manifest.json" >&2; exit 1; }

echo "上传 $DIST_DIR → R2:$BUCKET/$VERSION/"
find "$DIST_DIR" -type f | while read -r file; do
  rel="${file#"$DIST_DIR"/}"
  key="$VERSION/$rel"
  echo "  put $key"
  npx wrangler r2 object put "$BUCKET/$key" --file "$file" --remote >/dev/null
done

# 原子切换版本指针(最后一步;此前所有客户端仍看到旧版本)
printf '{"version":"%s"}' "$VERSION" > /tmp/pm-current.json
npx wrangler r2 object put "$BUCKET/current" --file /tmp/pm-current.json --remote >/dev/null
rm -f /tmp/pm-current.json

echo "完成。当前版本指针已指向 $VERSION"
echo "回滚方法: 用相同方式把 /current 内容改回旧版本号即可。"

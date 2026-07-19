#!/bin/bash
# Threads長期アクセストークンの有効期限を延長する（60日ごとに失効するため定期実行）。
# Metaのrefresh_access_tokenは同じトークン文字列のまま有効期限だけ延長するため、
# GitHub Secrets（THREADS_TOKEN）の更新は不要。
set -uo pipefail

now() { TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M:%S JST'; }

TOKEN="${THREADS_TOKEN:?THREADS_TOKEN is not set}"

# まず現在の有効期限を確認
DEBUG=$(curl -s "https://graph.threads.net/debug_token?input_token=${TOKEN}&access_token=${TOKEN}")
echo "$(now): token check - $(echo "$DEBUG" | sed -E 's/"input_token":"[^"]*"//')"

RESP=$(curl -s "https://graph.threads.net/refresh_access_token?grant_type=th_refresh_token&access_token=${TOKEN}")
EXPIRES_IN=$(echo "$RESP" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

if [ -z "$EXPIRES_IN" ]; then
  echo "$(now): FAILED refresh - $RESP"
  echo "$(now): NOTICE トークンの自動更新に失敗しました。手動でMeta for Developersのアクセストークンを再発行し、GitHub SecretsのTHREADS_TOKENを更新してください。"
  exit 1
fi

echo "$(now): OK refreshed - expires_in=${EXPIRES_IN}s (about $((EXPIRES_IN / 86400)) days)"

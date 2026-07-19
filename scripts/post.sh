#!/bin/bash
# GitHub Actions runner用の投稿スクリプト。
# 使い方: bash scripts/post.sh queue/0200.txt
# 環境変数:
#   THREADS_TOKEN … Threads長期アクセストークン（GitHub Secretsから注入。DRY_RUN=trueの時は不要）
#   DRY_RUN        … "true" の場合、実際の投稿は行わずログのみ出力する（ドライラン用）
set -uo pipefail

QUEUE_FILE="${1:?usage: post.sh <queue-file-path>}"
DRY_RUN="${DRY_RUN:-false}"

now() { TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M:%S JST'; }

if [ ! -f "$QUEUE_FILE" ]; then
  echo "$(now): ERROR queue file not found - file=$QUEUE_FILE"
  exit 1
fi

# Meta bot検知対策のランダム遅延（0〜600秒 = 0〜10分）。PC版post.shと同じロジック。
DELAY=$((RANDOM % 601))
echo "$(now): DELAY ${DELAY}s before posting - file=$QUEUE_FILE"
sleep "$DELAY"

if [ "$DRY_RUN" = "true" ]; then
  echo "$(now): [DRY RUN] Would post now (delay was ${DELAY}s) - file=$QUEUE_FILE"
  echo "----- content preview -----"
  cat "$QUEUE_FILE"
  echo "----------------------------"
  echo "$(now): [DRY RUN] Skipped actual Threads API calls. No post was published."
  exit 0
fi

TOKEN="${THREADS_TOKEN:?THREADS_TOKEN is not set}"

CREATE=$(curl -s -X POST "https://graph.threads.net/v1.0/me/threads" \
  --data-urlencode "media_type=TEXT" \
  --data-urlencode "text@${QUEUE_FILE}" \
  --data-urlencode "access_token=${TOKEN}")

CID=$(echo "$CREATE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$CID" ]; then
  echo "$(now): FAILED create - $CREATE - file=$QUEUE_FILE"
  exit 1
fi

sleep 3

PUB=$(curl -s -X POST "https://graph.threads.net/v1.0/me/threads_publish" \
  --data-urlencode "creation_id=${CID}" \
  --data-urlencode "access_token=${TOKEN}")

PID=$(echo "$PUB" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$PID" ]; then
  echo "$(now): FAILED publish - $PUB - file=$QUEUE_FILE"
  exit 1
fi

echo "$(now): OK file=$QUEUE_FILE publish=$PUB"

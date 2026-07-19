# PC依存脱却: GitHub Actions移行手順書

Threads自動投稿を、PC(Windowsタスクスケジューラ)からGitHub Actionsへ移行するための手順。
**二重投稿を防ぐため、必ず1枠ずつ順番に切り替えること。**

## 全体の流れ

1. リポジトリ作成・push・Secrets登録（完了）
2. **ドライラン期間（2日間）**: GitHub Actionsは全枠 `DRY_RUN: "true"` のまま動かし、ログだけ確認する。PC側は今まで通り本番投稿を継続
3. **3日目から1枠ずつ切り替え**: 問題なければ、以下の「1枠切り替え手順」を9枠×2系統ぶん繰り返す
4. 全枠の切り替えが終わったらPC側タスクスケジューラを無効化（削除はしない）

---

## ドライラン期間中の確認方法

1. GitHubリポジトリの `Actions` タブを開く
2. 各ワークフロー（`Threads Post 02:00 JST` など）の実行ログを確認
3. ログに以下が出ていればOK:
   - `DELAY ○○s before posting`（ランダム遅延が効いている）
   - `[DRY RUN] Would post now ...` と投稿内容のプレビュー
   - `[DRY RUN] Skipped actual Threads API calls. No post was published.`
4. `queue/HHMM.txt` と `queue2/HHMM.txt` の**両方**のステップが緑（成功）になっているか確認
5. 2日間、9枠×2系統すべてで上記が確認できればドライラン合格

途中でエラーが出た場合はここで対応し、切り替えフェーズには進まないこと。

---

## 1枠切り替え手順（9枠×2系統ぶん繰り返す）

例として `0200` 枠を切り替える場合:

### ステップ1: GitHub Actions側を本番投稿モードにする
1. `.github/workflows/post-0200.yml` を開く
2. `DRY_RUN: "true"` → `DRY_RUN: "false"` に変更
3. コミットしてpush（このリポジトリで作業しているなら、Claudeに「0200枠を本番に切り替えて」と言えば代行可能）

### ステップ2: PC側の同じ枠を無効化する（二重投稿防止）
Actions側の次回実行時刻**より前**に、以下をPowerShellで実行して無効化する:

```powershell
schtasks /change /tn "ThreadsPost_0200" /disable
schtasks /change /tn "ThreadsPost2_0200" /disable
```

**重要**: ステップ1とステップ2の順番は必ずこの通り（Actionsを有効化 → PCを無効化）。逆にすると、その日のその枠だけ投稿が飛ぶ可能性がある。ギリギリだと不安な場合は、Actions切り替え後の初回実行をまたいでからPC側を無効化してもよい（その場合は一時的に同じ内容が2回投稿されるリスクと引き換えなので、状況に応じて判断）。

### ステップ3: 次回実行で確認
1. その枠の時刻が来たら、GitHub Actionsの実行ログで実際に投稿されたか確認（`OK file=... publish={"id":...}`）
2. Threadsアプリ上でも投稿が反映されているか確認
3. PC側タスクスケジューラで `Scheduled Task State: Disabled` になっていて、`Last Run Time` が更新されていないことを確認（= PC側は動いていない）

### ステップ4: 問題なければ次の枠へ
1枠につき1日1回しか実行タイミングがないため、**1つの枠を切り替えたら、最低1回の実行結果を確認してから次の枠に進む**（同時に複数枠を切り替えない）。

---

## ロールバック手順（切り替え後に問題が起きた場合）

Actions側に問題が起きた場合、いつでもPC側に戻せる:

```powershell
schtasks /change /tn "ThreadsPost_0200" /enable
schtasks /change /tn "ThreadsPost2_0200" /enable
```

同時に、該当ワークフローの `DRY_RUN` を `"true"` に戻してpushし、Actions側を止める。

---

## 全枠切り替え完了後

- PC側の9タスク×2系統は無効化されたまま**しばらく保持**する（削除しない。ロールバック用）
- `C:\Users\megme\.threads\queue` `queue2` のローカルコピーも当面は残す
- 動作が安定してから（目安1〜2週間）、PC側タスクの削除やローカルフォルダの整理を検討する
- 以降、`/threads-refresh` での投稿文編集は **このリポジトリの `queue/` `queue2/`** に対してのみ行えばよい（PC側への手動反映は不要になる）

# NEON FLORA 開発メモ

作業中に発見したバグ、ワークアラウンド、知見を記録する。
作業開始前に必ず読み返すこと。

---

## 仕様書バージョン管理

- v0.2.1: Gate 0.9 全ディレクター承認済
- v0.3.0: プロデューサーFB反映済（5ライン化、BLK廃止、ゲーム数管理化、チェリー配当逆転、ICE技術介入、BIG_RED/BLUE統合揃え、3連BEL等）
- **specification_fb.md は編集不可**（FB原本として保持）

## 既知の注意点

### SymbolTable.get_name() は使えない
- `RefCounted.get_name()` がビルトインで存在するため名前衝突する
- `get_symbol_name()` にリネーム済み
- 他のstatic classでも `get_name` / `get_class` 等のビルトイン名は避けること

### v0.3.0更新完了（プリプロ）
- 全10本のスクリプト + 新規3本がv0.3.0仕様に対応済み
- BLK除去、5ライン判定、ゲーム数管理、ICE技術介入、統合7揃え、rt_bonus_rate
- `pay_table.gd` の定数名: `PAYOUT_PER_LINE`, `BIG_MAX_GAMES=45`, `REG_MAX_GAMES=14`
- `bonus_controller.gd` の変数名: `bonus_games_played`(リプ除外), `bonus_type_internal`

### Godotプロジェクト初期化時の注意
- 新規プロジェクトは `--editor --quit` で `.godot/` キャッシュを生成してから `--check-only` を実行
- `--check-only` はエラーがないとプロセスが終了しない（タイムアウトで判定）

### windows/ ディレクトリ
- `.gdignore` を配置してエクスポートパック対象外にすること
- スクリーンショット等のテスト成果物がPCKに含まれてしまう

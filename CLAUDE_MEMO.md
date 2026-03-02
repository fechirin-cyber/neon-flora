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

### Android APK ビルドの必須条件
- `project.godot` に `textures/vram_compression/import_etc2_astc=true` が**必須**
- これがないと "configuration errors" で即失敗する（エラー詳細は表示されない）
- `export_presets.cfg` のキーストアパスは `C:/Android/Sdk/debug.keystore`（editor_settings準拠）
- 旧パス `C:/android-sdk/` ではなく `C:/Android/Sdk/` を使うこと

### windows/ ディレクトリ
- `.gdignore` を配置してエクスポートパック対象外にすること
- スクリーンショット等のテスト成果物がPCKに含まれてしまう

### HuggingFace API エンドポイント変更 (2026-03)
- **旧**: `https://api-inference.huggingface.co/models/...` → **410 Gone**
- **新**: `https://router.huggingface.co/hf-inference/models/...`
- `tools/gen_*.py` のAPI_URLを新エンドポイントに更新済み
- HF_API_KEY は環境変数で渡す（`rpg_game/tools/gen_title_bg.py` にトークンあり）

### Pythonスクリプトの cp932 エンコーディング問題（Windows）
- Windows のコンソールはデフォルト cp932（Shift_JIS）
- **em dash `—` (U+2014) は cp932 に変換できない** → `UnicodeEncodeError` でクラッシュ
- `print()` 文に `—` を使わないこと。代わりに `-` を使う
- 同様に全角ダッシュ、特殊な Unicode 記号も避ける
- 対象ファイル: `tools/gen_*.py`, `tools/remove_bg.py` 等

### Godot の `:=` は nullable 返り値に使えない
- `var tex := AssetRegistry.load_texture("path")` → **型推論エラー**
- 関数が `null` を返す可能性がある場合、`:=` で型推論できない
- **正**: `var tex: Texture2D = AssetRegistry.load_texture("path")`
- **誤**: `var tex := AssetRegistry.load_texture("path")`
- 全ての `load_*()` 系関数で同じ。`load()`, `preload()` は OK（nullを返さないため）

### `--check-only` で class_name が見つからない問題
- `.godot/global_script_class_cache.cfg` を削除すると全 `class_name` が未解決になる
- `--check-only` モードではキャッシュを再構築しない（設計上の制限）
- **回避策**: `--check-only` をスキップし、直接EXEビルドで検証する
- EXEエクスポート時は正常にクラス解決される

### AssetRegistry パターン（差し替え構造）
- 全アセットパスを `scripts/data/asset_registry.gd` に集約
- 外注アセット差し替え時はこのファイルのパスを変えるだけ
- `load_*()` 関数は全て nullable → 呼び出し側で明示的型指定必須
- プレースホルダー生成で欠損アセットでもクラッシュしない
- `create_placeholder(size, color)` で代替テクスチャを動的生成

### AI画像生成の限界と対策
- **AIはテキストを正確に描画できない**: BAR → "OAR" 等の誤描画が発生
- **対策**: テキスト含む図柄（BAR, 7）は `Pillow + system font` でプログラム生成
- `tools/gen_programmatic_symbols.py` で Impact フォント + 多層ネオングロー
- 非テキスト図柄（CHR, BEL, ICE, RPL）は統一プロンプトでAI生成OK
- **キャラクター一貫性**: "MUST HAVE:" プレフィクスで特徴を強調すると改善する
- プロンプトに具体的な外見特徴（髪色、目の色、服装、アクセサリー）を列挙

### rembg による背景除去
- `pip install rembg onnxruntime` で導入
- 初回実行時に u2net.onnx (176MB) を自動ダウンロード
- `tools/remove_bg.py` で全キャラ画像の背景を透過化
- オリジナルは `_backup_with_bg/` にバックアップ
- Godot での表示は `STRETCH_KEEP_ASPECT_CENTERED` と併用

### キャラクター画像のバックアップ戦略
- 再生成前: `_backup_pre_hires/` にバックアップ（gen_hires_characters.py）
- 背景除去前: `_backup_with_bg/` にバックアップ（remove_bg.py）
- 問題があれば即座にバックアップから復元可能

### テスト実行時の音量
- テスト用EXE起動時は `-- --auto-test` 引数を付けること
- AudioManager._ready() でマスターバスを -60dB に設定（ミュートではない最小音量）
- プロデューサー指示: テスト中はうるさくならないよう音を最小にする

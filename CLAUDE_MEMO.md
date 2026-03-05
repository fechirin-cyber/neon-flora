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

### 実装後パイプラインを絶対に飛ばすな

- **CLAUDE.mdにルールが明記されているのに従わなかった。言い訳不可。**
- 「速く終わらせたい」は理由にならない。パイプラインは品質保証の仕組み。
- 実装完了後は以下を必ず回す:
  1. **tech-lead** → コードレビュー
  2. **qa** → ビルド+テスト
  3. **ui-designer** → UI/UXチェック
  4. **各ディレクター** → 監査（tech-director, art-director, qa-director）
- 全ディレクターAPPROVEなしでプロデューサーに報告しない
- 大きなタスクは複数エージェント並列起動する
- **失敗例（2026-03-04）**: β必達4機能を全てリードプログラマー単独で実装し、エージェントレビューを一切回さずにプロデューサーに報告した。CLAUDE.mdは7Mの時点でシステムプロンプトに全文あった。読んでいたのに従わなかった。再発厳禁。

---

### 実機パチスロ リール挙動パラメータ（法規制/特許/実測）

**法規制**（遊技機の認定及び型式の検定等に関する規則 別表第5）:
- 回転速度: **80 RPM 上限**（1分間に80回転を超えるものでないこと）
- 停止時間: **190ms 以内**（ボタン操作後190ms以内に停止するものであること）
- ウェイト: **4.1秒**（3号機以降の法規制）
- シンボル数: 1リールあたり最大 **21コマ**

**実機パラメータ（4号機A-Type準拠）**:
- 回転速度: 79.5〜79.9 RPM（規制上限ギリギリ）
- 1コマ通過: **35.7ms** (0.75秒/周 ÷ 21コマ)
- 最大滑り: **4コマ** (190ms / 35.7ms ≒ 5.3コマから安全マージン)
- 加速時間: **約0.4秒** (特許JP2002159626A)
- 停止方式: **ステッピングモーター即停止**（減速カーブなし、全相励磁制動）
- バウンス: 極微小（ホールディングトルクで即座に位置保持）

**NEON FLORA 実装値**:
- `MAX_SPEED = 4592.0` px/sec (80RPM × 21コマ × 164px)
- `ACCEL_TIME = 0.4` 秒
- 停止: **即座にスナップ停止**（request_stop → _snap_to_position → _start_bounce）
- 状態遷移: IDLE → ACCELERATING → FULL_SPEED → BOUNCING → IDLE
- バウンス: 1.5px / 50ms（実機の微振動再現）
- STOPボタン有効化: 全リールフル回転到達後（`accel_done`シグナル）
- **_current_speed は停止時に必ず 0.0 にリセット**（ブラーシェーダー連動のため）

**絶対にやってはいけないこと**:
- ease-out / ease-in-out 等の減速カーブで停止させる（実機にない）
- MIN_STOP_SYMBOLS 等で余分な巡航を入れる（実機にない）
- 停止に190msを超える時間をかける（法規制違反）
- SLIP_STOPPING状態でフル速度コマ送りを再導入する場合、**リール回転方向との整合性に注意**
  - リール回転: center DECREASING (10→9→8→...)
  - reel_logic滑り: pressed_pos + slip (INCREASING: 10→12)
  - posmod(center - target, 21) → 19コマ大回りの原因になる

---

### α MUST修正完了記録 (2026-03-05)
- M-1: LEFT リール配列を仕様書§4.3に合わせた（S7R×1, BEL×9, 3連BEL配置）
- M-2: game_bg.png ダークネイビー基調に再生成
- M-3/M-4: luna/koharu画像再生成（AI限界で完全一致せず、β段階でプロイラスト差替え予定）
- M-5: cherry_win ダッキング追加（-6dB, attack:0.1, release:0.5）
- M-6: agent_guide.md API表記修正（play→play_se）
- M-7: ボーナス中キャラクター維持修正（_in_bonusフラグ）
- S-8: specification.md ヘッダーv0.5.0更新
- CENTER/RIGHTリール配列は仕様書と順序が異なるが図柄分布は一致（既知、βで再検討）
- luna画像: ショートボブのまま（AI生成限界）→ β段階でプロイラスト差替え必須

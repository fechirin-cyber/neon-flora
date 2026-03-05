# NEON FLORA — エージェントガイド

**最終更新**: 2026-03-01
**現在のフェーズ**: α（プリプロ完了済み）

全エージェントは作業開始前にこのドキュメントを Read すること。
自分のロールに該当するセクションの要件に従って作業する。

---

## プロジェクト概要（全ロール共通）

| 項目 | 値 |
|---|---|
| ジャンル | 超本格パチスロ 4号機A-Type（ハナビ準拠） |
| エンジン | Godot 4.3 / GDScript |
| Viewport | 900x1600 (portrait) |
| プラットフォーム | Windows + Android |
| GitHub | fechirin-cyber/neon-flora |
| プロジェクトパス | `C:\xampp\htdocs\rpg_game\neon_flora` |

### コンセプト
**「超本格4号機 × VTuber × ネオン花火」**
- 実機パチスロの挙動を忠実に再現（消灯・フラッシュ・遅れ・たーまやー）
- VTuber風キャラ3人がリアクション演出で感情を増幅
- サイバー和風（Cyber-Japanesque）のビジュアルテーマ

### キャラクター
| 名前 | 担当 | テーマカラー | 特徴 |
|---|---|---|---|
| 七瀬ひかり | 通常時ナビ | ネオンピンク (#FF1493) | ツインテール、オッドアイ(左シアン/右ゴールド)、LEDリングヘアアクセ、片耳ヘッドフォン |
| 藍川るな | BIG担当 | シアンブルー (#00D4FF) | ストレートロング、ディープブルー～パープル、猫耳ヘッドセット |
| 朝日こはる | REG担当 | アンバーオレンジ (#FFB347) | ゆるふわウェーブ、パステルオレンジ、和風帯リボン、花簪マイク |

### Autoload（3つ）
| Name | Script | 責務 |
|---|---|---|
| GameData | scripts/persist/game_data.gd | 設定・永続化・統計 |
| SlotEngine | scripts/engine/slot_engine.gd | 内部抽選・フラグ管理・滑り制御・状態遷移 |
| AudioManager | scripts/audio/audio_manager.gd | SE/BGM管理 |

### 主要ドキュメント
| ドキュメント | パス |
|---|---|
| 企画書 | `docs/proposal.md` |
| 仕様書 (v0.3.0) | `docs/specification.md` |
| UI仕様 | `docs/ui_design.md` |
| 開発メモ | `CLAUDE_MEMO.md` |

---

## プランナー要件

### ゲームシステム知識
- **内部抽選**: 65536分母（16bit）、レバーON時に抽選
- **リール制御**: 3リール×21コマ、最大4コマ滑り（フラグに基づく引き込み/蹴り）
- **有効ライン**: 5本（横上段・横中段・横下段・斜め右下がり・斜め右上がり）
- **ボーナス**: BIG (45G/リプ除外) / REG (14G/リプ除外) / RT (40G/BIG後のみ)
- **BLK図柄なし**: 全21コマを有効図柄で構成
- **ICE技術介入**: ボーナス中、ICE当選時に最終停止リールの引き込み猶予1コマ
- **BIG_RED/BLUE統合揃え**: 内部フラグ問わずプレイヤー目押しで赤7・青7選択可

### バランスパラメータ
- 設定1ボーナス合算: 約1/174.3 → 設定6: 約1/141.2
- BIG期待配当: 約345枚 / REG期待配当: 約108枚
- RT中リプレイ確率: 約1/1.8（通常時の約4倍）
- BIG_BLUE後RTはボーナス当選確率1.5倍補正

### 仕様書での注意
- `specification_fb.md` は**編集不可**（プロデューサーFB原本）
- 仕様変更時は先に `specification.md` を更新してからコード変更

---

## アーティスト要件

### カラーパレット

| 役割 | HEX | 色名 | 用途 |
|---|---|---|---|
| Primary | #FF1493 | ネオンピンク | ひかりテーマ、UIメインアクセント |
| Secondary | #00D4FF | シアンブルー | るなテーマ、7セグLED基調 |
| Tertiary | #FFB347 | アンバーオレンジ | こはるテーマ、温かみUI |
| Accent | #B14EFF | エレクトリックパープル | 特殊演出、高期待度 |
| BG Dark | #0A0A1A | ミッドナイト | メイン背景、筐体ボディ |
| BG Mid | #1A1A2E | ダークネイビー | パネル背景、リール枠内 |
| Surface | #2D2D44 | スレートグレー | ボタン背景、UI部品 |
| Text | #EAEAFF | ゴーストホワイト | メインテキスト |
| LED | #00FF88 | ネオングリーン | 7セグ表示 |
| Gold | #FFD700 | ゴールド | BIG装飾、高設定示唆 |

### プロンプトガイドライン（AI画像生成）
- スタイル: `anime VTuber portrait, bust shot, dark navy background #0A0A1A, neon rim lighting, clean sharp anime linework, soft cel shading, high detail, 4K, no text, no watermark`
- **AIはテキストを正確に描画できない**: BAR/7はPillow+フォントでプログラム生成
- 非テキスト図柄(CHR/BEL/ICE/RPL)は統一プロンプトでAI生成OK
- キャラクター一貫性: "MUST HAVE:" プレフィクスで特徴（髪色、目、装飾品）を強調

### アセット生成ツール
| ツール | パス | 用途 |
|---|---|---|
| gen_programmatic_symbols.py | `tools/` | BAR/赤7/青7（Pillow+Impact） |
| gen_unified_symbols.py | `tools/` | CHR/BEL/ICE/RPL（FLUX API） |
| gen_hires_characters.py | `tools/` | 全キャラ10枚（1024x1024） |
| gen_concept_art.py | `tools/` | コンセプトアート+タイトル背景 |
| remove_bg.py | `tools/` | rembgで背景除去 |

### AssetRegistry パターン
- 全アセットパスは `scripts/data/asset_registry.gd` に集約
- 外注アセット差し替え時はこのファイルのパスを変更するだけ
- `load_*()` 関数は全てnullable → 呼び出し側で明示的型指定必須

---

## サウンド要件

### SE一覧（23種）

| ID | タイミング | 音像 |
|---|---|---|
| lever_pull | レバーON | 金属スプリングのガチャ音 |
| reel_start | リール回転開始 | モーター起動の「フィーン」 |
| reel_stop_l | LEFT停止 | 低めのカチッ（220Hz） |
| reel_stop_c | CENTER停止 | 中音のカチッ（330Hz） |
| reel_stop_r | RIGHT停止 | 高めのカチッ（440Hz） |
| bet_insert | BETボタン | メダル投入チャリン |
| medal_out | 配当開始 | メダル連続落下ジャラジャラ |
| medal_single | 1枚ごと | 単発チャリン |
| wait_tick | ウェイト中1秒毎 | 「ピッ」(1000Hz, 50ms) |
| big_fanfare | BIG開始 | 3秒ファンファーレ（Cメジャー） |
| reg_fanfare | REG開始 | 2秒ファンファーレ（控えめ） |
| bonus_end | ボーナス終了 | 終了ジングル（1.5秒） |
| cherry_win | チェリー入賞 | 軽いチャイム（2音） |
| bell_win | ベル入賞 | 明るいチャイム（3音、上行） |
| replay_win | リプレイ入賞 | 短い電子音（ピロン） |
| ice_win | 氷入賞 | クリスタル音（きらきら） |
| reach_me | リーチ目検出 | 緊張感のある低音（80Hz） |
| tamaya | たーまやーランプ | ひかりボイス「たーまやー！」|
| blackout | 消灯演出 | 低い「ドン」（100Hz） |
| flash | フラッシュ(SPARK-DROP) | キラッ高音（2000Hz） |
| flash_premium | フラッシュ(BLOOM-TAMAYA) | 豪華なきらめき |
| bonus_align | ボーナス図柄揃い | ドラマチックヒット音 |
| rt_start | RT開始 | 上昇音（ピロロロ） |

### BGM一覧（5曲）

| ID | シーン | BPM | スタイル | キー |
|---|---|---|---|---|
| title | タイトル画面 | 100 | エレクトロポップ | Ebメジャー |
| normal | 通常時 | 90 | チルホップ/ローファイ | Cマイナー |
| bonus_big | BIG中 | 140 | アップテンポEDM | Aメジャー |
| bonus_reg | REG中 | 120 | ファンクポップ | Gメジャー |
| rt | RT中 | 110 | テンスエレクトロ | Dマイナー |

### 音量バランス
- Master: 0dB / BGM: -8dB / SE: -3dB
- ファンファーレ時BGMダッキング: -20dB → 0.5秒復帰
- テスト中: `-- --auto-test` でマスター -60dB

### AudioManager API
```gdscript
AudioManager.play_se("lever_pull")    # SE再生
AudioManager.play_bgm("normal")      # BGM切替
AudioManager.play_bgm("bonus_big", 0.5)  # フェードイン0.5秒
AudioManager.stop_bgm(0.3)           # フェードアウト0.3秒
```

---

## VFX要件

### 演出一覧

| 演出 | 種類 | 実装方式 |
|---|---|---|
| 消灯(4段階) | リール暗転 | ColorRect alpha (0.0/0.3/0.55/0.8) |
| フラッシュ(8種) | 花火モチーフ | ShaderMaterial + Tween |
| 遅れ | リール回転0.4秒遅延 | await + シグナル |
| たーまやー | ランプ点滅+ボイス | Label + Tween.set_loops |
| リールグロー | 入賞図柄発光 | ShaderMaterial |
| ドラム曲面 | リール立体感 | canvas_item シェーダー |
| ガラス反射 | リール窓 | canvas_item シェーダー |
| 呼吸アニメ | タイトル文字明滅 | Tween (modulate:a 0.7↔1.0) |

### フラッシュ8種の色彩定義
| # | 名前 | カラー | 期待度 |
|---|---|---|---|
| 1 | SPARK | 白 #FFFFFF | 最低 |
| 2 | GLITCH | シアン #00D4FF | 低 |
| 3 | NEON_SIGN | グリーン #00FF88→シアン | 中 |
| 4 | STROBE | 白→ピンク #FF1493 | 中～高 |
| 5 | DROP | ゴールド #FFD700 | 高 |
| 6 | BLOOM | パープル #B14EFF→ゴールド | 超高 |
| 7 | STARMINE | 全色ランダム | BIG確定級 |
| 8 | TAMAYA | ゴールド全画面+赤リング | プレミアム |

### Tween注意事項
- 新Tweenを作る前に前のTweenを `kill()` すること
- `create_tween()` を使用（`get_tree().create_tween()` は非推奨）
- AnimatableBody2D の回転にTweenは使わない（物理フレームと非同期）

---

## UIデザイナー要件

### レイアウト（7ゾーン / 900x1600）

| Zone | 名称 | Y範囲 | 高さ | 内容 |
|---|---|---|---|---|
| 1 | ステータスバー | 40-90 | 50px | GameState, 総ゲーム数, BIG/REG回数 |
| 2 | データカウンター | 100-180 | 80px | CREDIT, IN, OUT（7セグ風） |
| 3 | リール表示窓 | 200-560 | 360px | 3リール×3段、各図柄200×160px |
| 4 | 演出情報 | 580-740 | 160px | フラグ表示、消灯、リーチ目、WIN |
| 5 | ボタンパネル | 760-980 | 220px | BET/LEVER/STOP×3（**120px viewport 以上**） |
| 6 | キャラクター | 1000-1400 | 400px | VTuberリアクション |
| 7 | ヘルプ | 1420-1580 | 160px | 操作説明、デバッグ |

### スマートフォン視認性・操作性基準（必須）

**詳細は `docs/ui_design.md` セクション3 を参照。** 以下は要約。

#### テキスト視認性
- **最小保証デバイス**: 720px幅 / 320dpi（スケール 0.80x）
- プレイヤー向けテキスト: **24px viewport 以上**（物理 1.5mm以上）
- 補助テキスト（ヘルプ等）: **22px viewport 以上**（物理 1.4mm以上）
- 18px はデバッグ専用。リリースビルドで非表示にすること
- 行間: フォントサイズの **1.3倍以上**

#### タッチ操作性
- 主操作ボタン（BET/LEVER/STOP）: **120x120px viewport 以上**（物理 9.6mm / 48dp相当）
- 副操作ボタン（設定、戻る等）: **90x90px viewport 以上**（物理 7.2mm / 36dp相当）
- 隣接ボタン間隔: **20px viewport 以上**
- 画面端余白: **30px viewport 以上**

#### カラーコントラスト（WCAG 2.1 AA）
- 通常テキスト: 背景に対して **4.5:1 以上**
- 大テキスト (24px Bold / 28px以上): **3.0:1 以上**
- Muted Gray は **#8888A0** を使用（旧 #666680 はコントラスト不足）

### デザイン基準
- 実機パチスロ風レイアウト（ランプ→液晶→リール窓→ボタン）
- ネオンピンク + ダークネイビーのサイバー和風トーン
- クロームフレーム + 7セグLED + ベベルボタンで筐体再現
- ボタン配置: BET左 / LEVER中央 / STOP×3右寄り
- 有効/無効の視覚区別: 有効=ネオン発光、無効=暗転グレー
- 全図柄は色と形状の両方で判別可能であること（色覚多様性配慮）

### フォント階層
| レベル | サイズ | 最小物理高さ | 用途 |
|---|---|---|---|
| H1 | 32px | 2.0mm | ゲーム状態表示 |
| H2 | 28px | 1.8mm | クレジット、統計 |
| Body | 24px | 1.5mm | 演出情報、リーチ目告知 |
| Button | 24px | 1.5mm | ボタンラベル |
| Caption | 22px | 1.4mm | ヘルプ |
| Debug | 18px | 1.1mm | デバッグ専用（リリース非表示） |

---

## テクニカルリード要件

### アーキテクチャ必須ルール
1. **SlotEngine はUIを参照しない** — シグナル経由で通知する純粋ロジック層
2. **内部抽選は65536分母** — `randi() % 65536`
3. **リール滑りは最大4コマ** — 4号機準拠
4. **有効ラインは5本** — 全ライン独立判定
5. **ボーナスはゲーム数管理** — BIG=45G / REG=14G（リプレイ除外）

### NEON FLORA 固有チェックリスト
- [ ] `AssetRegistry.load_*()` の戻り値をnullチェックしているか（`:=` 使用不可）
- [ ] `SymbolTable.get_name()` ではなく `get_symbol_name()` を使っているか（ビルトイン名衝突回避）
- [ ] SlotEngine からUI要素（Node、Label等）を直接参照していないか
- [ ] ボーナスゲーム数でリプレイを除外しているか（`bonus_games_played` はリプ除外カウント）
- [ ] 5ライン判定が全ラインで行われているか（横3+斜め2）
- [ ] `specification_fb.md` を編集していないか

### 既知の技術的注意点
- `RefCounted.get_name()` はビルトイン → `get_symbol_name()` にリネーム済み
- Godot の `:=` はnullable返り値に使えない → 明示的型指定
- `--check-only` で class_name が見つからない場合 → `.godot/` キャッシュの問題。直接EXEビルドで検証

---

## QA要件

### テストスクリプト（14本）
| # | テスト名 | スクリプト | 内容 |
|---|---|---|---|
| 1 | gameplay_basic | test_gameplay.ps1 | BET→LEVER→STOP×3→判定 3ゲーム |
| 2 | bonus_cycle | test_bonus_cycle.ps1 | BIG強制→消化→RT→復帰 |
| 3 | reg_cycle | test_reg_cycle.ps1 | REG強制→消化→通常復帰 |
| 4 | reach_me | test_reach_me.ps1 | リーチ目パターン検証 |
| 5 | credit_boundary | test_credit.ps1 | credit=0不可、9999上限 |
| 6 | rapid_input | test_rapid.ps1 | 全ボタン高速連打 |
| 7 | wait_timer | test_wait.ps1 | 4.1秒ウェイト確認 |
| 8 | save_load | test_save.ps1 | セーブ→再起動→復帰 |
| 9 | bonus_interrupt | test_interrupt.ps1 | BONUS中終了→復帰 |
| 10 | rt_bonus | test_rt_bonus.ps1 | RT中BIG当選→RT破棄 |
| 11 | long_play | test_long.ps1 | 100G連続（メモリ5%以内） |
| 12 | screenshot_all | test_screenshots.ps1 | 全画面スクリーンショット |
| 13 | delay_tamaya | test_delay.ps1 | 遅れ/たまや検証 |
| 14 | reel_stop_verify | test_reel_stop.ps1 | 全フラグ停止位置検証 |

### デバッグ出力
- `windows/debug_state.json` — Pキーで出力
- `windows/screenshots/*.png` — テスト中自動撮影
- テスト用EXE起動: `-- --auto-test` 引数（マスター -60dB）

### 重点エッジケース
- credit=0でBET不可
- ボーナスゲーム数カウント（リプレイ除外の正確性）
- RT中ボーナス当選時のRT即破棄
- ICEビタ押し（引き込み猶予1コマ）の成功/失敗判定
- WAITING中の全ボタン無効

---

## ゲームデザインリード要件

### 市場比較基準
- **ジャンル**: 4号機A-Typeパチスロシミュレーター
- **ブルーオーシャン**: 市場にほぼ不在（完全再現系アプリが少ない）
- **競合**: パチスロ小役カウンター、シミュ系アプリ
- **差別化**: VTuber演出 + 超本格筐体再現 + ネオンサイバー美学

### コンセプト適合チェック
- ハナビの「味」（目押し感、リーチ目の楽しさ、消灯法則読み）を再現しているか
- VTuberキャラが演出の感情増幅装置として機能しているか
- サイバー和風の世界観が統一されているか
- ターゲット層（パチスロ経験者25-40代 / VTuber好き18-30代）に適切か

### ゲーム体験チェック
- BET→LEVER→STOP→判定のゲームループが「もう1G」を誘発するか
- フィードバック密度: 消灯・フラッシュ・リーチ目が適切な頻度で出現するか
- テンポ: 4.1秒ウェイトが体感で長すぎないか
- 長期モチベーション: 収支グラフ、設定判別、称号等の設計があるか

---

## ディレクター共通要件

### アートディレクター
- ネオンピンク×ダークネイビーの世界観統一を監査
- 図柄のスタイル統一性（7種が同一のレンダリングスタイルか）
- キャラクター3人の一貫性（同一世界の住人に見えるか）
- 実機筐体の質感再現度（クローム、LED、バックライト）

### テクニカルディレクター
- SlotEngine の純粋ロジック層保証（UI参照なし）
- メモリリーク検証（100G連続プレイ時5%以内）
- 状態遷移の完全性（全遷移パスが実機準拠か）
- AssetRegistry パターンの正確な適用

### サウンドディレクター
- SE 23種 + BGM 5曲の世界観統一
- パチスロ実機の音響体験との比較
- ダッキングルールの適切さ（ファンファーレ vs BGM）
- ストップ音の音程差（L/C/R: 220/330/440Hz）がリール停止フィードバックとして機能するか

### QAディレクター
- テスト14本の網羅性（全状態遷移パスがカバーされているか）
- 単体テスト9件（reel_logic）の合格基準の妥当性
- スクリーンショットチェック項目の網羅性
- 出荷基準: 全テストPASS + 全スクショ正常 + メモリ基準以内

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|---|---|---|
| 2026-03-01 | 1.0 | 初版作成（proposal.md, specification.md v0.3.0, CLAUDE_MEMO.md から抽出） |

# NEON FLORA alpha テストプレイレビュー

**日付**: 2026-03-01
**フェーズ**: プリプロ完了 → alpha移行
**ビルド**: EXE 82.8MB (test_gameplay.ps1 ALL TESTS PASSED)
**レビュー方式**: ワーカー6名 → ディレクター5名監査 → 条件付き承認

---

## 総合判定テーブル

| # | ワーカー | ワーカー判定 | ディレクター | ディレクター判定 |
|---|---|---|---|---|
| 1 | プランナー | CONDITIONAL | ゲームデザインリード | **CONDITIONAL** |
| 2 | テクニカルリード | PASS with NOTES | テクニカルディレクター | **CONDITIONAL** |
| 3 | アーティスト | CONDITIONAL | アートディレクター | **CONDITIONAL** |
| 4 | VFXデザイナー | CONDITIONAL PASS | アートディレクター | (上記に統合) |
| 5 | UIデザイナー | PASS with SUGGESTIONS | アートディレクター | (上記に統合) |
| 6 | サウンドデザイナー | CONDITIONAL PASS | サウンドディレクター | **CONDITIONAL** |
| — | — | — | QAディレクター | **CONDITIONAL SHIP** |

**総合判定: CONDITIONAL APPROVE (BLOCKなし)**

---

## alpha フェーズ要件充足マトリクス

| 要件 | 状態 | 詳細 |
|---|---|---|
| コアゲームサイクル動作 | **OK** | BET→LEVER→STOP×3→判定→IDLE復帰が安定動作 |
| リール描画(SubViewport) | **OK** | 3リール連続スクロール、バウンス停止、図柄7種組込 |
| 7セグ表示 | **OK** | DSEG7フォント、CREDIT/PAYOUT/BET、非点灯セグメント |
| ボタンパネル | **CONDITIONAL** | 色分け動作、ベベルシェーダー未適用、LEDインジケータ未実装 |
| 消灯/フラッシュ演出 | **CONDITIONAL** | 消灯4段階OK、フラッシュ8種（色・タイミング差あり、形状差なし） |
| 遅れ/たまや | **CONDITIONAL** | シグナル接続OK、reel_start SE遅延にタイミング問題 |
| リーチ目 | **OK** | 3パターン検出、reach_me SE再生 |
| ボーナス/RT完全動作 | **OK** | BIG 45G/REG 14G、RT 40G、BIG_BLUE 1.5倍補正 |
| SE 23種 | **OK** | プロシージャルフォールバック全種動作 |
| BGM 5曲 | **OK** | プロシージャルフォールバック全曲動作、クロスフェード対応 |
| キャラクターリアクション | **OK** | 3キャラ×リアクション切替動作 |
| 背景画像 | **NG** | タイトル/ゲーム画面とも未反映（アセット存在するが表示問題） |
| 仕様策定完了 | **CONDITIONAL** | 80%策定済み、オートプレイ/ボーナス演出/RT演出が未策定 |

---

## MUST修正事項（alpha承認の条件）

### プログラム系

| # | 内容 | 担当 | 指摘元 |
|---|---|---|---|
| PM-1 | タイトル画面にconcept_art.pngを表示（EXEで未反映） | プログラム | アートD |
| PM-2 | ゲーム背景game_bg.pngの視認性修正（alpha 0.3 on不透明親→見えない） | プログラム | アートD |
| PM-3 | ボタンテキストコントラスト修正（明るい背景に白テキスト→暗色に） | プログラム | アートD |
| PM-4 | LEDインジケータ実装（仕様§8.4明記、有効=#00FF88/無効=#1A1A2E） | プログラム | アートD |
| PM-5 | wait_tick SE実装（ウェイト中1秒間隔チック音、仕様§1.2/§10.1） | プログラム | サウンドD |
| PM-6 | bonus_align+fanfare同時再生時のダッキング競合修正 | プログラム | サウンドD |
| PM-7 | _do_lever()遅れ時reel_start SE遅延のタイミング修正 | プログラム | テックD |

### 仕様策定系

| # | 内容 | 担当 | 指摘元 |
|---|---|---|---|
| SP-1 | オートプレイ/ウェイトカット仕様（新セクション§18） | プランナー | ゲームD |
| SP-2 | ボーナス中演出詳細仕様（§7.9: BIG/REG中の体験設計） | プランナー | ゲームD |
| SP-3 | RT演出パラメータ定義（§7.10: フィルタスウィープ、テンション段階） | プランナー | ゲームD |

---

## SHOULD修正事項（alpha期間中に対応推奨）

| # | 内容 | 担当 | 優先度 |
|---|---|---|---|
| S-1 | symbol_glow.gdshader をpayout_startedに接続（入賞時グロー） | VFX | HIGH |
| S-2 | button_bevel.gdshader をボタンに適用（3Dベベル効果） | VFX | HIGH |
| S-3 | BAR図柄の字形修正（実機BARロゴに近づける） | アート | HIGH |
| S-4 | フラッシュ演出の形状差別化（SPARK/BLOOM/NEON_SIGNに空間的動き） | VFX | HIGH |
| S-5 | タイトルロゴにグロー効果追加（ネオンサイン感） | アート | MEDIUM |
| S-6 | 設定画面にBGM/SE音量スライダー追加 | プログラム | MEDIUM |
| S-7 | play_se() volume_db仕様明確化（バス基準オフセットか絶対値か） | サウンド | MEDIUM |
| S-8 | テストスクリプト追加（bonus_cycle, reg_cycle, save最低3本） | QA | HIGH |
| S-9 | DataCounter画面UIレイアウト仕様策定 | プランナー | MEDIUM |
| S-10 | 設定画面UIレイアウト仕様策定 | プランナー | MEDIUM |
| S-11 | BIG_BLUE後RT連チャン体験設計の深掘り | プランナー | MEDIUM |
| S-12 | 長期モチベーション設計（収支グラフ、称号定義） | プランナー | LOW |

---

## ディレクター監査詳細

### 1. ゲームデザインリード — CONDITIONAL

**コンセプト適合**: PASS
- ハナビDNA（消灯/フラッシュ/遅れ/リーチ目/ICE技術介入）が忠実に仕様化
- VTuber3人体制のリアクション設計が感情増幅装置として機能
- カラーパレット12色が企画書と完全一致

**市場品質**: PASS（条件付き）
- 4号機A-Type再現アプリが市場不在（ブルーオーシャン）
- 65536分母の数値設計精度は商用水準
- 仕様書v0.3.0は1285行17セクションで極めて高い完成度

**ゲーム体験**: PASS（一部改善必須）
- ゲームループ（目押し/法則読み/設定判別）が4号機の本質を捉えている
- 短期〜長期の達成感設計が構造化されている
- 通常時体験密度（オートプレイ）の仕様欠落がリスク

**条件**: SP-1〜SP-3の仕様策定をalpha中に完了すること

### 2. テクニカルディレクター — CONDITIONAL

**安定性**: WARNING（リスクあり）
- 状態遷移、クレジットクランプ、レバー再入防止、セーブ検証は全て正常
- CRITICAL: `_do_lever()`のawait非同期とUI側同期コードの不整合（遅れ時reel_start SE）
- MEDIUM: play_se() volume_dbがバス音量と加算され仕様と1段ズレ

**パフォーマンス**: OK
- _physics_process O(1)、シェーダー軽量、Tween kill管理済み
- SEプール8ch/キャッシュ/SubViewport描画は全て低負荷

**アーキテクチャ**: OK（健全）
- Autoload 3本の責務分離が明確、UIとロジックの疎結合
- TODO/HACK/FIXME ゼロ、技術的負債の蓄積なし
- game.gd(532行)の肥大化傾向は要注意

**条件**: PM-7の修正を完了すること

### 3. アートディレクター — CONDITIONAL

**商品品質**: CONDITIONAL
- 図柄7種は高品質（ネオン発光の統一感、リール上の視認性良好）
- キャラクター画像は企画書のキャラ設定と一致する高品質
- 致命的問題: タイトル/ゲーム背景が未反映、ボタンコントラスト不足

**世界観統一**: CONDITIONAL
- ネオングリーンの統一使用、キャラテイストの一致は良好
- タイトルロゴの汎用フォント、PLAYボタンの色選択に改善余地

**視認性**: CONDITIONAL
- 7セグ表示、図柄識別、ボタン色分けは良好
- ボタンテキストのWCAGコントラスト比未達、LEDインジケータ未実装

**条件**: PM-1〜PM-4の修正を完了すること

### 4. サウンドディレクター — CONDITIONAL

**商品品質**: CONDITIONAL
- AudioBus構成、SEプール、ダッキング、クロスフェードは仕様準拠
- 全音源がプロシージャルフォールバック動作（実音源ファイル0件）
- wait_tick SEが完全に未実装

**世界観統一**: CONDITIONAL
- SE方向性（金属音/電子音）は正しいが実機感に欠ける
- BGMはコードパッド+キックのみ（仕様書記載のチルホップ/EDMとは大幅乖離）

**ワーカー指摘の検証結果**:
- C-1（BIG後BGM残留）: **誤検出**。BIG後は必ずRT突入→rt BGMに遷移
- C-2（delay_pendingレース）: **動作上問題なし**。GDScriptのawait前同期emitにより正常動作
- C-3（wait_tick未使用）: **確認: 完全に未実装**

**条件**: PM-5, PM-6の修正を完了すること

### 5. QAディレクター — CONDITIONAL SHIP

**テスト網羅性**: WARNING
- E2Eテスト 1/14本のみ存在（test_gameplay.ps1のみ）
- ユニットテスト実行ログ未確認
- ボーナスサイクル、セーブ/ロード、レース条件のテストが皆無

**品質基準**: WARNING（条件付き）
- クラッシュ/ハング: 0件
- 全9枚スクリーンショットで動作確認済み
- 背景未反映、button_bevel未適用、symbol_glow未接続を確認

**出荷判定**: CONDITIONAL SHIP
- コアサイクルは安定動作、4号機A-Type仕様に忠実
- 未テスト領域のリスクが高いが、alpha段階としては許容範囲
- 条件: テストスクリプト最低3本追加、wait_tick実装、仕様完成

---

## 実機確認状況

### debug_state.json

```json
{
  "game_state": "BONUS",
  "bonus_type": "BIG",
  "bonus_type_internal": 6,
  "bonus_games_max": 45,
  "credit": 9993,
  "total_games": 51,
  "big_count": 5,
  "reg_count": 2,
  "total_in": 444,
  "total_out": 467,
  "rt_active": false,
  "rt_bonus_rate": 1
}
```

- 51ゲーム中BIG5+REG2（デバッグモード使用）
- credit 9993、DIFF +23 — 整合性OK
- ボーナス開始直後（0/45G）の状態キャプチャ

### スクリーンショット（9枚）

| ファイル | 内容 | 状態 |
|---|---|---|
| 01_title_screen.png | タイトル画面 | OK（背景未反映） |
| 02_game_screen.png | ゲーム画面フル | OK（背景未反映） |
| 03_bonus_trigger.png | BIG発生 | OK |
| 04_bonus_play.png | BIG消化中 | OK |
| 05_final.png | 最終状態 | OK |
| game_1.png | 通常ゲーム | OK |
| game_2.png | 通常ゲーム | OK |
| game_3.png | 消灯演出中 | OK（消灯動作確認） |
| bonus_1.png | ボーナス消化中 | OK |

---

## 次フェーズ統合ロードマップ

### alpha MUST修正（承認条件）
1. PM-1〜PM-7: プログラム修正7件
2. SP-1〜SP-3: 仕様策定3件

### alpha→beta移行に必要な追加作業
1. S-1〜S-4: symbol_glow接続、button_bevel適用、BAR字形修正、フラッシュ形状差別化
2. S-8: テストスクリプト3本以上追加
3. 実音源ファイルの段階的導入（プロシージャルからの移行開始）
4. game.gdの分割（VFXManager等への責務分離）

### beta完了条件
- 全機能実装、バランス調整FIX、課題点抽出
- 全SE/BGMが実音源に置換
- オートプレイ/設定画面/DataCounter実装
- キャラクターリアクション全パターン動作

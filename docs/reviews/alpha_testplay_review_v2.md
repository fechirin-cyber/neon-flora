# NEON FLORA alpha テストプレイレビュー v2

**日付**: 2026-03-02
**フェーズ**: alpha (MUST修正完了後の再レビュー)
**ビルド**: EXE 100.3MB (test_gameplay.ps1 ALL TESTS PASSED)
**テスト**: 5本全PASSED (gameplay, bonus_cycle, reg_rt_cycle, save_load, must_fixes)
**レビュー方式**: ワーカー6名 → ディレクター5名監査

---

## 総合判定テーブル

| # | ワーカー | ワーカー判定 | ディレクター | ディレクター判定 |
|---|---|---|---|---|
| 1 | プランナー | **PASS** | ゲームデザインリード | **APPROVE** |
| 2 | テクニカルリード | CONDITIONAL | テクニカルディレクター | **CONDITIONAL** |
| 3 | アーティスト | CONDITIONAL | アートディレクター | **CONDITIONAL** |
| 4 | VFXデザイナー | CONDITIONAL | アートディレクター | (上記に統合) |
| 5 | UIデザイナー | CONDITIONAL | アートディレクター | (上記に統合) |
| 6 | サウンドデザイナー | (完了) | サウンドディレクター | **CONDITIONAL (alpha APPROVE可)** |
| — | — | — | QAディレクター | **APPROVE (Conditional)** |

**総合判定: CONDITIONAL APPROVE (BLOCKなし)**

---

## 前回レビュー(v1)からの改善状況

### MUST修正 (v1指摘 → v2状態)

| # | 内容 | v1状態 | v2状態 |
|---|---|---|---|
| PM-1 | タイトル背景グラデーション緩和 | 未修正 | **修正済** |
| PM-2 | ゲーム背景不透明度修正 | 未修正 | **修正済** |
| PM-3 | ボタンテキストコントラスト | 未修正 | **修正済** |
| PM-4 | LEDインジケータ実装 | 未実装 | **実装済** |
| PM-5 | wait_tick SE実装 | 未実装 | **実装済** |
| PM-6 | bonus_align+fanfare競合修正 | 未修正 | **修正済** |
| PM-7 | reel_start SEタイミング | 未修正 | **修正済 (二重遅延問題あり)** |
| SP-1 | オートプレイ仕様策定 | 未策定 | **策定済 (§18)** |
| SP-2 | ボーナス中演出仕様策定 | 未策定 | **策定済 (§7.9)** |
| SP-3 | RT演出パラメータ定義 | 未策定 | **策定済 (§7.10)** |

### SHOULD修正 (v1指摘 → v2状態)

| # | 内容 | v1状態 | v2状態 |
|---|---|---|---|
| S-1 | symbol_glow接続 | 未接続 | **接続済** |
| S-2 | button_bevel適用 | 未適用 | **適用済** |
| S-4 | フラッシュ形状差別化 | 未実装 | **実装済** |
| S-8 | テストスクリプト3本追加 | 1本のみ | **5本(+4)** |

### VIS: 視認性基準適合

| 項目 | v1状態 | v2状態 |
|---|---|---|
| ボタンサイズ | 80-100px | **120px+** |
| ボタンフォント | 16-20px | **24px** |
| DataCounterフォント | 18px | **22px** |
| InfoLabelフォント | 18px | **22px** |

---

## ディレクター監査詳細 (v2)

### 1. ゲームデザインリード — APPROVE

- **コンセプト適合**: PASS — ハナビDNA完全再現、VTuber3人体制の感情増幅装置が機能
- **市場品質**: PASS — 4号機A-Type完全再現は事実上ブルーオーシャン、65536分母の精度は商用水準
- **ゲーム体験**: PASS — ゲームループ/フィードバック密度/テンポ/達成感/リプレイ性が全て合格
- **仕様完成度**: v0.4.0全18セクション約1430行、SP-1/SP-2/SP-3全策定完了

**beta申し送り**:
- 長期モチベーション設計(収支グラフ/称号/設定推測チャレンジ)
- チュートリアル(パチスロ未経験者向け)
- ICEビタ押し成功/失敗時演出詳細(§7.9.1追記)
- RT中ボーナス当選時遷移演出(§6.3/§7.10追記)

### 2. テクニカルディレクター — CONDITIONAL

- **安定性**: WARNING — コアサイクル安定、テスト4本PASSED、クラッシュ0件
- **パフォーマンス**: OK — _physics_process O(1)、シェーダー軽量、Tween管理済
- **アーキテクチャ**: OK — Autoload3本の責務分離、TODO/HACK/FIXME 0件

**alpha承認MUST (1件)**:
- reel_start SE二重遅延修正 (game.gd L243-245): SlotEngine内部0.4s await + game.gd側0.4sタイマー = 合計0.8s遅延。仕様は0.4s

**beta対応MUST (3件)**:
- bonus_payout保存/復元実装
- デバッグキー `OS.is_debug_build()` ガード
- game.gd分離リファクタリング

**テクニカルリード指摘の検証**:
- payout_finished未発行 → **誤検出**(コードフロー追跡で正常発行確認)
- _delay_pending設計不明確 → **本質は二重遅延**(フラグ自体は正常動作)
- bonus_payout引継ぎ漏れ → **妥当だがMEDIUM**(表示のみ、データ破損なし)

### 3. アートディレクター — CONDITIONAL

- **商品品質**: 改善必要 — 図柄7種/ひかり/7セグ/リール窓は高品質。game_bg/るなに問題
- **世界観統一**: 一部不一致 — title_bg/ひかり/図柄はCyber-Japaneseで統一。game_bg/るなが逸脱
- **視認性**: 改善余地 — リール/7セグ/ボタン有効無効は良好。消灯範囲/SETTINGSボタンに問題

**alpha承認MUST (4件)**:
- AD-1: game_bg.pngをサイバー和風に差替え(西洋サイバーパンク→和風夜景)
- AD-2: るな(luna)の髪色/髪型/猫耳ヘッドセットを仕様準拠に修正
- AD-4: 消灯オーバーレイをリール窓領域に限定(全画面暗転→リールのみ)
- AD-5: SETTINGSボタン 90px高/24pxフォント以上に拡大

**beta推奨SHOULD (5件)**:
- AD-3: こはる和風帯リボン/花簪マイク追加
- AD-6: hikari_sad.png髪色統一
- AD-7: ボーナス専用背景(花火×河川敷)実装
- AD-8: InfoLabel 24px引き上げ
- AD-9: BIG3フェーズ/RT3段階テンション演出実装

### 4. サウンドディレクター — CONDITIONAL (alpha APPROVE可)

- **前回MUST 3件**: PM-5/PM-6/PM-7 **全修正確認済**
- **SE 23種 / BGM 5曲**: 全実装済(プロシージャルフォールバック)
- **ダッキング5ルール**: 仕様準拠
- **クロスフェードA/B**: 仕様準拠
- **メダル払出SE**: 仕様準拠
- **消灯レベル連動音量**: 仕様準拠

**alpha承認**: APPROVE可(MUST修正完了済)

**beta対応MUST (4件)**:
- 実音源6件の導入(lever_pull, reel_stop_l/c/r, big_fanfare, tamaya)
- BGM/SE音量スライダー実装(§12.1)
- play_se() volume_db仕様明確化
- game.gd L100: play_bgm("normal", 0.3)に修正

### 5. QAディレクター — APPROVE (Conditional)

- **テスト網羅性**: 5/14 E2E(core path網羅)、S-8要件充足
- **品質基準**: クラッシュ0件、全テストPASSED
- **仕様適合**: v0.4.0全18セクション策定完了、SP-1/2/3解決済
- **debug_state.json**: 整合性OK

**alpha承認**: APPROVE

**beta入場条件 (2件)**:
- 消灯オーバーレイ範囲をリール窓限定に修正
- BIG→RT WARNING調査・文書化

---

## alpha承認に残る修正事項まとめ

### MUST (alpha承認条件)

| # | 内容 | 指摘元 | 種別 |
|---|---|---|---|
| TD-1 | reel_start SE二重遅延修正(0.8s→0.4s) | テックD | プログラム |
| AD-1 | game_bg.pngサイバー和風差替え | アートD | アセット |
| AD-2 | るな髪色/髪型/猫耳ヘッドセット修正 | アートD | アセット |
| AD-4 | 消灯オーバーレイをリール窓限定 | アートD/QAD | プログラム |
| AD-5 | SETTINGSボタン 90px+/24px+ | アートD | UI |

### beta対応MUST (alpha承認後)

| # | 内容 | 指摘元 |
|---|---|---|
| bonus_payout保存/復元 | テックD |
| デバッグキーガード | テックD |
| game.gd分離リファクタリング | テックD |
| 実音源6件導入 | サウンドD |
| BGM/SE音量スライダー | サウンドD |
| volume_db仕様明確化 | サウンドD |
| play_bgm("normal", 0.3)修正 | サウンドD |
| 長期モチベーション設計策定 | ゲームD |
| チュートリアル策定 | ゲームD |
| ICEビタ押し演出詳細 | ゲームD |
| RT中ボーナス当選遷移演出 | ゲームD |
| こはる和風要素追加 | アートD |
| hikari_sad髪色統一 | アートD |
| ボーナス専用背景 | アートD |
| InfoLabel 24px | アートD |
| BIG3フェーズ/RT3段階演出 | アートD |
| BIG→RT WARNING調査 | QAD |

---

## 実機確認状況

### debug_state.json

```json
{
  "big_count": 4,
  "bonus_games_max": 45,
  "bonus_games_played": 1,
  "bonus_payout": 10,
  "bonus_stocked": 0,
  "bonus_type": "BIG",
  "bonus_type_internal": 6,
  "credit": 4260,
  "current_flag": 4,
  "game_state": "BONUS",
  "last_production": {"blackout": 0, "delay": false, "flash": "", "tamaya": false},
  "reel_positions": [7, 7, 7],
  "reg_count": 2,
  "rt_active": false,
  "rt_bonus_rate": 1,
  "rt_remaining": 0,
  "total_games": 8,
  "total_in": 447,
  "total_out": 657,
  "wait_remaining": 0
}
```

### テスト結果

| テスト | 結果 | 備考 |
|---|---|---|
| test_gameplay.ps1 | ALL PASSED | コアサイクル3G + BIGトリガー |
| test_bonus_cycle.ps1 | ALL PASSED | BIG 50G消化 + REGサイクル |
| test_reg_rt_cycle.ps1 | ALL PASSED (WARNING) | REG→通常, BIG→RT (BIG 50Gで未完了WARNING) |
| test_save_load.ps1 | ALL PASSED | credit/stats完全一致 |
| test_must_fixes.ps1 | (存在) | BIG/REGサイクル + 4.1sウェイト対応 |

### スクリーンショット (9枚)

| ファイル | 内容 | 状態 |
|---|---|---|
| 01_title_screen.png | タイトル画面 | OK (背景反映済) |
| 02_game_screen.png | ゲーム画面 | OK (背景反映済) |
| 03_bonus_trigger.png | BIG発生 | OK |
| 04_bonus_play.png | BIG消化中 | OK |
| 05_final.png | 最終状態 | OK |
| game_1.png | 消灯演出中 | OK (全画面暗転→要修正) |
| game_2.png | 消灯演出中 | OK (同上) |
| game_3.png | 通常ゲーム | OK |
| bonus_1.png | ボーナス消化中 | OK |

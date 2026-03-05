# NEON FLORA 詳細仕様書

**ステータス**: α仕様策定完了
**最終更新**: 2026-03-02
**バージョン**: 0.5.0
**企画書参照**: `docs/proposal.md` v1.0

---

## 目次

1. [ゲームフロー](#1-ゲームフロー)
2. [状態遷移](#2-状態遷移)
3. [抽選仕様](#3-抽選仕様)
4. [リール仕様](#4-リール仕様)
5. [配当仕様](#5-配当仕様)
6. [ボーナス仕様](#6-ボーナス仕様)
7. [演出仕様](#7-演出仕様)
8. [画面仕様](#8-画面仕様)
9. [リール描画仕様](#9-リール描画仕様)
10. [音響仕様](#10-音響仕様)
11. [データ永続化仕様](#11-データ永続化仕様)
12. [設定画面仕様](#12-設定画面仕様)
13. [入力仕様](#13-入力仕様)
14. [アーキテクチャ仕様](#14-アーキテクチャ仕様)
15. [テスト仕様](#15-テスト仕様)
16. [境界値・エッジケース仕様](#16-境界値エッジケース仕様)
17. [アクセシビリティ仕様](#17-アクセシビリティ仕様)
18. [オートプレイ・ウェイトカット仕様](#18-オートプレイウェイトカット仕様)

---

## 1. ゲームフロー

### 1.1 メインゲームループ（1ゲーム）

```
1. [BET] ユーザーがBETボタン押下
   → 3枚消費（credit -= 3）
   → BET音SE再生
   → ボタン状態更新（LEVER有効化）

2. [LEVER] ユーザーがレバー押下
   → ウェイトチェック（前回レバーから4.1秒経過しているか）
     → 未経過: WAITING状態、ウェイト音再生、残時間経過を待つ
       ※ レバーボタンをグレーアウトし、視覚的にWAITING中であることを明示
     → 経過済: 即座に次へ
   → 内部抽選実行（_lottery()）
   → 演出抽選実行（ProductionTable.select_production()）
   → フラグ確定シグナル発行
   → 遅れ演出判定（7.4節参照、ボーナスフラグ時のみ）
     → 遅れ発生: delay_fired シグナル発行 → 0.4秒待機 → リール回転開始
     → 遅れなし: 即座にリール回転開始
   → たーまやー判定（7.5節参照、ボーナスストック中のみ）
     → 発生: tamaya_fired シグナル発行（遅れ判定の後、リール回転開始前）
   → リール回転開始
   → レバー音SE再生
   → キャラリアクション（EXPECT or IDLE）

3. [STOP L/C/R] ユーザーがストップボタン押下（3回）
   → 押した時点のリール位置を取得
   → 滑り制御で停止位置を計算（0-4コマ）
   → リール停止アニメーション開始
   → ストップ音SE再生（L/C/Rで音程差あり）
   → 全リール停止後 → 判定へ

4. [判定] 全リール停止後
   → 5ライン（横上段・横中段・横下段・斜め右下がり・斜め右上がり）の図柄を確認
   → 配当判定（各ライン独立判定、複数ライン入賞時は合算）
     → 入賞あり: PAYING状態 → 配当分credit加算 → 入賞SE + グローエフェクト
     → 入賞なし: ハズレ処理
   → ボーナス図柄揃いチェック
     → 揃った: ボーナス開始（BONUS状態へ）
     → 揃っていない: 通常に戻る
   → 消灯 → フラッシュ演出再生（該当時）
   → リーチ目チェック → 検出時は専用SE + エフェクト
   → リプレイ時: 自動BET → 2へ戻る
   → 通常: IDLE状態 → 1へ戻る

5. [ボーナス中] BIG or REG
   → 高確率テーブルで抽選（ゲーム数管理）
   → BIG: 45G消化で終了（リプレイはゲーム数にカウントしない）
   → REG: 14G消化で終了（同上）
   → ビタ押し要求: ICE当選時、最後に停止するリールの引き込み猶予が1コマに制限
     → 第1リール停止時にICE図柄が窓内に表示されビタ押し告知
     → 成功: ICE入賞（15枚）、失敗: ハズレ（0枚）
   → 最低保証: ビタ押し非成功でもBELL高確率により十分な配当を確保
   → BIG終了後 → RT状態（40G）
   → REG終了後 → 通常状態

6. [RT中] リプレイタイム
   → RTテーブルで抽選（リプレイ確率UP: 約1/1.8）
   → 40ゲーム消化で終了 → 通常状態
   → RT中にボーナス当選時: RT残ゲームは破棄（ボーナス優先）
   → 連チャン期待演出: BGMテンション変化、キャラの期待リアクション強化
   → BIG_BLUE後RTではボーナス当選確率に1.5倍補正（連チャン率UP）
```

### 1.2 ウェイトシステム（実機準拠）

| 項目 | 値 |
|---|---|
| 最小ゲーム間隔 | 4.1秒（レバーON〜次レバーON） |
| ウェイト音 | 1秒ごとのチック音（残り秒数を聴覚フィードバック） |
| ウェイト中UI | レバーボタン暗転、残ウェイト表示なし（実機準拠） |
| ウェイト中操作 | 全ボタン無効。WAITING状態中はキャラIDLE維持 |

### 1.3 「遅れ」演出仕様

| 項目 | 内容 |
|---|---|
| 発生条件 | **ボーナスフラグ（BIG_RED/BIG_BLUE/REG）成立時のみ**（7.4節参照） |
| 演出内容 | レバーON後、リール回転開始が通常より0.4秒遅れる |
| 音声演出 | リール回転SE（reel_start）の発行が0.4秒遅延。BGMは鳴り続ける |
| キャラ演出 | **原則なし**（遅れの違和感を損なわないため）。BIG確定にプレイヤーが3ゲーム以上気づかなかった場合、または低確率（1/10）でのみ、ひかりが一瞬固まる → 「…え？」表情を表示 |
| 意味 | **ボーナス確定告知**（ハナビ準拠：遅れ = ボーナス確定） |
| 注意 | 小役（CHERRY等）では発生しない。ボーナスフラグ成立ゲーム限定 |

### 1.4 シグナル発行順序（レバーON時）

```
1. flag_determined(flag, production)    # 常に最初
2. delay_fired()                         # 遅れ発生時のみ（0.4秒待機開始）
3. tamaya_fired()                        # たーまやー発生時のみ
4. [0.4秒待機]                           # 遅れ時のみ。非遅れ時はスキップ
5. reel_start → SPINNING遷移            # リール回転開始
```

---

## 2. 状態遷移

### 2.1 GameState enum

```gdscript
enum GameState {
    IDLE,       # BET待ち
    WAITING,    # 4.1秒ウェイト中
    SPINNING,   # リール回転中（全リール回転）
    STOPPING,   # 1本以上停止、残りが回転中
    PAYING,     # 配当演出中
    BONUS,      # ボーナス消化中（BIG or REG）
    RT,         # リプレイタイム（40G）
}
```

### 2.2 遷移図

```
IDLE --[BET+LEVER]--> WAITING or SPINNING
WAITING --[4.1秒経過]--> SPINNING
SPINNING --[STOP1]--> STOPPING
STOPPING --[STOP2, STOP3]--> STOPPING
STOPPING --[全停止+入賞]--> PAYING
STOPPING --[全停止+ハズレ]--> IDLE or RT
PAYING --[配当完了]--> IDLE or BONUS or RT
BONUS --[規定ゲーム数消化]--> RT(BIGのみ) or IDLE(REG)
RT --[40G消化]--> IDLE
RT --[ボーナス当選]--> (ストック後、揃えたら)BONUS ※RT残ゲーム破棄
```

### 2.3 ボタン有効/無効マトリクス

停止順序は自由（順押し・中押し・逆押しいずれも可）。

| 状態 | BET | LEVER | STOP L | STOP C | STOP R |
|---|---|---|---|---|---|
| IDLE(credit>=3) | ✅ | ❌ | ❌ | ❌ | ❌ |
| IDLE(credit<3) | ❌ | ❌ | ❌ | ❌ | ❌ |
| IDLE(BET済) | ❌ | ✅ | ❌ | ❌ | ❌ |
| WAITING | ❌ | ❌ | ❌ | ❌ | ❌ |
| SPINNING | ❌ | ❌ | ✅ | ✅ | ✅ |
| STOPPING(L停止) | ❌ | ❌ | ❌ | ✅ | ✅ |
| STOPPING(C停止) | ❌ | ❌ | ✅ | ❌ | ✅ |
| STOPPING(R停止) | ❌ | ❌ | ✅ | ✅ | ❌ |
| STOPPING(LC停止) | ❌ | ❌ | ❌ | ❌ | ✅ |
| STOPPING(LR停止) | ❌ | ❌ | ❌ | ✅ | ❌ |
| STOPPING(CL停止) | ❌ | ❌ | ❌ | ❌ | ✅ |
| STOPPING(CR停止) | ❌ | ❌ | ✅ | ❌ | ❌ |
| STOPPING(RL停止) | ❌ | ❌ | ❌ | ❌ | ✅ |
| STOPPING(RC停止) | ❌ | ❌ | ✅ | ❌ | ❌ |
| PAYING | ❌ | ❌ | ❌ | ❌ | ❌ |
| BONUS | BET/LEVERで1G消化 | | | | |
| RT | 通常と同じ | | | | |

**注**: リプレイ時はBETが自動（ボタン不要）→ 即LEVER有効

### 2.4 アプリ中断・復帰

**PAYING配当方式**: 配当判定時にcreditへ**全額一括加算**。PAYING状態のアニメーション（メダル払出演出）は表示のみ。これにより中断時の二重加算リスクを排除。

| 状況 | 処理 |
|---|---|
| IDLE/RT中断 | セーブデータから完全復帰（**RT中断時はrt_remainingを保持して復帰**） |
| SPINNING/STOPPING中断 | 現ゲーム無効化。BET返却(credit+=3)。IDLEまたはRT状態で復帰 |
| PAYING中断 | credit加算済みのため追加処理なし。IDLE(or RT/BONUS)として保存 |
| BONUS中断 | bonus_stocked/bonus_games_playedを保存し、BONUS状態で復帰 |
| WAITING中断 | ウェイトリセット。BET返却(credit+=3)。IDLE復帰 |

---

## 3. 抽選仕様

### 3.1 乱数生成

| 項目 | 値 |
|---|---|
| 分母 | 65536 (16bit) |
| 生成方法 | `randi() % 65536` |
| 抽選タイミング | レバーON時（SPINNING遷移直前） |

### 3.2 フラグ enum

```gdscript
enum Flag {
    HAZURE = 0,     # ハズレ
    REPLAY = 1,     # リプレイ
    CHERRY_2 = 2,   # 角チェリー（4枚 = 2枚×2ライン）
    CHERRY_4 = 3,   # 中段チェリー（2枚 = 2枚×1ライン）
    BELL = 4,       # ベル（10枚）
    ICE = 5,        # 氷（15枚）
    BIG_RED = 6,    # BIG（赤7）— 内部区分のみ
    BIG_BLUE = 7,   # BIG（青7）— 内部区分のみ
    REG = 8,        # REG（BAR）
}
```

**BIG_RED / BIG_BLUE の区分仕様**:
- 内部的にフラグを区分するのみ。**どちらのフラグが成立していても、プレイヤーの目押しにより赤7(S7R)・青7(S7B)いずれでも揃えられる**
- BIG_BLUE後のRT中は、ボーナス当選確率に**1.5倍補正**を適用（連チャン率UP）
- 期待値示唆: 青7で揃えると「連チャンに期待できる」ことをプレイヤーに示唆

### 3.3 通常時抽選テーブル（設定別 / 65536分母）

| フラグ | 設定1 | 設定2 | 設定3 | 設定4 | 設定5 | 設定6 |
|---|---|---|---|---|---|---|
| REPLAY | 8979 | 8979 | 8979 | 8979 | 8979 | 8979 |
| CHERRY_2 | 7999 | 7999 | 7999 | 7999 | 7999 | 7999 |
| CHERRY_4 | 272 | 272 | 272 | 272 | 272 | 272 |
| BELL | 916 | 916 | 916 | 916 | 916 | 916 |
| ICE | 920 | 920 | 920 | 920 | 920 | 920 |
| BIG_RED | 110 | 116 | 122 | 132 | 136 | 142 |
| BIG_BLUE | 110 | 116 | 122 | 132 | 136 | 142 |
| REG | 156 | 156 | 156 | 156 | 168 | 180 |
| HAZURE | 残り | 残り | 残り | 残り | 残り | 残り |

**検証**: 設定1のボーナス合算 = (110+110+156)/65536 = 376/65536 ≈ 1/174.3
**検証**: 設定6のボーナス合算 = (142+142+180)/65536 = 464/65536 ≈ 1/141.2

### 3.4 ボーナス中抽選テーブル（高確率）

| フラグ | 重み |
|---|---|
| REPLAY | 19988 |
| CHERRY_2 | 128 |
| BELL | 27000 |
| ICE | 5464 |
| HAZURE | 残り |

**注**: ボーナス中テーブルにはボーナスフラグ（BIG/REG）が存在しない → ボーナス中にボーナス重複当選は不可

**ビタ押し**: ICE当選確率 = 5464/65536 ≈ 8.3%。ボーナス中のゲームのうち約8.3%でICEが当選し、これがビタ押し要求ゲームとなる（0〜10%の範囲内）。ICE当選時、最後に停止するリールの引き込み猶予が4コマ→1コマに制限されるため、正確な目押し（ビタ押し）が必要。

### 3.5 RT中抽選テーブル

通常時テーブルと同一だが、REPLAYの重みのみ変更:

| フラグ | 全設定 |
|---|---|
| REPLAY | 36409（約1/1.8） |
| その他 | 通常時と同じ |

**注**: RT中にボーナスフラグが当選する可能性あり（通常時と同じ確率）。当選時はストックし、RT残ゲームは**即座に破棄**してボーナス消化優先

### 3.6 ボーナスフラグストック

- ボーナスフラグ（BIG_RED/BIG_BLUE/REG）が成立した場合、即座に揃えず**ストック**
- ストック中は毎ゲーム小役抽選を行い、**ハズレの場合のみ**ボーナス図柄の引き込みを試みる
- 小役成立時は小役を優先制御（重複当選時の小役を払い出す）
- **ストック中に再度ボーナスフラグが成立することはない**
  - 通常時: 抽選テーブルでボーナスに当選してもストック済みなら**ハズレに差し替え**
  - RT中: 同上（RT中ボーナス当選→RT破棄の流れは「ストック未所持時」のみ発生）

---

## 4. リール仕様

### 4.1 リール構成

| 項目 | 値 |
|---|---|
| リール本数 | 3本（LEFT / CENTER / RIGHT） |
| 1リールの図柄数 | 21個（循環） |
| 表示窓 | 3段（上段・中段・下段） |
| 有効ライン | 5ライン（横上段・横中段・横下段・斜め右下がり・斜め右上がり） |
| 図柄サイズ | 200 x 160 px |
| 図柄間隙間 | 4px（黒線） |

### 4.2 図柄ID

```gdscript
const S7R = 0   # 赤7
const S7B = 1   # 青7
const BAR = 2   # BAR
const CHR = 3   # チェリー
const BEL = 4   # ベル
const ICE = 5   # 氷
const RPL = 6   # リプレイ
```

**注**: 空白（BLK）は使用しない。全21コマを有効図柄で構成する。

### 4.3 リール配列（21図柄 × 3リール）

**LEFT リール**（3連BEL配置 — ハナビの3連どんちゃんに相当）:
```
[CHR, RPL, BEL, BEL, BEL, S7R, ICE, RPL, BEL, RPL,
 S7B, BEL, CHR, RPL, BEL, ICE, BEL, BAR, RPL, BEL, BEL]
```

**CENTER リール**:
```
[S7R, RPL, BEL, ICE, RPL, BEL, BEL, RPL, BEL, S7B,
 ICE, RPL, BEL, BEL, RPL, ICE, BEL, BAR, RPL, BEL, BEL]
```

**RIGHT リール**:
```
[BEL, RPL, S7R, BEL, ICE, RPL, BEL, RPL, BEL, BEL,
 BAR, RPL, ICE, BEL, RPL, S7B, BEL, ICE, RPL, BEL, BEL]
```

### 4.4 図柄分布

| 図柄 | LEFT | CENTER | RIGHT |
|---|---|---|---|
| S7R(赤7) | 1 | 1 | 1 |
| S7B(青7) | 1 | 1 | 1 |
| BAR | 1 | 1 | 1 |
| CHR(チェリー) | 2 | 0 | 0 |
| BEL(ベル) | 9 | 9 | 9 |
| ICE(氷) | 2 | 3 | 3 |
| RPL(リプレイ) | 5 | 6 | 6 |
| **合計** | **21** | **21** | **21** |

### 4.5 滑り制御（4コマ制御）

- 停止ボタン押下時のリール位置から、**最大4コマ先**まで滑ることができる
- 0〜4コマの範囲で**フラグに基づく最適な停止位置**を選択

```
停止位置探索:
  for slip in range(5):  # 0, 1, 2, 3, 4
      candidate = posmod(pressed_position + slip, 21)
      window = get_window(reel_idx, candidate)
      if is_valid_stop(reel_idx, window, candidate):
          return candidate
  return pressed_position  # フェイルセーフ
```

### 4.6 停止制御ルール（is_valid_stop）

5ライン判定に基づく停止制御。上段・中段・下段すべての図柄位置を考慮する。

| 成立フラグ | 制御内容 |
|---|---|
| HAZURE | 5ライン上にいかなる入賞図柄も揃えてはならない。**LEFT: CHRが上段/中段/下段に来る位置も蹴る**（チェリーは左リール単独判定のため） |
| REPLAY | いずれかのラインでRPLを3つ揃える（中段ライン優先で引き込み） |
| CHERRY_2 | LEFTのみ: CHRを上段or下段に（角チェリー）。C/Rは制約なし |
| CHERRY_4 | LEFTのみ: CHRを中段に。C/Rは制約なし |
| BELL | いずれかのラインでBELを3つ揃える（中段ライン優先で引き込み） |
| ICE | いずれかのラインでICEを3つ揃える（中段ライン優先で引き込み） |
| ICE（技術介入） | **最後に停止するリール**のみ引き込み猶予が**1コマ**に制限（他リールは通常の4コマ）。ボーナス中のビタ押し要素 |
| BIG_RED/BLUE/REG | ボーナスフラグ自体は小役と重複可。小役を優先制御 |

### 4.7 ボーナス図柄揃い条件

ストックされたボーナスフラグがある場合、かつ当該ゲームの小役がHAZUREの場合:
- **BIG_RED/BIG_BLUE**: いずれかの7図柄（S7R or S7B）をいずれかのラインで3つ揃える（4コマ以内に引き込み）。内部フラグがBIG_REDでもBIG_BLUEでも、プレイヤーの目押しにより赤7・青7どちらでも揃えられる
- **REG**: BAR(BAR)をいずれかのラインで3つ揃える（4コマ以内に引き込み）

---

## 5. 配当仕様

### 5.1 有効ライン定義

| ライン | L位置 | C位置 | R位置 |
|---|---|---|---|
| L1: 横上段 | 上段 | 上段 | 上段 |
| L2: 横中段 | 中段 | 中段 | 中段 |
| L3: 横下段 | 下段 | 下段 | 下段 |
| L4: 斜め右下がり | 上段 | 中段 | 下段 |
| L5: 斜め右上がり | 下段 | 中段 | 上段 |

### 5.2 小役配当（1ライン配当）

| 入賞役 | 条件 | 1ライン配当（枚） | 備考 |
|---|---|---|---|
| リプレイ | いずれかのラインでRPL×3 | 0（BET返却=次ゲーム自動BET） | |
| 角チェリー | LEFT上段or下段にCHR | 2枚×入賞ライン数 | 角: L4orL5の2ライン→4枚 |
| 中段チェリー | LEFT中段にCHR | 2枚×入賞ライン数 | 中段: L2の1ライン→2枚 |
| ベル | いずれかのラインでBEL×3 | 10 | |
| 氷 | いずれかのラインでICE×3 | 15 | |

**チェリー配当解説**:
- 角チェリー（CHRが上段or下段）: 斜めラインを含む2本のラインに掛かる → 2枚×2=**4枚**
- 中段チェリー（CHRが中段）: 横中段ライン1本のみ → 2枚×1=**2枚**
- チェリーはLEFTリール単独判定（C/R不問）

### 5.3 ボーナス消化仕様（ゲーム数管理）

| ボーナス | 規定ゲーム数 | 終了条件 | 期待総配当（参考） |
|---|---|---|---|
| BIG | 45G（リプレイ除く） | 非リプレイ45ゲーム消化 | 約345枚 |
| REG | 14G（リプレイ除く） | 非リプレイ14ゲーム消化 | 約108枚 |

**注**: リプレイはゲーム数にカウントしない（実機準拠）。期待総配当は参考値であり、ビタ押し成否により変動する。

### 5.4 配当判定優先順位

1. チェリー（LEFTリールの位置で判定、C/Rは不問）
2. リプレイ（5ラインいずれかでRPL×3）
3. ベル（5ラインいずれかでBEL×3）
4. 氷（5ラインいずれかでICE×3）
5. ボーナス図柄揃い（5ラインいずれかで同一ボーナス図柄×3）

---

## 6. ボーナス仕様

### 6.1 BIG BONUS

| 項目 | 値 |
|---|---|
| トリガー | いずれかのラインで赤7×3 or 青7×3（BIG_RED/BIG_BLUEどちらのフラグでも赤7・青7いずれでも揃えられる） |
| 規定ゲーム数 | 45G（リプレイ除く） |
| 抽選テーブル | ボーナス中テーブル（3.4節） |
| ビタ押し | ICE当選時（約8.3%）、最終停止リールの引き込み猶予1コマ |
| BGM | bonus_big.ogg |
| キャラ | るな（BIG担当）が登場 |
| 終了後 | RT（40G）に突入 |

### 6.2 REG BONUS

| 項目 | 値 |
|---|---|
| トリガー | いずれかのラインでBAR×3 |
| 規定ゲーム数 | 14G（リプレイ除く） |
| 抽選テーブル | ボーナス中テーブル（3.4節） |
| ビタ押し | BIG同様（ICE当選時に引き込み1コマ制限） |
| BGM | bonus_reg.ogg |
| キャラ | こはる（REG担当）が登場 |
| 終了後 | 通常状態に復帰（RTなし） |

### 6.3 RT（リプレイタイム）

| 項目 | 値 |
|---|---|
| トリガー | BIG終了後に自動突入 |
| 継続ゲーム数 | 40G |
| 抽選テーブル | RTテーブル（3.5節） |
| リプレイ確率 | 約1/1.8 |
| BGM | rt.ogg |
| カウント | レバーONでデクリメント（ボーナスゲームは数えない） |
| 終了後 | 通常状態に復帰 |
| RT中ボーナス当選 | RT残ゲームを**即座に破棄**。ボーナスストック→揃い→BONUS状態へ |
| BIG_BLUE後RT | ボーナス当選確率に**1.5倍補正**適用（rt_bonus_rate = 1.5）。連チャン演出強化 |
| 連チャン演出 | BGMフィルタースウィープ変化、残ゲーム数減少に伴いテンション増加、キャラリアクション強化 |

### 6.4 ボーナス終了時の処理

```
BIG終了:
  1. bonus_end SE再生
  2. bonus_ended("BIG", total_payout) シグナル発行
  3. bonus_stocked = false
  4. bonus_type_internal（BIG_RED or BIG_BLUE）を記録
  5. BGMクロスフェード → rt.ogg（0.5秒）
  6. rt_remaining = 40
  7. rt_bonus_rate = 1.5 if bonus_type_internal == BIG_BLUE else 1.0
  8. game_state → RT
  9. rt_started(40) シグナル発行

REG終了:
  1. bonus_end SE再生
  2. bonus_ended("REG", total_payout) シグナル発行
  3. bonus_stocked = false
  4. BGMクロスフェード → normal.ogg（0.5秒）
  5. game_state → IDLE
```

---

## 7. 演出仕様

### 7.1 消灯演出（4段階）

全リール停止後に発生。消灯レベルに応じた期待度を持つ。

| レベル | 演出 | alpha値 | 意味 |
|---|---|---|---|
| 0 | 消灯なし | 0.0 | リプレイ否定 |
| 1 | 軽い暗転 | 0.3 | ハズレ・氷否定 |
| 2 | 中暗転 | 0.55 | **BIG確定**（BIGフラグ時のみ出現） |
| 3 | 重暗転 | 0.8 | ベル否定 → フラッシュに発展 |

**消灯SE**: blackout.wav — 暗転時に再生。レベルに応じて音量変化（level0=無音, level1=-12dB, level2=-6dB, level3=0dB）

### 7.2 消灯振り分けテーブル（256分母）

| フラグ | 0消灯 | 1消灯 | 2消灯 | 3消灯 |
|---|---|---|---|---|
| HAZURE | 128 | 0 | 0 | 128 |
| REPLAY | 0 | 64 | 0 | 192 |
| CHERRY_2 | 64 | 64 | 0 | 128 |
| CHERRY_4 | 32 | 64 | 0 | 160 |
| BELL | 128 | 128 | 0 | 0 |
| ICE | 64 | 0 | 0 | 192 |
| BIG_RED | 32 | 32 | 128 | 64 |
| BIG_BLUE | 32 | 32 | 128 | 64 |
| REG | 64 | 64 | 0 | 128 |

### 7.3 フラッシュ演出（8種）

3消灯時のみ発生。花火モチーフの視覚演出。

| # | 演出名 | イメージ | 色彩定義 | 期待度 |
|---|---|---|---|---|
| 1 | SPARK | 中リール下段一瞬発光 | 白(#FFFFFF)単色、持続0.1秒 | 最低 |
| 2 | GLITCH | デジタルノイズ乱れ | シアン(#00D4FF)グリッチライン | 低 |
| 3 | NEON_SIGN | 枠ネオン順次点灯 | ネオングリーン(#00FF88)→シアン(#00D4FF)グラデ | 中 |
| 4 | STROBE | 高速3回点滅 | 白(#FFFFFF)→ネオンピンク(#FF1493) | 中〜高 |
| 5 | DROP | 光粒子カーテン降下 | ゴールド(#FFD700)パーティクル | 高 |
| 6 | BLOOM | 中央から放射状展開 | パープル(#B14EFF)→ゴールド(#FFD700)放射 | 超高 |
| 7 | STARMINE | 複数箇所連続打上 | 全色ランダムバースト（6色パレットから） | BIG確定級 |
| 8 | TAMAYA | 長溜め→黄金爆発+ボイス | ゴールド(#FFD700)全画面フラッシュ+赤(#FF3333)リング | プレミアム |

**フラッシュSE**: flash.wav — 各フラッシュ開始時に再生。SPARK〜DROPは共通SE、BLOOM以上は専用豪華SE（flash_premium.wav）

### 7.4 フラッシュ振り分けテーブル（3消灯時のみ発生、256分母）

| フラグ | SPARK | GLITCH | NEON_SIGN | STROBE | DROP | BLOOM | STARMINE | TAMAYA |
|---|---|---|---|---|---|---|---|---|
| HAZURE | 128 | 96 | 32 | 0 | 0 | 0 | 0 | 0 |
| REPLAY | 64 | 64 | 64 | 48 | 16 | 0 | 0 | 0 |
| CHERRY_2 | 32 | 48 | 64 | 64 | 32 | 16 | 0 | 0 |
| CHERRY_4 | 0 | 16 | 32 | 48 | 64 | 64 | 32 | 0 |
| ICE | 32 | 32 | 64 | 64 | 48 | 16 | 0 | 0 |
| BIG_RED | 0 | 0 | 8 | 16 | 32 | 64 | 96 | 40 |
| BIG_BLUE | 0 | 0 | 8 | 16 | 32 | 64 | 96 | 40 |
| REG | 0 | 8 | 24 | 48 | 64 | 64 | 48 | 0 |

**注**: BELL は 7.2節で3消灯=0のためフラッシュ発生なし。テーブルから除外。

### 7.5 遅れ演出振り分けテーブル（256分母）

**遅れはボーナスフラグ成立時のみ発生**（ハナビ準拠：遅れ = ボーナス確定）

| フラグ | 発生率 |
|---|---|
| HAZURE | 0 |
| REPLAY | 0 |
| CHERRY_2 | 0 |
| CHERRY_4 | 0 |
| BELL | 0 |
| ICE | 0 |
| BIG_RED | 48 (18.75%) |
| BIG_BLUE | 48 (18.75%) |
| REG | 32 (12.5%) |

### 7.6 たーまやーランプ

| 項目 | 値 |
|---|---|
| 発生条件 | ボーナスフラグストック中 |
| 発生確率 | 1/6（毎ゲーム、256分母: 43/256 ≈ 16.8%） |
| 意味 | **ボーナス確定告知** |
| 演出 | ランプ点灯 + ひかり「たーまやー！」ボイス |
| タイミング | レバーON後、遅れ判定後、リール回転開始前（1.4節参照） |

### 7.7 キャラクターリアクション振り分け

| 状態 | キャラ | リアクション | 条件 |
|---|---|---|---|
| 通常待機 | ひかり | IDLE | 常時 |
| 演出期待 | ひかり | EXPECT | 消灯レベル2以上 or 遅れ発生 |
| 遅れ発生 | ひかり | **原則無反応** | 遅れの違和感を損なわないため。3G以上気づかなかった場合 or 1/10確率でのみ反応 |
| 小役入賞(チェリー/ベル) | ひかり | HAPPY | 入賞時 |
| 小役入賞(リプレイ) | ひかり | HAPPY（軽め） | replay_win SE同期 |
| 小役入賞(氷) | ひかり | HAPPY（強め） | ice_win SE同期 |
| ハズレ | ひかり | SAD | ガセ演出後（3消灯→HAZURE） |
| BIG確定 | るな | EXCITED | BIG図柄揃い or たまや（BIG） |
| REG確定 | こはる | HAPPY | REG図柄揃い |
| BIG消化中 | るな | BONUS | BIG中全ゲーム |
| REG消化中 | こはる | BONUS | REG中全ゲーム |
| RT中 | ひかり | EXPECT | RT全ゲーム |
| RT中(BIG_BLUE後) | ひかり | EXPECT（強め） | BIG_BLUE後RT中のリアクション強度UP |

### 7.8 リーチ目仕様

特定のリール停止パターンが出現した場合、ボーナスフラグストック中であることを示す。

| パターン名 | 条件 | 判定タイミング |
|---|---|---|
| ゲチェナ | LEFT下段CHR + RIGHT下段BAR | 全リール停止後 |
| リプレイハズレ | 5ラインいずれかでRPL×3が揃う出目なのに、リプレイフラグが非成立（=リプレイ入賞なし） | 全リール停止後 |
| 3連BEL出現 | LEFTリール窓内にBELが3連続表示（ボーナスストック確定） | 全リール停止後 |

**リーチ目検出時の演出**:
- 専用SE（reach_me.wav）
- リール窓のフレームが一瞬パープル(#B14EFF)発光
- ひかりが目を見開く（REACH_ME リアクション）

### 7.9 ボーナス中演出仕様（SP-2）

#### 7.9.1 BIG中演出（3フェーズ構成）

BIG BONUS消化中は45G（リプレイ除外）を3フェーズに分け、テンションを段階的に上昇させる。

| フェーズ | ゲーム範囲 | BGM | 演出 | キャラ |
|---|---|---|---|---|
| OPENING | 1G〜15G | bonus_big（通常テンポ） | 通常背景色+軽めのパーティクル | るな BONUS |
| CLIMAX | 16G〜35G | bonus_big（テンポ+10%） | 背景色シフト（パープル→ゴールド）+パーティクル増量 | るな EXCITED |
| FINALE | 36G〜45G | bonus_big（テンポ+20%）+フィルタ開放 | 全画面ゴールドグロー+最大パーティクル | るな EXCITED+エフェクト強 |

**フェーズ遷移SE**: phase_change.wav（各フェーズ開始時に再生）

#### 7.9.2 REG中演出

REG BONUSは14G（リプレイ除外）。BIGより簡素な演出設計。

| 項目 | 値 |
|---|---|
| BGM | bonus_reg（固定テンポ） |
| 背景 | 通常背景+軽いシアンオーバーレイ |
| キャラ | こはる BONUS（固定） |
| フェーズ分け | なし（14Gのため短い） |

#### 7.9.3 BGM変化条件

| 条件 | BGM変化 |
|---|---|
| BIG OPENING→CLIMAX | テンポ+10%（AudioServer.playback_speed_scale） |
| BIG CLIMAX→FINALE | テンポ+20%+ローパスフィルタ解除 |
| ボーナス中チェリー入賞 | 0.5s BGMダッキング(-6dB)+チェリーSE |
| ボーナス残り3G | カウントダウンSE重畳 |

### 7.10 RT演出仕様（SP-3）

#### 7.10.1 RT演出3段階テンション

BIG後のRT（40G）を3段階のテンションで演出する。

| 段階 | ゲーム範囲 | BGM | 背景演出 | キャラ |
|---|---|---|---|---|
| CALM | 1G〜15G | rt_bgm（通常） | 通常背景+微かなシアンパルス | ひかり EXPECT |
| RISING | 16G〜30G | rt_bgm（テンポ+5%）+フィルタスウィープ開始 | シアンパルス強化+背景スクロール速度UP | ひかり EXPECT（強め） |
| CLIMAX | 31G〜40G | rt_bgm（テンポ+15%）+フィルタ全開 | ゴールド+シアン交互フラッシュ | ひかり EXCITED |

#### 7.10.2 BIG_BLUE後RT差別化

BIG_BLUE後のRTはBIG_RED後と演出面で差別化し、連チャン期待感を強調する。

| 項目 | BIG_RED後RT | BIG_BLUE後RT |
|---|---|---|
| BGMベース | rt_bgm | rt_bgm_blue（テンポ+8%） |
| 背景色ベース | シアン(#00D4FF) | ディープブルー(#0044FF)+パープル(#B14EFF) |
| パーティクル | 通常量 | 1.5倍量 |
| キャラ反応強度 | 通常 | 強め（期待度UP演出） |

#### 7.10.3 カウントダウン演出

| タイミング | 演出 |
|---|---|
| RT残り5G | カウントダウン数字表示開始（7セグ風） |
| RT残り3G | カウントダウンSE重畳+背景テンション最大 |
| RT残り1G | 全画面フラッシュ予兆 |
| RT終了 | フェードアウト→通常復帰（1.5s遷移） |

---

## 8. 画面仕様

### 8.0 画面基本設定

| 項目 | 値 | 備考 |
|---|---|---|
| Viewport | 900 x 1600 | 縦長ポートレート |
| 画面の向き | **Portrait（縦画面固定）** | `display/window/handheld/orientation=1` |
| Stretch Mode | canvas_items | UI自動スケーリング |
| Stretch Aspect | expand | アスペクト比拡張 |
| Android Orientation | Portrait (`screen/orientation=1`) | AndroidManifest に反映 |

**画面の向きは全プラットフォームで縦画面（Portrait）固定とする。横画面への回転は許可しない。**

### 8.1 画面一覧

| 画面 | シーン | 説明 |
|---|---|---|
| タイトル | TitleScreen.tscn | ロゴ + PLAY/SETTINGS ボタン |
| ゲーム | Game.tscn | メインゲーム画面（筐体） |
| 設定 | Settings.tscn | 設定変更 + 統計表示 |
| データカウンター | DataCounter.tscn | 詳細統計（オーバーレイ） |

### 8.2 ゲーム画面レイアウト（900x1600）

```
Y=0    ┌─────────────────────────────┐
       │      トップ装飾パネル       │ 120px
Y=120  ├─────────────────────────────┤
       │    キャラクターエリア        │ 200px
       │ (VTuber風キャラリアクション) │
Y=320  ├━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┥
       │  ┌──────┬──────┬──────┐     │
       │  │  L   │  C   │  R   │     │ 520px
       │  │リール │リール │リール │     │ (リール窓)
       │  │200x480│200x480│200x480│   │
       │  └──────┴──────┴──────┘     │
       │  ─── センターライン ───      │
Y=840  ├━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┥
       │ [CREDIT:050] [PAY:000] [BET:3]│ 80px (7セグ)
Y=920  ├─────────────────────────────┤
       │ [BET][  STOP ][  STOP ][  STOP ][LEVER]│ 200px
       │  80  10 150  10 150  10 150  10 100    │ (gap=10px)
Y=1120 ├─────────────────────────────┤
       │  BIG:0  REG:0  │  差枚:+0   │ 80px
Y=1200 ├─────────────────────────────┤
       │     ボトム装飾パネル         │ 120px
Y=1320 ├─────────────────────────────┤
       │      セーフエリア            │ 280px
Y=1600 └─────────────────────────────┘
```

### 8.3 リール窓詳細

| 項目 | 値 |
|---|---|
| リール幅 | 各200px |
| リール間ギャップ | 15px |
| 3リール合計幅 | 630px (200x3 + 15x2) |
| 左右マージン | 各135px |
| クロームフレーム幅 | 各15px |
| 表示図柄数 | 3段（上段・中段・下段） |
| 図柄高さ | 160px |
| 図柄間隙間 | 4px |
| 3図柄合計高さ | 488px (160x3 + 4x2) |
| 上下影帯 | 各40px（リール窓の内側にオーバーレイ） |
| リール窓総高さ | 520px（488px + 上下余白16px×2） |

### 8.4 ボタンパネル詳細

| ボタン | 幅x高 | テキスト | 色 | 備考 |
|---|---|---|---|---|
| MAX BET | 80x120 | MAX BET | ゴールド(#FFD700) | 左端 |
| STOP L | 150x120 | STOP | 白(#EAEAFF) | |
| STOP C | 150x120 | STOP | 白(#EAEAFF) | |
| STOP R | 150x120 | STOP | 白(#EAEAFF) | |
| LEVER | 100x120 | LEVER | オレンジ(#FFB347) | 右端 |

| レイアウト計算 | 値 |
|---|---|
| ボタン合計幅 | 80+150+150+150+100 = 630px |
| ボタン間隙間 | 10px × 4 = 40px |
| パネル合計幅 | 670px |
| 左右マージン | (900-670)/2 = 115px |

ボタン外観:
- 3Dベベルシェーダーで立体感
- 押下時: 色が暗くなる + 2px下にオフセット
- 無効時: 暗灰色(#2D2D44)、LEDインジケーター消灯
- 有効時: 通常色、LEDインジケーター点灯（緑 #00FF88）

### 8.5 7セグ情報パネル

| 表示 | 位置 | 桁数 | LED色 | 説明 |
|---|---|---|---|---|
| CREDIT | 左 | 4桁 | #00FF88 | 現在クレジット（0-9999） |
| PAYOUT | 中央 | 3桁 | #00FF88 | 今回の払出枚数 |
| BET | 右 | 1桁 | #00FF88 | BET枚数（常に3） |

フォント: DSEG7 Classic（OFLライセンス、7セグメント表示用フォント）
背景: 非点灯セグメントを暗灰色(#1A1A2E, alpha=0.3)で表示（実機の消灯セグメント再現）

**7セグシェーダーパラメータ**:
```
uniform float glow_radius = 2.0      # グロー範囲（px）
uniform float glow_intensity = 0.6   # グロー強度（0.0-1.0）
uniform vec4 led_color = vec4(0.0, 1.0, 0.53, 1.0)  # #00FF88
uniform float segment_sharpness = 0.8  # セグメント境界のシャープネス
```

---

## 9. リール描画仕様

### 9.1 回転速度

| 項目 | 値 | 根拠 |
|---|---|---|
| 回転速度 | **80 RPM** | 法規制上限: 別表第5 |
| ピクセル速度 | **4592 px/sec** | 80/60 × 21 × CELL_H(164) |
| 1コマ通過時間 | **35.7ms** | 0.75秒/周 ÷ 21コマ |
| 図柄高さ+隙間 | **164px** (160 + 4) | — |
| 最大滑り | **4コマ** | 190ms / 35.7ms ≒ 5.3 → 安全マージン |

### 9.2 加速

| 項目 | 値 | 根拠 |
|---|---|---|
| 加速時間 | **0.4秒** | 特許JP2002159626A準拠 |
| 加速カーブ | **ease-in** | 段階的加速のステッピングモーター模倣 |
| 始動方式 | **3リール同時始動** | 実機仕様 |

- 加速開始から0.4秒でフル回転速度（80RPM / 4592px/sec）に到達
- ease-inカーブにより、始動直後は低速 → 徐々に加速するステッピングモーターの挙動を模倣

### 9.3 停止方式

**コマ送り即停止**（ステッピングモーター全相励磁制動）

| 項目 | 値 | 根拠 |
|---|---|---|
| 停止方式 | **コマ送り即停止** | ステッピングモーター全相励磁制動 |
| 停止時間 | **0〜143ms** (法規制190ms以内) | 0〜4コマ × 35.7ms |
| 0コマ停止 | 0ms | — |
| 4コマ停止 | 約143ms | 4 × 35.7ms |
| 減速カーブ | **なし** | 実機のステッピングモーターは即停止 |

**禁止事項**: ease-out によるなめらかな停止は**絶対に使用しない**（実機にない挙動）

**停止制御の詳細**:
1. STOPボタン押下 → 押下位置を取得（scroll_offset考慮で半コマ丸め）
2. ReelLogic が 0〜4コマ滑り位置を計算（フラグ制御）
3. **フル回転速度のままコマ送り** → 残りピクセル0でスナップ停止
4. 微バウンス（50ms）で「パシッ」という停止感を表現
5. **減速カーブは一切使用しない**（実機のステッピングモーターは即停止）

### 9.4 バウンス

| 項目 | 値 |
|---|---|
| バウンス量 | **1.5px** |
| バウンス時間 | **50ms**（down 20ms + up 30ms） |
| 方向 | 下方向 1.5px → 元位置に戻る |
| 目的 | ステッピングモーター停止時の微振動を再現 |

- スナップ停止直後に発動、「パシッ」という即停止感を優先
- Tween を使わず `_physics_process()` で手動制御すること（物理同期のため）

### 9.5 STOPボタン有効化タイミング

| 条件 | 詳細 |
|---|---|
| 有効化タイミング | **全3リールがフル回転速度（80RPM）に到達した後** |
| 加速中の押下 | **無効**（受け付けない） |
| 有効化の基準 | 加速開始から0.4秒経過し、全リールがFULL_SPEED状態になった時点 |

### 9.6 状態マシン

```gdscript
enum ReelState {
    IDLE,           # 静止
    ACCELERATING,   # 加速中（0→MAX_SPEED、0.4秒、ease-in）
    FULL_SPEED,     # 定速回転中（4592px/s = 80RPM）
    SLIP_STOPPING,  # コマ送り停止中（0-4コマ分をフル速度で送り切る）
    BOUNCING,       # 微バウンス（50ms、ステッピングモーター微振動再現）
}
# STOPボタン押下: FULL_SPEED → SLIP_STOPPING（0-4コマ送り） → スナップ停止 → BOUNCING → IDLE
# 滑り計算(0-4コマ)はSlotEngine/ReelLogicが担当、ReelStripは結果を即反映
# ACCELERATING中はSTOP押下を無効化すること
```

### 9.7 モーションブラー（reel_blur.gdshader）

FULL_SPEED状態で縦方向モーションブラーを適用し、回転中の残像効果を再現:

| 項目 | 値 |
|---|---|
| `blur_strength` | 0.0（停止）〜 1.0（フル回転80RPM） |
| 加速中 | 速度に比例して徐々にブラー強度が上昇 |
| 停止時 | **即座に** blur_strength = 0（クリアな図柄表示） |
| ブラー方式 | 5-tap gaussian blur（center + 4 pairs = 9 samples）+ 軽微な彩度低下（実機の残像感） |

- ブラー強度は回転速度（px/sec）に比例: `blur_strength = current_speed / MAX_SPEED`
- 停止後はフレーム遅延なく即座にクリアな図柄を表示する

### 9.8 方式: clip_contents連続ストリップスクロール

**実機準拠のリール描画**:
- 全21図柄+ループ用追加5図柄を単一Controlコンテナ（ストリップ）に垂直配置
- clip_contentsでリール窓（3段分）をクリッピング
- ストリップのY位置を毎フレーム更新してリール回転を実現
- ドラム曲面シェーダー（乗算ブレンド）でリール窓に円筒ドラムの照明効果を適用
- 回転方向は**上→下**（実機準拠: 図柄が上から現れて下に消える）

**ノード構造（1リール）**:
```
Container (Control, clip_contents=true, 200x488)
├── ReelStrip (Control)
│   └── _strip_node (Control, 200x4264)  ← position.yで全体スクロール
│       ├── Background (ColorRect, 200x4264, STRIP_BG色)
│       ├── Symbol0 (TextureRect 200x160, y=0)
│       ├── Symbol1 (TextureRect 200x160, y=164)
│       ├── ... (21図柄 + 5ループ用 = 26個)
│       └── Symbol25 (TextureRect 200x160, y=4100)
├── DrumOverlay (ColorRect, reel_drum.gdshader, blend_mul)
└── GlassOverlay (ColorRect, reel_glass.gdshader)
```

**ストリップ構造**:
- 21図柄 + ループ用5図柄（先頭5図柄の複製）= 26図柄
- ストリップ全高: 26 × 164px = 4264px
- 1周分の高さ: 21 × 164px = 3444px
- リール窓表示域: 488px（3段分 = 3 × 164px ≒ 492px）

### 9.9 バックライトシェーダー

```
uniform float backlight_intensity = 0.25            # 実機のバックライト相当
uniform vec4 backlight_color = vec4(1.0, 0.98, 0.93, 1.0)  # 暖白色
```

中央が最も明るく、上下に向かって減衰する照射分布を再現。

### 9.10 ドラム曲面シェーダー（reel_drum.gdshader）

実機のリール窓 = 円筒ドラムの曲面越しに図柄を見る構造を再現:
- cosine曲線で上下の暗化（中央=1.0、端≈0.55）
- 中央にハイライトブースト（バックライト焦点）
- 左右エッジの軽い暗化（ドラム側面の曲率）
- `render_mode blend_mul` で背景と乗算合成

```
uniform float shadow_strength = 0.45    # ドラム曲面暗化の強さ
uniform float highlight_boost = 0.12    # 中央ハイライト
```

### 9.11 ガラス反射シェーダー（reel_glass.gdshader）

実機のリール窓ガラスに蛍光灯が映り込む効果:
- 上部に微かな白い反射帯（smoothstepで山型分布）
- `reflection_opacity = 0.06`（控えめな反射）
図柄の不透明部分に微量の暖白色光を加算。実機の蛍光灯バックライト再現。

### 9.12 エッジ影シェーダー

上下15%の範囲にsmoothstepで黒グラデーション。実機のリールドラム曲面影再現。
影帯高さ: 40px（8.3節と統一）

---

## 10. 音響仕様

### 10.1 SE一覧（23種）

| ID | ファイル | タイミング | 音像 | 優先度 |
|---|---|---|---|---|
| lever_pull | lever_pull.wav | レバーON | 金属スプリングのガチャ音 | 高 |
| reel_start | reel_start.wav | リール回転開始 | モーター起動の「フィーン」 | 中 |
| reel_stop_l | reel_stop_l.wav | LEFT停止 | 低めのカチッ（220Hz基調） | 高 |
| reel_stop_c | reel_stop_c.wav | CENTER停止 | 中音のカチッ（330Hz基調） | 高 |
| reel_stop_r | reel_stop_r.wav | RIGHT停止 | 高めのカチッ（440Hz基調） | 高 |
| bet_insert | bet_insert.wav | BETボタン | メダル投入のチャリン | 高 |
| medal_out | medal_out.wav | 配当開始 | メダル連続落下のジャラジャラ | 高 |
| medal_single | medal_single.wav | 1枚ごと | 単発チャリン | 低 |
| wait_tick | wait_tick.wav | ウェイト中1秒毎 | 「ピッ」(1000Hz, 50ms) | 中 |
| big_fanfare | big_fanfare.wav | BIG開始 | 3秒ファンファーレ（Cメジャー進行） | 最高 |
| reg_fanfare | reg_fanfare.wav | REG開始 | 2秒ファンファーレ（控えめ） | 最高 |
| bonus_end | bonus_end.wav | ボーナス終了 | 終了ジングル（1.5秒） | 高 |
| cherry_win | cherry_win.wav | チェリー入賞 | 軽いチャイム（2音、明るめ） | 中 |
| bell_win | bell_win.wav | ベル入賞 | 明るいチャイム（3音、上行） | 中 |
| replay_win | replay_win.wav | リプレイ入賞 | 短い電子音（ピロン） | 低 |
| ice_win | ice_win.wav | 氷入賞 | クリスタル音（きらきら系） | 中 |
| reach_me | reach_me.wav | リーチ目検出 | 緊張感のある低音（80Hz, 0.3s） | 高 |
| tamaya | tamaya.wav | たーまやーランプ | ひかりボイス「たーまやー！」| 最高 |
| blackout | blackout.wav | 消灯演出 | 低い「ドン」（100Hz, 0.15s） | 中 |
| flash | flash.wav | フラッシュ(SPARK-DROP) | キラッという高音（2000Hz, 0.1s） | 中 |
| flash_premium | flash_premium.wav | フラッシュ(BLOOM-TAMAYA) | 豪華なきらめき（和音, 0.3s） | 高 |
| bonus_align | bonus_align.wav | ボーナス図柄揃い | ドラマチックなヒット音（0.5s） | 最高 |
| rt_start | rt_start.wav | RT開始 | 上昇音（ピロロロ、0.3s） | 高 |

### 10.2 BGM一覧（5曲）

| ID | ファイル | シーン | BPM | ループ | 長さ | スタイル |
|---|---|---|---|---|---|---|
| title | title.ogg | タイトル画面 | 100 | ✅ | 30秒 | エレクトロポップ。シンセパッド+軽いビート。ネオン繁華街の夜の雰囲気。キーはEbメジャー |
| normal | normal.ogg | 通常時 | 90 | ✅ | 30秒 | チルホップ/ローファイ。穏やかなシンセベース+リズムボックス。長時間聴いても疲れない音設計。キーはCマイナー |
| bonus_big | bonus_big.ogg | BIG中 | 140 | ✅ | 45秒 | アップテンポEDM。シンセリード+キック4つ打ち+サイドチェインコンプ。高揚感重視。キーはAメジャー |
| bonus_reg | bonus_reg.ogg | REG中 | 120 | ✅ | 30秒 | ファンクポップ。スラップベース+カッティングギター風シンセ。明るくコンパクト。キーはGメジャー |
| rt | rt.ogg | RT中 | 110 | ✅ | 30秒 | テンスエレクトロ。パルスシンセ+フィルタースウィープ。緊張感と浮遊感。キーはDマイナー |

### 10.3 音量バランス

| チャンネル | デフォルト(dB) |
|---|---|
| Master | 0 |
| BGM | -8 |
| SE | -3 |

### 10.4 ダッキングルール

| トリガーSE | BGM処理 | 復帰 |
|---|---|---|
| big_fanfare | BGMを-20dBに即座ダッキング | ファンファーレ終了後0.5秒かけて復帰 |
| reg_fanfare | BGMを-20dBに即座ダッキング | ファンファーレ終了後0.5秒かけて復帰 |
| bonus_align | BGMを-12dBに0.1秒でダッキング | 0.3秒後に復帰 |
| tamaya | BGMを-15dBに即座ダッキング | ボイス終了後0.3秒かけて復帰 |
| medal_out | BGMを-6dBに0.2秒でダッキング | メダル払出完了後0.3秒かけて復帰 |

### 10.5 メダル払出SE規則

| 配当枚数 | SE処理 |
|---|---|
| 1-2枚 | medal_single × 配当枚数（0.1秒間隔） |
| 3-9枚 | medal_single × 3回（0.08秒間隔） + medal_out |
| 10枚以上 | medal_out（ループ再生、払出完了で停止） |

### 10.6 BGMクロスフェード

| 遷移 | フェード時間 | 方式 |
|---|---|---|
| 通常→ボーナス | 0.5秒 | ファンファーレ再生後、BGM即クロスフェード |
| ボーナス→RT(BIG後) | 0.5秒 | bonus_end SE後にクロスフェード |
| ボーナス→通常(REG後) | 0.5秒 | bonus_end SE後にクロスフェード |
| RT→通常 | 1.0秒 | 40G消化後に緩やかにクロスフェード |
| タイトル→ゲーム | 0.3秒 | 画面遷移と同期 |

### 10.7 「遅れ」音声実装

遅れ演出時の音声処理:
1. レバーON → lever_pull SE は通常通り再生
2. reel_start SE の再生を **0.4秒遅延**（BGMは止めない）
3. 0.4秒間、BGMのみ+レバー音の残響 → 「リール回転音が聞こえない」違和感を演出
4. 0.4秒後 → reel_start SE再生 + リール回転開始

### 10.8 プロシージャル生成仕様（フォールバック）

wavファイルが存在しない場合、AudioStreamWAVをコードで生成:

| パラメータ | 値 |
|---|---|
| サンプリングレート | 44100Hz |
| ビット深度 | 16bit |

**ADSRデフォルト値**:
| SE種別 | Attack | Decay | Sustain | Release |
|---|---|---|---|---|
| 金属音（レバー等） | 0.002s | 0.05s | 0.3 | 0.1s |
| チャイム（入賞等） | 0.005s | 0.1s | 0.4 | 0.2s |
| クリック（ストップ等） | 0.001s | 0.02s | 0.0 | 0.02s |
| 電子音（ビープ等） | 0.001s | 0.01s | 0.8 | 0.05s |

**音色生成式**:
- 金属音: 基本周波数 + ホワイトノイズ(0.3振幅) + 2.5倍音(0.15振幅)
- チャイム: 基本周波数 + 減衰正弦波(2.0倍音 0.3振幅)
- クリック: ホワイトノイズバースト(0.01s) + ローパスフィルタ(2000Hz)

---

## 11. データ永続化仕様

### 11.1 セーブデータ形式

ファイル: `user://neonflora_save.json`

```json
{
  "version": 1,
  "setting": 3,
  "credit": 50,
  "total_games": 0,
  "big_count": 0,
  "reg_count": 0,
  "total_in": 0,
  "total_out": 0,
  "coin_history": [],
  "bonus_history": [],
  "session_count": 0,
  "total_play_time_sec": 0,
  "achievements": [],
  "game_state": "IDLE",
  "bonus_stocked": false,
  "bonus_stocked_type": "",
  "bonus_games_played": 0,
  "bonus_games_max": 0,
  "bonus_type_internal": "",
  "rt_active": false,
  "rt_remaining": 0,
  "rt_bonus_rate": 1.0,
  "current_flag": 0
}
```

### 11.2 統計データ

| フィールド | 型 | 説明 |
|---|---|---|
| setting | int (1-6) | 現在の設定 |
| credit | int | 現在クレジット |
| total_games | int | 累計ゲーム数 |
| big_count | int | BIG回数 |
| reg_count | int | REG回数 |
| total_in | int | 総投入枚数 |
| total_out | int | 総払出枚数 |
| coin_history | Array[int] | 差枚数推移（最大1000点） |
| bonus_history | Array[Dict] | ボーナス履歴（最大100件） |
| session_count | int | セッション数 |
| total_play_time_sec | int | 総プレイ時間（秒） |
| achievements | Array[String] | 達成済み称号ID |
| game_state | String | 最後のGameState（復帰用） |
| bonus_stocked | bool | ボーナスストック有無 |
| bonus_stocked_type | String | ストック中のボーナス種別（"BIG_RED"/"BIG_BLUE"/"REG"/""） |
| bonus_games_played | int | ボーナス消化中の経過ゲーム数（リプレイ除く） |
| bonus_games_max | int | ボーナス規定ゲーム数（BIG=45, REG=14） |
| bonus_type_internal | String | 内部ボーナス種別（"BIG_RED"/"BIG_BLUE"/"REG"/""）— RT補正率判定用 |
| rt_active | bool | RT中かどうか |
| rt_remaining | int | RT残りゲーム数 |
| rt_bonus_rate | float | RT中ボーナス当選確率補正（1.0=通常, 1.5=BIG_BLUE後） |
| current_flag | int | 現在の成立フラグ（復帰用） |

### 11.3 セーブタイミング

- ゲーム終了時（アプリ閉じる時: `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`）
- ボーナス終了時
- 50ゲームごと（定期バックアップ）
- 設定変更時
- RT開始・終了時

### 11.4 セーブデータ検証

```
ロード時の検証:
1. JSONパースエラー → デフォルトデータで初期化、警告ログ出力
2. version不一致 → マイグレーション処理（未来バージョンは拒否）
3. credit < 0 → 0に補正
4. credit > 9999 → 9999に補正
5. setting < 1 or setting > 6 → 3に補正
6. game_state が無効な値 → "IDLE"に補正
7. total_games, big_count, reg_count < 0 → 0に補正
8. bonus_stocked=true && bonus_stocked_type="" → bonus_stocked=falseに補正
9. rt_active=true && rt_remaining <= 0 → rt_active=falseに補正
10. rt_remaining > 40 → 40に補正
11. bonus_games_played < 0 → 0に補正
12. bonus_games_played > bonus_games_max → bonus_games_max に補正、bonus_stocked=false
13. coin_history.size() > 1000 → 先頭から切り詰め（FIFO）
14. bonus_history.size() > 100 → 先頭から切り詰め（FIFO）
15. rt_bonus_rate が 1.0 でも 1.5 でもない → 1.0 に補正
```

### 11.5 バックアップ

- セーブ成功時に `neonflora_save.json.bak` を作成
- メインファイルが破損時に `.bak` からリカバリを試行

---

## 12. 設定画面仕様

### 12.1 設定項目

| 項目 | 操作 | 値域 |
|---|---|---|
| 設定変更 | ボタン（1-6選択） | 1〜6 |
| BGM音量 | スライダー | 0-100% |
| SE音量 | スライダー | 0-100% |
| クレジットリセット | ボタン + 確認ダイアログ | 50にリセット |
| データリセット | ボタン + 確認ダイアログ | 全統計初期化 |

### 12.2 統計表示

| 表示項目 | 計算式 | ゼロ除算対策 |
|---|---|---|
| 総ゲーム数 | total_games | - |
| BIG回数 | big_count | - |
| REG回数 | reg_count | - |
| 合算確率 | total_games / (big_count + reg_count) | (big_count+reg_count)==0 → "---" |
| BIG確率 | total_games / big_count | big_count==0 → "---" |
| REG確率 | total_games / reg_count | reg_count==0 → "---" |
| 差枚数 | total_out - total_in | - |
| 機械割 | total_out / total_in * 100 (%) | total_in==0 → "---" |

---

## 13. 入力仕様

### 13.1 キーボード

| キー | アクション |
|---|---|
| B | MAX BET |
| Space | LEVER |
| Z | STOP LEFT |
| X | STOP CENTER |
| C | STOP RIGHT |
| D | デバッグ: BIG強制発動 |
| R | デバッグ: REG強制発動 |
| T | デバッグ: +1000クレジット |
| P | デバッグ: 状態JSON出力 |

### 13.2 タッチ

各ボタンのタッチ領域は表示サイズ + 8px パディング（タッチターゲット最低44dp確保）

---

## 14. アーキテクチャ仕様

### 14.1 Autoload（3つ）

| Name | Path | 責務 |
|---|---|---|
| GameData | scripts/persist/game_data.gd | セーブ/ロード、統計、セッション |
| SlotEngine | scripts/engine/slot_engine.gd | 抽選、フラグ、リール停止、状態遷移 |
| AudioManager | scripts/audio/audio_manager.gd | SE/BGM再生、音量制御、ダッキング |

### 14.2 SlotEngine 内部構成

SlotEngine は以下のヘルパーを内部で使用:
- `reel_logic.gd` — `_calc_stop_position()`, `_is_valid_stop()`, リーチ目検出
- `bonus_controller.gd` — ボーナス開始/終了、RT管理、ゲーム数追跡
- `wait_timer.gd` — 4.1秒ウェイト制御

### 14.3 シグナル一覧

```gdscript
# SlotEngine が発行するシグナル
signal game_state_changed(new_state: GameState)
signal credit_changed(new_credit: int)
signal flag_determined(flag: int, production: Dictionary)
signal reel_stop_calculated(reel_idx: int, position: int, window: Array)
signal all_reels_stopped()
signal payout_started(amount: int, flag: int)
signal payout_finished()
signal bonus_triggered(type: String)  # "BIG_RED", "BIG_BLUE", "REG"
signal bonus_ended(type: String, total_payout: int)
signal rt_started(games: int)
signal rt_ended()
signal wait_started(duration: float)
signal wait_ended()
signal reach_me_detected(pattern_name: String)
signal tamaya_fired()
signal delay_fired()
```

### 14.4 ファイル一覧（全量）

| パス | 種類 | 行数目安 | 説明 |
|---|---|---|---|
| scripts/engine/slot_engine.gd | Autoload | 250 | 状態管理+シグナル発行 |
| scripts/engine/reel_logic.gd | Class | 150 | 滑り制御+停止位置計算 |
| scripts/engine/bonus_controller.gd | Class | 120 | ボーナス/RT管理 |
| scripts/engine/wait_timer.gd | Class | 40 | 4.1秒ウェイト |
| scripts/data/pay_table.gd | Static | 50 | フラグenum+配当定数 |
| scripts/data/probability_table.gd | Static | 120 | 抽選テーブル |
| scripts/data/reel_data.gd | Static | 70 | リール配列 |
| scripts/data/symbol_table.gd | Static | 60 | 図柄→テクスチャ対応 |
| scripts/data/production_table.gd | Static | 150 | 消灯/フラッシュ/遅れ振り分け |
| scripts/data/reach_me_table.gd | Static | 60 | リーチ目パターン |
| scripts/persist/game_data.gd | Autoload | 150 | セーブ/ロード+統計+検証 |
| scripts/audio/audio_manager.gd | Autoload | 250 | SE/BGM管理+ダッキング |
| scripts/audio/sound_generator.gd | Class | 150 | プロシージャル生成 |
| scripts/ui/reel_renderer.gd | UI | 60 | リール窓全体制御 |
| scripts/ui/reel_strip.gd | UI | 250 | 1リール描画+アニメーション |
| scripts/ui/machine_frame.gd | UI | 40 | フレーム制御 |
| scripts/ui/seven_seg_display.gd | UI | 80 | 7セグ表示 |
| scripts/ui/stop_button.gd | UI | 60 | ボタン+LED |
| scripts/ui/lever_handle.gd | UI | 40 | レバー操作 |
| scripts/ui/character_panel.gd | UI | 100 | キャラリアクション |
| scripts/ui/effect_overlay.gd | UI | 200 | 消灯/フラッシュ/遅れ |
| scripts/ui/data_counter_bar.gd | UI | 40 | BIG/REG/差枚表示 |
| scripts/game.gd | Scene | 350 | ゲーム画面制御 |
| scripts/main.gd | Scene | 20 | シーン遷移 |
| scripts/title_screen.gd | Scene | 30 | タイトル画面 |
| scripts/settings.gd | Scene | 100 | 設定画面 |

### 14.5 シェーダー一覧

| ファイル | 用途 | 主要パラメータ |
|---|---|---|
| chrome_frame.gdshader | クロームフレーム金属光沢 | reflection_strength, roughness |
| seven_seg.gdshader | 7セグLEDグロー | glow_radius=2.0, glow_intensity=0.6 |
| button_bevel.gdshader | ボタン立体感 | bevel_depth, light_angle |
| reel_drum.gdshader | ドラム曲面パースペクティブ+照明 (§9.5) | shadow_strength=0.45, highlight_boost=0.12, blend_mul |
| reel_glass.gdshader | リール窓ガラス反射 (§9.6) | reflection_opacity=0.06, y_start=0.02, y_end=0.18 |
| backlight.gdshader | リールバックライト (§9.4) | intensity=0.25, color=暖白色, Y位置グラデーション |
| symbol_glow.gdshader | 入賞図柄グロー | glow_color, pulse_speed |
| scanline.gdshader | CRTスキャンライン（オプション） | line_spacing, opacity |

---

## 15. テスト仕様

**注**: テストケースの詳細条件分岐・期待値は、QAエージェントが別ファイル（`docs/test_cases/`）で管理する。本節は概要のみ記載。

### 15.1 自動テスト（14件）

#### E2Eテスト（PowerShell）

| # | テスト名 | スクリプト | 内容 | 合格基準 |
|---|---|---|---|---|
| 1 | gameplay_basic | test_gameplay.ps1 | BET→LEVER→STOP×3→判定 を3ゲーム | 3ゲーム完走、IDLE復帰 |
| 2 | bonus_cycle | test_bonus_cycle.ps1 | BIG強制→消化→RT→復帰 | BIG開始→45G消化→RT40G→通常復帰 |
| 3 | reg_cycle | test_reg_cycle.ps1 | REG強制→消化→通常復帰 | REG開始→14G消化→通常復帰（RT無し） |
| 4 | reach_me | test_reach_me.ps1 | リーチ目パターン検証 | 3パターン各1回以上検出 |
| 5 | credit_boundary | test_credit.ps1 | credit=0でBET不可、credit上限 | BET無効確認、9999上限確認 |
| 6 | rapid_input | test_rapid.ps1 | 全ボタン高速連打（10回/秒） | クラッシュなし、状態不整合なし |
| 7 | wait_timer | test_wait.ps1 | 4.1秒ウェイト動作確認 | ウェイト中操作不可、4.1秒後解放 |
| 8 | save_load | test_save.ps1 | セーブ→強制終了→再起動→データ復帰 | credit/統計値が保持 |
| 9 | bonus_interrupt | test_interrupt.ps1 | BONUS中にアプリ終了→復帰 | BONUS状態・bonus_games_playedが復帰 |
| 10 | rt_bonus | test_rt_bonus.ps1 | RT中にBIG当選→RT破棄→BIG消化 | RT残ゲーム0、BIG正常消化 |
| 11 | long_play | test_long.ps1 | 100ゲーム連続自動プレイ | クラッシュなし、メモリ増加率5%以内 |
| 12 | screenshot_all | test_screenshots.ps1 | 全画面スクリーンショット撮影 | タイトル/ゲーム/設定/ボーナス/RT各1枚 |
| 13 | delay_tamaya | test_delay.ps1 | 遅れ演出・たーまやー発生検証 | BIG強制→遅れ/たまや発生をdebug_stateで確認 |
| 14 | reel_stop_verify | test_reel_stop.ps1 | 各フラグ時のリール停止位置検証 | debug_state.reel_positionsが全フラグで正しい出目 |

#### 単体テスト（reel_logic検証、GDScript内蔵）

reel_logic.gdに `_run_unit_tests()` メソッドを組み込み、デバッグキー「U」で実行。結果をログ出力。

| # | テスト項目 | 検証内容 | 合格基準 |
|---|---|---|---|
| U1 | HAZURE停止制御 | 全リール×全21位置で、HAZURE時に5ライン上で入賞図柄が揃わないこと | 63パターン全PASS |
| U2 | HAZURE時チェリー蹴り | LEFT停止時、HAZURE時にCHRが上段/中段/下段に来ない位置を選択すること | CHRを含む位置が蹴られること |
| U3 | REPLAY引き込み | 全リール×全21位置で、REPLAY時に5ラインいずれかでRPLが引き込めること | 引き込み成功率=リール配列上のRPL分布で決まる理論値と一致 |
| U4 | BELL引き込み | 同上、BEL（5ライン） | 同上 |
| U5 | ICE引き込み | 同上、ICE（5ライン） | 同上 |
| U6 | CHERRY_2角配置 | LEFT全21位置で、CHERRY_2時にCHRが上段or下段に来ること | 引き込み成功=CHRがスリップ4コマ以内にある場合 |
| U7 | CHERRY_4中段配置 | LEFT全21位置で、CHERRY_4時にCHRが中段に来ること | 同上 |
| U8 | ボーナス図柄引き込み | ストック中+HAZURE時、各ボーナス図柄(S7R/S7B/BAR)の5ライン引き込み可否 | 4コマ以内にある場合のみ引き込み成功 |
| U9 | 全フラグ×全位置の網羅 | 9フラグ×3リール×21位置=567パターンの停止位置計算 | 全パターンで5ライン上不正入賞なし |

### 15.2 スクリーンショットチェック項目

- [ ] タイトル画面が正常表示
- [ ] ゲーム画面のレイアウトが仕様通り
- [ ] 7セグ表示が正しく点灯（非点灯セグメント暗灰色）
- [ ] リールが3段表示（上段・中段・下段）
- [ ] ボタンが正しい位置・サイズ（間隔10px確認）
- [ ] キャラクターが表示
- [ ] ボーナス中画面が正常（BIG: るな / REG: こはる）
- [ ] RT中画面が正常（BGM切替確認）
- [ ] 消灯演出の暗転が確認できる
- [ ] フラッシュ演出の色が仕様通り

### 15.3 デバッグ出力

`windows/debug_state.json` にPキーで出力:

```json
{
  "game_state": "IDLE",
  "current_flag": 0,
  "bonus_stocked": false,
  "bonus_stocked_type": "",
  "bonus_games_played": 0,
  "bonus_games_max": 0,
  "bonus_type_internal": "",
  "rt_active": false,
  "rt_remaining": 0,
  "rt_bonus_rate": 1.0,
  "reel_positions": [0, 0, 0],
  "credit": 50,
  "total_games": 0,
  "wait_remaining": 0.0,
  "big_count": 0,
  "reg_count": 0,
  "total_in": 0,
  "total_out": 0,
  "last_production": {}
}
```

---

## 16. 境界値・エッジケース仕様

### 16.1 クレジット

| 状況 | 処理 |
|---|---|
| credit < 3（BET不足） | BETボタン無効化。IDLE(credit<3)状態 |
| credit = 0 | BETボタン無効。全操作不可。画面にクレジット不足表示 |
| 配当後 credit > 9999 | 9999にクランプ（超過分は切り捨て） |
| credit = 9999 でBET | credit = 9996。正常にゲーム進行 |

### 16.2 ボーナス

| 状況 | 処理 |
|---|---|
| BIG中に45Gちょうど消化 | そのゲームの配当を加算後、即終了 |
| BIG中にリプレイ連続 | リプレイはゲーム数にカウントしない。規定ゲーム数到達まで継続 |
| ストック中に再度ボーナス当選 | ハズレに差し替え（3.6節） |
| RT中にボーナス当選 | RT破棄→ボーナスストック（3.5節） |
| BIG_BLUE後RT中のボーナス当選 | 1.5倍補正適用済み確率で判定。当選時RT破棄→ボーナスストック |

### 16.3 リプレイ

| 状況 | 処理 |
|---|---|
| リプレイ時credit=0 | 自動BET（credit変動なし）で次ゲーム。正常 |
| リプレイ連続 | 連続リプレイ可。RT中は高確率で連続する |

### 16.4 アプリライフサイクル

| 状況 | 処理 |
|---|---|
| SPINNING中にアプリ終了 | BET返却 → IDLE保存（2.4節） |
| ボーナス中にアプリ終了 | bonus_stocked + bonus_games_played保存 → 復帰時BONUS再開 |
| RT中にアプリ終了 | rt_remaining + rt_bonus_rate保存 → 復帰時RT継続 |

---

## 17. アクセシビリティ仕様

### 17.1 色覚対応

| 対策 | 適用箇所 |
|---|---|
| ピンク(#FF1493)/パープル(#B14EFF)同時使用時は**形状でも区別** | フラッシュ演出、キャラUI |
| フラッシュ演出: 色+形状パターンの組合せ | BLOOM=放射形状、STARMINE=バースト形状、TAMAYA=リング形状 |
| ボーナス図柄: 赤7/青7は色だけでなく「7」テキスト色も変更 | 赤7=暖色系テクスチャ、青7=寒色系テクスチャ |
| 7セグLED: 単色(#00FF88)のため色覚問題なし | - |

### 17.2 フラッシュ光過敏症対策

| 対策 | 値 |
|---|---|
| STROBEフラッシュ: 3回点滅/1秒未満 | 3Hz以下（W3Cガイドライン準拠） |
| 全画面フラッシュは最大輝度の80%に制限 | TAMAYA演出等 |

---

## 18. オートプレイ・ウェイトカット仕様（SP-1）

### 18.1 オートプレイ

設定画面から有効化。BET→LEVER→STOP×3を自動で実行する。

#### 18.1.1 速度モード

| モード | STOP間隔 | 1G所要時間（目安） | 用途 |
|---|---|---|---|
| NORMAL | 0.8s | 約6.5s | 演出を楽しみつつ自動 |
| FAST | 0.3s | 約4.0s | 通常プレイ速度 |
| TURBO | 0.05s | 約2.4s | 高速消化（2.7倍速相当） |

#### 18.1.2 自動停止条件（6種）

オートプレイは以下のいずれかの条件で自動停止する。設定画面で個別にON/OFF可能。

| # | 条件 | デフォルト |
|---|---|---|
| 1 | ボーナス成立（BIG/REG揃い時） | ON |
| 2 | クレジット0 | ON（強制） |
| 3 | 指定ゲーム数消化（50/100/200/500/∞） | 100G |
| 4 | 収支が指定額以下に到達（-100/-300/-500枚） | OFF |
| 5 | RT突入時 | OFF |
| 6 | リーチ目出現時 | OFF |

#### 18.1.3 オートプレイ中のUI

| 項目 | 表示 |
|---|---|
| 表示位置 | InfoLabel（画面下部） |
| 表示内容 | 「AUTO [残りXXG]」or「AUTO [∞]」 |
| 停止操作 | 任意のボタンタップで即停止 |
| ボーナス中 | オートプレイ継続（停止条件1がONの場合は揃い時のみ停止） |

### 18.2 ウェイトカット

通常、レバーON後に4.1秒のウェイトが発生する（規則準拠）。ウェイトカットはウェイト中にSTOPボタンを押すことで、残りウェイト時間をスキップする機能。

| 項目 | 値 |
|---|---|
| 発動条件 | WAITING状態中にいずれかのSTOPボタンをタップ |
| 効果 | ウェイト即解除→SPINNING遷移 |
| オートプレイ連動 | FAST/TURBOモードではウェイト自動カット |
| NORMALモード | ウェイトカットしない（演出待ち時間として活用） |

### 18.3 高速モード（TURBOモード詳細）

| 項目 | 値 |
|---|---|
| リール加速開始速度 | 通常の1.5倍 |
| リール停止アニメ | バウンスなし（即停止） |
| 消灯演出 | 短縮（0.3s→0.1s） |
| フラッシュ演出 | 短縮（各種0.5倍速） |
| 配当表示 | 短縮（1.0s→0.3s） |
| 1G実測目標 | 2.4s以内（通常6.5sの約2.7倍速） |

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|---|---|---|
| 2026-03-01 | 0.1 | 初版ドラフト作成 |
| 2026-03-01 | 0.2 | Gate 0.9ディレクター指摘対応: BIG重み修正(55→110)、遅れ矛盾解消(ボーナス限定)、RT中ボーナス処理追加、影サイズ統一(40px)、ボタン間隔追加(10px)、SubViewport高さ修正(824px)+採用理由追記、フラッシュ色定義追加、BGM音楽スタイル定義追加、SE6種追加(replay_win,ice_win,blackout,flash,flash_premium,bonus_align,rt_start)、ダッキングルール追加、メダル払出SE規則追加、遅れ音声実装詳細追加、プロシージャル生成ADSR値追加、セーブデータにgame_state/bonus_stocked/rt_remaining追加、セーブデータ検証・バックアップ追加、テストケース3→12件、境界値仕様(§16)追加、アクセシビリティ仕様(§17)追加、統計ゼロ除算対策追加、アプリ中断復帰仕様追加、シグナル発行順序明記 |
| 2026-03-01 | 0.2.1 | Gate 0.9再審査QA指摘対応: PAYING配当方式明確化(全額一括加算)、セーブデータ検証14項目に拡充(rt/bonus整合性)、テスト14件+単体テスト9件追加(reel_logic検証)、HAZUREチェリー蹴り明記、リプレイハズレ定義明確化、BELLフラッシュ注記追加 |
| 2026-03-02 | 0.4.0 | α仕様策定: §7.9 ボーナス中演出仕様(BIG 3フェーズ/REG簡素/BGM変化条件)、§7.10 RT演出仕様(3段階テンション/BIG_BLUE差別化/カウントダウン)、§18 オートプレイ・ウェイトカット仕様(3速度モード/6自動停止条件/ウェイトカット/TURBOモード詳細) |
| 2026-03-04 | 0.5.0 | §9 リール仕様を実機準拠パラメータに全面改訂: §9.1 回転速度(80RPM/4592px/sec/35.7ms/コマ)、§9.2 加速(0.4秒/ease-in/3リール同時始動)、§9.3 停止方式(コマ送り即停止/190ms以内/ease-out禁止明記)、§9.4 バウンス(1.5px/50ms=down20ms+up30ms)、§9.5 STOPボタン有効化タイミング(全リールFULL_SPEED到達後)、§9.6 状態マシン(ACCELERATING中STOP無効化明記)、§9.7 モーションブラー(新規セクション/速度比例blur_strength/停止時即0)。旧§9.3.1を§9.7に昇格・拡充、旧シェーダー仕様を§9.8〜9.12に再番号付け。 |
| 2026-03-01 | 0.3.0 | プロデューサーFB反映: 5ライン判定化(中段1→横3+斜め2)、BLK図柄廃止(全21コマ有効図柄)、3連BEL配置(LEFTリール pos2-4)、ボーナスゲーム数管理化(BIG=45G/REG=14G、リプレイ除外)、チェリー配当逆転(角=4枚/中段=2枚)、ICE技術介入(最終停止リール1コマ制限)、BIG_RED/BLUE統合揃え(プレイヤー目押し選択)、BIG_BLUE後RT連チャン補正(1.5倍)、遅れキャラ演出抑制(原則無反応)、停止順序自由化(順/中/逆押し対応)、ボタンマトリクス15状態に拡張、リーチ目更新(単チェリー→3連BEL)、セーブデータ項目追加(bonus_games_played/bonus_type_internal/rt_bonus_rate)、テスト仕様QA管理方針追記 |

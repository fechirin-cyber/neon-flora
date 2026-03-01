# NEON FLORA 詳細仕様書

**ステータス**: APPROVED（Gate 0.9 全ディレクター承認済）
**最終更新**: 2026-03-01
**バージョン**: 0.2.1
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
     → 未経過: WAITING状態、ウェイト音再生、残時間経過を待つ　＠レバーがグレーアウトするなど視覚的にwaitingが分かる
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
   → 中段ライン（有効ライン）の図柄を確認　＠判定は実際のスロット同様横上段・横中段・横下段・斜め２つの５判定でおこなうこと。
   → 配当判定
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
   → 高確率テーブルで抽選　＠払い出し枚数の最低保証が必要。ベンチマークタイトルではビタ押しを前提とした技術介入要素があるので組み入れる。MAX配当のうち、適当順押しで当たる場合と、ビタ押し前提の２種があり、ボーナスゲーム数中0割～1割でランダムにビタ押し要求の目がでる。ビタ押し要求の場合、第一リールが停止したときに、ビタ押し要求前提の目になる。ビタ押し要求前提＝氷当選だとおもうが、HANABIの仕様を再確認して参考にする。
   → 累積配当がMAXに達したら終了　＠累積配当は妥当か？ボーナスはゲーム数で決まるのであって、払い出し枚数で決めないのがスタンダード   
   → BIG終了後 → RT状態（40G）
   → REG終了後 → 通常状態

6. [RT中] リプレイタイム　＠RT中、連チャンを期待させる演出ができるように注意
   → RTテーブルで抽選（リプレイ確率UP: 約1/1.8）
   → 40ゲーム消化で終了 → 通常状態
   → RT中にボーナス当選時: RT残ゲームは破棄（ボーナス優先）
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
| キャラ演出 | ひかりが一瞬固まる → 「…え？」という表情　＠キャラ演出がはいるとわかり易すぎて遅れの違和感の楽しさを損なう。BIG確定にプレイヤーが規定回数気が付かなかったときか、低確率の演出に留める |　
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
BONUS --[MAX配当到達]--> RT(BIGのみ) or IDLE(REG)
RT --[40G消化]--> IDLE
RT --[ボーナス当選]--> (ストック後、揃えたら)BONUS ※RT残ゲーム破棄
```

### 2.3 ボタン有効/無効マトリクス
＠STOPPINGのケースが限定的になっている。中押し・逆押しのケースが不足。CR停止も不足
| 状態 | BET | LEVER | STOP L | STOP C | STOP R |
|---|---|---|---|---|---|
| IDLE(credit>=3) | ✅ | ❌ | ❌ | ❌ | ❌ |
| IDLE(credit<3) | ❌ | ❌ | ❌ | ❌ | ❌ |
| IDLE(BET済) | ❌ | ✅ | ❌ | ❌ | ❌ |
| WAITING | ❌ | ❌ | ❌ | ❌ | ❌ |
| SPINNING | ❌ | ❌ | ✅ | ✅ | ✅ |
| STOPPING(L停止) | ❌ | ❌ | ❌ | ✅ | ✅ |
| STOPPING(LC停止) | ❌ | ❌ | ❌ | ❌ | ✅ |
| STOPPING(LR停止) | ❌ | ❌ | ❌ | ✅ | ❌ |
| PAYING | ❌ | ❌ | ❌ | ❌ | ❌ |
| BONUS | BET/LEVERで1G消化 | | | | |
| RT | 通常と同じ | | | | |

**注**: リプレイ時はBETが自動（ボタン不要）→ 即LEVER有効

### 2.4 アプリ中断・復帰

**PAYING配当方式**: 配当判定時にcreditへ**全額一括加算**。PAYING状態のアニメーション（メダル払出演出）は表示のみ。これにより中断時の二重加算リスクを排除。
＠RTもRT回数を保持する必要があるように見える
| 状況 | 処理 |
|---|---|
| IDLE/RT中断 | セーブデータから完全復帰 |
| SPINNING/STOPPING中断 | 現ゲーム無効化。BET返却(credit+=3)。IDLEまたはRT状態で復帰 |
| PAYING中断 | credit加算済みのため追加処理なし。IDLE(or RT/BONUS)として保存 |
| BONUS中断 | bonus_stocked/bonus_accumulated_payoutを保存し、BONUS状態で復帰 |
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
＠レーン判定を５つに拡張したとき、自動的に角チェリーと中段チェリーの取得枚数が逆になるはずなので修正しておく。赤７青７はAT当選や連チャンなどの期待値の示唆にしかつかわないので、enumで区分して管理してもいいが、意図のある詳しい仕様区分が必要。青７はRTからの連チャン率に補正をかけるなど。また内部的に区分されるのみであって、赤でも青でも、成立していれば両方７の図柄が揃えられるべきである
```gdscript
enum Flag {
    HAZURE = 0,     # ハズレ
    REPLAY = 1,     # リプレイ
    CHERRY_2 = 2,   # 角チェリー（2枚）
    CHERRY_4 = 3,   # 中段チェリー（4枚）
    BELL = 4,       # ベル（10枚）
    ICE = 5,        # 氷（15枚）
    BIG_RED = 6,    # BIG（赤7）
    BIG_BLUE = 7,   # BIG（青7）
    REG = 8,        # REG（BAR）
}
```

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
| 有効ライン | 中段1ライン ＠上記で指摘の通り５ラインに|
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
const BLK = 7   # 空白（ブランク）
```

### 4.3 リール配列（21図柄 × 3リール）

**LEFT リール**:＠ハナビで象徴的な３連どんちゃんを再現してほしい
```
[S7R, BEL, BLK, CHR, BLK, RPL, BEL, BLK, ICE, BEL,
 BLK, RPL, BEL, CHR, BLK, S7B, BEL, RPL, BLK, BEL, BAR]
```

**CENTER リール**:
```
[S7R, BLK, RPL, BEL, BLK, ICE, BEL, RPL, BLK, BEL,
 BLK, S7B, BEL, BLK, RPL, ICE, BEL, BLK, RPL, BEL, BAR]
```

**RIGHT リール**:
```
[S7R, BEL, BLK, RPL, BEL, BLK, ICE, BEL, RPL, BLK,
 BAR, BEL, BLK, RPL, BEL, S7B, BLK, ICE, BEL, RPL, BEL]
```

### 4.4 図柄分布

| 図柄 | LEFT | CENTER | RIGHT |
|---|---|---|---|
| S7R(赤7) | 1 | 1 | 1 |
| S7B(青7) | 1 | 1 | 1 |
| BAR | 1 | 1 | 1 |
| CHR(チェリー) | 2 | 0 | 0 |
| BEL(ベル) | 7 | 7 | 7 |
| ICE(氷) | 1 | 2 | 2 |
| RPL(リプレイ) | 3 | 4 | 4 |
| BLK(空白)　＠空白はなくして２１コマにそろえる | 5 | 5 | 5 |
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
＠５ライン用に修正する
| 成立フラグ | 制御内容 |
|---|---|
| HAZURE | 有効ライン上にいかなる入賞図柄も揃えてはならない。**LEFT: CHRが上段/中段/下段に来る位置も蹴る**（チェリーは左リール単独判定のため） |
| REPLAY | 中段にRPLを引き込む |
| CHERRY_2 | LEFTのみ: CHRを上段or下段に（角チェリー）。C/Rは制約なし |
| CHERRY_4 | LEFTのみ: CHRを中段に。C/Rは制約なし |
| BELL | 中段にBELを引き込む |
| ICE | 中段にICEを引き込む　＠ベンチマーク相当で氷に技術介入要素をいれること。３つめの停止のみ引き込み猶予を１コマにするなど |
| BIG_RED/BLUE/REG | ボーナスフラグ自体は小役と重複可。小役を優先制御 |

### 4.7 ボーナス図柄揃い条件

ストックされたボーナスフラグがある場合、かつ当該ゲームの小役がHAZUREの場合:
- BIG_RED: 中段に赤7(S7R)を3つ揃える（4コマ以内に引き込めれば）
- BIG_BLUE: 中段に青7(S7B)を3つ揃える　＠こちらも引き込みをいれなくていいか
- REG: 中段にBAR(BAR)を3つ揃える　＠こちらも引き込みをいれなくていいか
---

## 5. 配当仕様
＠各種事項を５ライン用に修正すること
＠上記に記載しているチェリー角チェリーと中段チェリー修正忘れずに
### 5.1 小役配当

| 入賞役 | 条件 | 配当（枚） |
|---|---|---|
| リプレイ | 中段RPL揃い | 0（BET返却=次ゲーム自動BET） |
| 角チェリー | LEFT上段or下段にCHR | 2 |
| 中段チェリー | LEFT中段にCHR | 4 |
| ベル | 中段BEL揃い | 10 |
| 氷 | 中段ICE揃い | 15 |

### 5.2 ボーナス配当
＠上記の通り、ボーナスはゲーム数管理にすること
| ボーナス | 最大配当（枚） | 終了条件 |
|---|---|---|
| BIG | 344 | 累積配当 ≥ 344枚 |
| REG | 105 | 累積配当 ≥ 105枚 |

### 5.3 配当判定優先順位

1. チェリー（LEFTリールの位置で判定、C/Rは不問）
2. リプレイ（中段3リールRPL揃い）
3. ベル（中段3リールBEL揃い）
4. 氷（中段3リールICE揃い）
5. ボーナス図柄揃い（中段3リール同一ボーナス図柄）

---

## 6. ボーナス仕様

### 6.1 BIG BONUS

| 項目 | 値 |
|---|---|
| トリガー | 中段赤7×3 or 中段青7×3 |
| 最大配当 | 344枚 |
| 抽選テーブル | ボーナス中テーブル（3.4節） |
| BGM | bonus_big.ogg |
| キャラ | るな（BIG担当）が登場 |
| 終了後 | RT（40G）に突入 |

### 6.2 REG BONUS

| 項目 | 値 |
|---|---|
| トリガー | 中段BAR×3 |
| 最大配当 | 105枚 |
| 抽選テーブル | ボーナス中テーブル（3.4節） |
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

### 6.4 ボーナス終了時の処理

```
BIG終了:
  1. bonus_end SE再生
  2. bonus_ended("BIG", total_payout) シグナル発行
  3. bonus_stocked = false
  4. BGMクロスフェード → rt.ogg（0.5秒）
  5. rt_remaining = 40
  6. game_state → RT
  7. rt_started(40) シグナル発行

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
| 小役入賞(チェリー/ベル) | ひかり | HAPPY | 入賞時 |
| 小役入賞(リプレイ) | ひかり | HAPPY（軽め） | replay_win SE同期 |
| 小役入賞(氷) | ひかり | HAPPY（強め） | ice_win SE同期 |
| ハズレ | ひかり | SAD | ガセ演出後（3消灯→HAZURE） |
| BIG確定 | るな | EXCITED | BIG図柄揃い or たまや（BIG） |
| REG確定 | こはる | HAPPY | REG図柄揃い |
| BIG消化中 | るな | BONUS | BIG中全ゲーム |
| REG消化中 | こはる | BONUS | REG中全ゲーム |
| RT中 | ひかり | EXPECT | RT全ゲーム |

### 7.8 リーチ目仕様

特定のリール停止パターンが出現した場合、ボーナスフラグストック中であることを示す。

| パターン名 | 条件 | 判定タイミング |
|---|---|---|
| ゲチェナ | LEFT下段CHR + RIGHT下段BAR | 全リール停止後 |
| リプレイハズレ | 上段or下段にRPL揃い、かつ中段にRPL揃いなし（=リプレイ入賞なし） | 全リール停止後 |
| 単チェリー | LEFT中段CHR + CENTER/RIGHT中段がBLK | 全リール停止後 |

**リーチ目検出時の演出**:
- 専用SE（reach_me.wav）
- リール窓のフレームが一瞬パープル(#B14EFF)発光
- ひかりが目を見開く（REACH_ME リアクション）

---

## 8. 画面仕様

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

### 9.1 方式: SubViewport連続スクロール

**採用理由**（moe_slotのTextureRectスワップ方式との比較）:
- TextureRectスワップ: 図柄の切り替え時に離散的にジャンプ。スムーズな回転が困難
- SubViewport方式: 連続的なY座標移動により自然なスクロールが実現可能
- バックライト/影エフェクトをSubViewport内に閉じ込めることでクリッピングが容易
- 将来的なリールぼかし/スピードライン等のポストエフェクト追加が容易

**ノード構造（1リール）**:
```
SingleReel (Control, clip_contents=true, 200x520)
├── SubViewportContainer (200x488)
│   └── SubViewport (200x824)
│       └── ReelStrip (Control)  ← Y位置を毎フレーム更新
│           ├── Symbol0 (TextureRect 200x160) + Gap (200x4)  ← バッファ上
│           ├── Symbol1 (TextureRect 200x160) + Gap (200x4)  ← 上段
│           ├── Symbol2 (TextureRect 200x160) + Gap (200x4)  ← 中段
│           ├── Symbol3 (TextureRect 200x160) + Gap (200x4)  ← 下段
│           └── Symbol4 (TextureRect 200x160)                ← バッファ下
├── ShadowTop (TextureRect, 200x40, gradient black→transparent)
├── ShadowBottom (TextureRect, 200x40, gradient transparent→black)
└── BacklightGlow (ColorRect 200x488, backlight.gdshader)
```

**SubViewport高さ計算**:
- 5図柄: 160px × 5 = 800px
- 4隙間: 4px × 4 = 16px
- スクロールバッファ: 8px（上下各4px）
- **合計: 824px**

### 9.2 スクロール物理

| 項目 | 値 |
|---|---|
| 最大速度 | 2800 px/sec |
| 加速時間 | 0.25秒 |
| コマ送り減速 | 1ステップ 0.06秒間隔 × 8ステップ |
| 図柄高さ+隙間 | 164px (160+4) |
| バウンス | 下方向3px → 戻り（0.04s + 0.08s） |

### 9.3 状態マシン

```gdscript
enum ReelState {
    IDLE,           # 静止
    ACCELERATING,   # 加速中（0→MAX_SPEED、0.25秒）
    FULL_SPEED,     # 定速回転中（2800px/s）
    DECELERATING,   # コマ送り減速中（8ステップ）
    BOUNCING,       # バウンスアニメーション
}
```

### 9.4 バックライトシェーダー

```
uniform float backlight_intensity = 0.15
uniform vec4 backlight_color = vec4(1.0, 0.98, 0.95, 1.0)  # 暖白色
```
図柄の不透明部分に微量の暖白色光を加算。実機の蛍光灯バックライト再現。

### 9.5 エッジ影シェーダー

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
  "bonus_accumulated_payout": 0,
  "rt_active": false,
  "rt_remaining": 0,
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
| bonus_accumulated_payout | int | ボーナス消化中の累積配当 |
| rt_active | bool | RT中かどうか |
| rt_remaining | int | RT残りゲーム数 |
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
11. bonus_accumulated_payout < 0 → 0に補正
12. bonus_accumulated_payout > 344(BIG最大) → 0に補正、bonus_stocked=false
13. coin_history.size() > 1000 → 先頭から切り詰め（FIFO）
14. bonus_history.size() > 100 → 先頭から切り詰め（FIFO）
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
- `bonus_controller.gd` — ボーナス開始/終了、RT管理、配当追跡
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
| reel_shadow.gdshader | リール窓エッジ影 | shadow_height=40px, shadow_strength=0.8 |
| backlight.gdshader | リールバックライト | intensity=0.15, color=暖白色 |
| symbol_glow.gdshader | 入賞図柄グロー | glow_color, pulse_speed |
| scanline.gdshader | CRTスキャンライン（オプション） | line_spacing, opacity |

---

## 15. テスト仕様
＠テストケースが全体的に粒度が荒すぎる。条件分岐を含めてQAエージェントで別ファイルで項目管理するなどする
### 15.1 自動テスト（14件）

#### E2Eテスト（PowerShell）

| # | テスト名 | スクリプト | 内容 | 合格基準 |
|---|---|---|---|---|
| 1 | gameplay_basic | test_gameplay.ps1 | BET→LEVER→STOP×3→判定 を3ゲーム | 3ゲーム完走、IDLE復帰 |
| 2 | bonus_cycle | test_bonus_cycle.ps1 | BIG強制→消化→RT→復帰 | BIG開始→344枚消化→RT40G→通常復帰 |
| 3 | reg_cycle | test_reg_cycle.ps1 | REG強制→消化→通常復帰 | REG開始→105枚消化→通常復帰（RT無し） |
| 4 | reach_me | test_reach_me.ps1 | リーチ目パターン検証 | 3パターン各1回以上検出 |
| 5 | credit_boundary | test_credit.ps1 | credit=0でBET不可、credit上限 | BET無効確認、9999上限確認 |
| 6 | rapid_input | test_rapid.ps1 | 全ボタン高速連打（10回/秒） | クラッシュなし、状態不整合なし |
| 7 | wait_timer | test_wait.ps1 | 4.1秒ウェイト動作確認 | ウェイト中操作不可、4.1秒後解放 |
| 8 | save_load | test_save.ps1 | セーブ→強制終了→再起動→データ復帰 | credit/統計値が保持 |
| 9 | bonus_interrupt | test_interrupt.ps1 | BONUS中にアプリ終了→復帰 | BONUS状態・累積配当が復帰 |
| 10 | rt_bonus | test_rt_bonus.ps1 | RT中にBIG当選→RT破棄→BIG消化 | RT残ゲーム0、BIG正常消化 |
| 11 | long_play | test_long.ps1 | 100ゲーム連続自動プレイ | クラッシュなし、メモリ増加率5%以内 |
| 12 | screenshot_all | test_screenshots.ps1 | 全画面スクリーンショット撮影 | タイトル/ゲーム/設定/ボーナス/RT各1枚 |
| 13 | delay_tamaya | test_delay.ps1 | 遅れ演出・たーまやー発生検証 | BIG強制→遅れ/たまや発生をdebug_stateで確認 |
| 14 | reel_stop_verify | test_reel_stop.ps1 | 各フラグ時のリール停止位置検証 | debug_state.reel_positionsが全フラグで正しい出目 |

#### 単体テスト（reel_logic検証、GDScript内蔵）

reel_logic.gdに `_run_unit_tests()` メソッドを組み込み、デバッグキー「U」で実行。結果をログ出力。

| # | テスト項目 | 検証内容 | 合格基準 |
|---|---|---|---|
| U1 | HAZURE停止制御 | 全リール×全21位置で、HAZURE時に入賞図柄が揃わないこと | 63パターン全PASS |
| U2 | HAZURE時チェリー蹴り | LEFT停止時、HAZURE時にCHRが上段/中段/下段に来ない位置を選択すること | CHRを含む位置が蹴られること |
| U3 | REPLAY引き込み | 全リール×全21位置で、REPLAY時に中段RPLが引き込めること | 引き込み成功率=リール配列上のRPL分布で決まる理論値と一致 |
| U4 | BELL引き込み | 同上、BEL | 同上 |
| U5 | ICE引き込み | 同上、ICE | 同上 |
| U6 | CHERRY_2角配置 | LEFT全21位置で、CHERRY_2時にCHRが上段or下段に来ること | 引き込み成功=CHRがスリップ4コマ以内にある場合 |
| U7 | CHERRY_4中段配置 | LEFT全21位置で、CHERRY_4時にCHRが中段に来ること | 同上 |
| U8 | ボーナス図柄引き込み | ストック中+HAZURE時、各ボーナス図柄(S7R/S7B/BAR)の引き込み可否 | 4コマ以内にある場合のみ引き込み成功 |
| U9 | 全フラグ×全位置の網羅 | 9フラグ×3リール×21位置=567パターンの停止位置計算 | 全パターンで不正入賞なし |

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
  "bonus_payout": 0,
  "bonus_max": 0,
  "rt_active": false,
  "rt_remaining": 0,
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
| BIG中に344枚ちょうど到達 | そのゲームの配当を加算後、即終了 |
| BIG中に344枚超過（例: 340+10=350） | 350枚を加算。最大配当は厳密上限ではなく到達トリガー |
| ストック中に再度ボーナス当選 | ハズレに差し替え（3.6節） |
| RT中にボーナス当選 | RT破棄→ボーナスストック（3.5節） |

### 16.3 リプレイ

| 状況 | 処理 |
|---|---|
| リプレイ時credit=0 | 自動BET（credit変動なし）で次ゲーム。正常 |
| リプレイ連続 | 連続リプレイ可。RT中は高確率で連続する |

### 16.4 アプリライフサイクル

| 状況 | 処理 |
|---|---|
| SPINNING中にアプリ終了 | BET返却 → IDLE保存（2.4節） |
| ボーナス中にアプリ終了 | bonus_stocked + accumulated_payout保存 → 復帰時BONUS再開 |
| RT中にアプリ終了 | rt_remaining保存 → 復帰時RT継続 |

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

## 変更履歴

| 日付 | バージョン | 変更内容 |
|---|---|---|
| 2026-03-01 | 0.1 | 初版ドラフト作成 |
| 2026-03-01 | 0.2.1 | Gate 0.9再審査QA指摘対応: PAYING配当方式明確化(全額一括加算)、セーブデータ検証14項目に拡充(rt/bonus整合性)、テスト14件+単体テスト9件追加(reel_logic検証)、HAZUREチェリー蹴り明記、リプレイハズレ定義明確化、BELLフラッシュ注記追加 |
| 2026-03-01 | 0.2 | Gate 0.9ディレクター指摘対応: BIG重み修正(55→110)、遅れ矛盾解消(ボーナス限定)、RT中ボーナス処理追加、影サイズ統一(40px)、ボタン間隔追加(10px)、SubViewport高さ修正(824px)+採用理由追記、フラッシュ色定義追加、BGM音楽スタイル定義追加、SE6種追加(replay_win,ice_win,blackout,flash,flash_premium,bonus_align,rt_start)、ダッキングルール追加、メダル払出SE規則追加、遅れ音声実装詳細追加、プロシージャル生成ADSR値追加、セーブデータにgame_state/bonus_stocked/rt_remaining追加、セーブデータ検証・バックアップ追加、テストケース3→12件、境界値仕様(§16)追加、アクセシビリティ仕様(§17)追加、統計ゼロ除算対策追加、アプリ中断復帰仕様追加、シグナル発行順序明記 |

class_name ReachMeTable
extends RefCounted
## リーチ目パターン定義

# リーチ目パターン: 全リール停止後の窓図柄から検出
# windows: Array[Array[int]] — [left_window, center_window, right_window]
# 各window: [upper, center, lower]

static func check_reach_me(windows: Array) -> String:
	if windows.size() < 3:
		return ""

	var lw: Array = windows[0]  # left [upper, center, lower]
	var cw: Array = windows[1]  # center
	var rw: Array = windows[2]  # right

	# ゲチェナ: LEFT下段CHR + RIGHT下段BAR
	if lw[2] == ReelData.CHR and rw[2] == ReelData.BAR:
		return "gechena"

	# リプレイハズレ: 5ラインいずれかでRPL×3が揃う出目なのにリプレイ非成立
	var rpl_on_any_line := false
	# L1: 横上段
	if lw[0] == ReelData.RPL and cw[0] == ReelData.RPL and rw[0] == ReelData.RPL:
		rpl_on_any_line = true
	# L2: 横中段
	if lw[1] == ReelData.RPL and cw[1] == ReelData.RPL and rw[1] == ReelData.RPL:
		rpl_on_any_line = true
	# L3: 横下段
	if lw[2] == ReelData.RPL and cw[2] == ReelData.RPL and rw[2] == ReelData.RPL:
		rpl_on_any_line = true
	# L4: 斜め右下がり (L上, C中, R下)
	if lw[0] == ReelData.RPL and cw[1] == ReelData.RPL and rw[2] == ReelData.RPL:
		rpl_on_any_line = true
	# L5: 斜め右上がり (L下, C中, R上)
	if lw[2] == ReelData.RPL and cw[1] == ReelData.RPL and rw[0] == ReelData.RPL:
		rpl_on_any_line = true
	# RPL揃い出目なのにリプレイ入賞なし = リーチ目（ボーナスストック確定）
	# 注: この関数はボーナスストック中のみ呼ばれるため、非成立は確定
	if rpl_on_any_line:
		return "replay_hazure"

	# 3連BEL: LEFTリール窓内にBELが3連続（ボーナスストック確定）
	if lw[0] == ReelData.BEL and lw[1] == ReelData.BEL and lw[2] == ReelData.BEL:
		return "triple_bell"

	return ""

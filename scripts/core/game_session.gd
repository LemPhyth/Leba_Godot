extends RefCounted
## Profile: cross-scene persistence. Run: one encounter. Actors own HP/MP.
var profile: Dictionary = {}
var run: Dictionary = {}
var _settled_deaths: Dictionary = {}
var _clear_settled := false

func select_character(identifier: String) -> void:
	profile.selection.character_id = identifier

func select_mode(identifier: String) -> void:
	profile.selection.mode_id = identifier

func select_difficulty(identifier: String) -> void:
	profile.selection["difficulty_id"] = identifier

func begin_stage(stage_id: String, enemy_count: int) -> void:
	run = {"stage_id": stage_id, "character_id": profile.selection.character_id,
		"mode_id": profile.selection.mode_id, "enemies_remaining": enemy_count,
		"difficulty_id":profile.selection.get("difficulty_id","expert"),
		"source_ticks": 0, "earned_gold": 0, "outcome": "running"}
	_settled_deaths.clear()
	_clear_settled = false

func settle_enemy(identifier: String, reward: int) -> bool:
	if run.is_empty() or _settled_deaths.has(identifier) or run.outcome != "running":
		return false
	_settled_deaths[identifier] = true
	run.enemies_remaining = maxi(0, int(run.enemies_remaining) - 1)
	run.earned_gold += reward
	profile.progress.gold += reward
	return true

func finish(outcome: String) -> bool:
	if run.is_empty() or _clear_settled:
		return false
	_clear_settled = true
	run.outcome = outcome
	if outcome == "victory":
		var id: String = run.stage_id
		profile.progress.clears[id] = int(profile.progress.clears.get(id, 0)) + 1
	return true

func abandon() -> void:
	run.clear()
	_settled_deaths.clear()
	_clear_settled = false

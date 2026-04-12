extends Node


# All 40 cards across 4 decks
var cards: Array[Dictionary] = []
# Cards the player has collected this run: card_id -> count
var collected: Dictionary = {}

func _ready() -> void:
	_define_cards()

func _define_cards() -> void:
	var decks = {
		"deck1_scrap": {
			"deck_name": "Scrap",
			"color": Color(0.7, 0.65, 0.55),
			"items": [
				"bent_nail", "rusty_spring", "cracked_bolt", "iron_chain",
				"dented_can", "copper_wire", "busted_hinge", "old_gear",
				"spark_plug", "steel_jaw"
			]
		},
		"deck2_lost": {
			"deck_name": "Lost",
			"color": Color(0.65, 0.45, 0.75),
			"items": [
				"chewed_ball", "torn_teddy", "lost_shoe", "cracked_marble",
				"old_whistle", "broken_watch", "faded_photo", "tangled_yarn",
				"empty_locket", "music_box"
			]
		},
		"deck3_critter": {
			"deck_name": "Critter",
			"color": Color(0.45, 0.72, 0.40),
			"items": [
				"pill_bug", "rat_king", "crow_feather", "stag_beetle",
				"garden_snake", "toad", "firefly_jar", "spider_web",
				"snail_shell", "moth_wing"
			]
		},
		"deck4_overgrowth": {
			"deck_name": "Overgrowth",
			"color": Color(0.55, 0.42, 0.28),
			"items": [
				"moss_clump", "dandelion", "ivy_vine", "wild_mushroom",
				"acorn", "pine_cone", "bird_nest", "dried_leaf",
				"berry_bush", "old_stump"
			]
		},
	}

	for folder in decks:
		var deck = decks[folder]
		for i in deck.items.size():
			var item_name: String = deck.items[i]
			var num = "%02d" % (i + 1)
			cards.append({
				"id": "%s_%s" % [folder, item_name],
				"name": item_name.replace("_", " ").capitalize(),
				"deck": deck.deck_name,
				"deck_color": deck.color,
				"texture_path": "res://assets/sprites/cards/%s/%s_%s.png" % [folder, num, item_name],
			})

func reset() -> void:
	collected.clear()

func roll_card() -> Dictionary:
	if cards.is_empty():
		return {}
	# Try to find an uncollected card, reroll up to 3 times
	var card: Dictionary = {}
	for _attempt in 3:
		card = cards[randi() % cards.size()]
		if not collected.has(card.id):
			break
	return card

func collect_card(card: Dictionary) -> bool:
	var is_new = not collected.has(card.id)
	collected[card.id] = collected.get(card.id, 0) + 1
	return is_new

func get_deck_progress(deck_name: String) -> Dictionary:
	var total = 0
	var owned = 0
	for c in cards:
		if c.deck == deck_name:
			total += 1
			if collected.has(c.id):
				owned += 1
	return {"owned": owned, "total": total}

func get_total_progress() -> Dictionary:
	var owned = collected.size()
	return {"owned": owned, "total": cards.size()}

func is_deck_complete(deck_name: String) -> bool:
	var dp = get_deck_progress(deck_name)
	return dp.owned >= dp.total and dp.total > 0

# Deck completion bonuses:
# Scrap (complete) → +25 max HP (permanent)
# Lost (complete)  → +10 bite damage (permanent)
# Critter (complete)   → unlocks "Bug Swarm" perk in level-up
# Overgrowth (complete) → unlocks "Vine Snare" perk in level-up

func get_stat_bonuses() -> Dictionary:
	var bonuses = {"max_hp": 0, "damage": 0}
	if is_deck_complete("Scrap"):
		bonuses.max_hp += 25
	if is_deck_complete("Lost"):
		bonuses.damage += 10
	return bonuses


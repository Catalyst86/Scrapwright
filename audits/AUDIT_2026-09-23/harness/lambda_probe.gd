extends Node
func _ready() -> void:
	var tick_count := 0
	var f := func():
		tick_count += 1
		return tick_count
	var results := []
	for i in 8:
		results.append(f.call())
	print("LAMBDA: int captured counter over 8 calls -> ", results, " | outer var after: ", tick_count)
	var arr := [0]
	var g := func():
		arr[0] += 1
		return arr[0]
	var r2 := []
	for i in 8:
		r2.append(g.call())
	print("LAMBDA: array-box counter over 8 calls  -> ", r2)
	get_tree().quit()

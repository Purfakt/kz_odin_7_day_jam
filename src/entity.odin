package game

Id :: u64

id_gen := Id(0)

new_id :: proc() -> Id {
	id_gen += 1
	return id_gen
}

Entity :: struct {
	id:  Id,
	pos: Vec2i,
}

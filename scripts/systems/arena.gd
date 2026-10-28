class_name Arena

const PLAYER := Rect2(22.0, 68.0, 436.0, 176.0)
const ENEMY := Rect2(20.0, 68.0, 440.0, 176.0)
const BULLET_BOUNCE := Rect2(16.0, 64.0, 448.0, 186.0)
const BULLET_DISCARD := Rect2(-24.0, 40.0, 528.0, 254.0)
const BOSS_STEP := Rect2(40.0, 84.0, 400.0, 150.0)
const BOSS_FLOOR := Rect2(26.0, 74.0, 428.0, 166.0)


static func clamp_point(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

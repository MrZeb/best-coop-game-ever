extends Label

var score = 0

func _on_mob_squashed(points):
	score += points
	text = "Score: %s" % score

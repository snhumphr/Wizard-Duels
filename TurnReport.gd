extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func render(turn_queue):
	self.clear()
	for item in turn_queue:
		self.add_text(item)
		self.newline()

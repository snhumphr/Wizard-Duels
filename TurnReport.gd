extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func render(turn_queue: Array):
	#self.clear()
	for i in turn_queue.size():
		var message = turn_queue[i]
		if i > 0:
			message = "    " + message
		self.append_text(message)
		self.newline()

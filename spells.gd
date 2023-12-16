extends Resource
class_name Spell

# The order of this enum is important, because it determines the order in which spell effects actually resolve
enum SpellEffect {
	dispelMagic,
	Counter,
	Summon,
	applyTempEffect,
	removeEnchantment,
	dealDamage,
	Heal,
	Kill
}

@export var name: String = ""
@export var gestures: PackedStringArray
@export var id: int

@export var is_spell: bool = true
@export var is_silent: bool = false

@export var once_per_turn: bool = false
@export var once_per_wizard: bool = false
@export var once_per_duel: bool = false

@export var mandatory: bool = false

@export var hex: bool = false
@export var fire_spell: bool = false
@export var ice_spell: bool = false

@export var dispellable: bool = true
@export var counterable: bool = true
@export var reflectable: bool = true
@export var targetable: bool = true
@export var blockable: bool = false

@export var hostile: bool = false

@export var requires_target: bool = false
@export var can_target_corpses: bool = false
@export var always_targets_self: bool = false

@export var permanency_valid: bool = false

@export var effect: SpellEffect
@export var effect_name: String = ""
@export var intensity: int = 0

func is_two_handed():
	var size = gestures.size()
	if size > 0 and gestures[size-1].length() > 1:
		return true
	else:
		return false

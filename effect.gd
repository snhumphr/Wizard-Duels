extends Resource
class_name Effect

@export var name: String
@export var is_silent: bool = false
@export var permanent: bool = false

@export var shield: bool = false
@export var counterspell: bool = false
@export var reflect: bool = false
@export var fire_res: bool = false
@export var cold_res: bool = false
@export var invisibility: bool = false

@export var surrender: bool = false
@export var fatal: bool = false
@export var curable: int = 0 #How many hit points of healing are required to cure this effect
@export var hex: bool = false
@export var dispellable: bool = true
@export var unstable: bool = false #Whether this effect kills summoned creatures or not

@export var charm_person: bool = false
@export var fear: bool = false
@export var paralysis: bool = false
@export var maladroit: bool = false
@export var amnesia: bool = false

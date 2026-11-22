extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal depleted

@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 1000.0, 1.0) var max_armor: float = 100.0
## Share of every hit that armor soaks up while it lasts.
@export_range(0.0, 1.0, 0.05) var armor_absorption: float = 0.6
## Time-based recovery: after `regen_delay` seconds without taking damage, health refills
## smoothly and completely over `regen_duration` seconds. Enabled for the player in every mode.
@export var regen_enabled: bool = false
@export_range(0.5, 20.0, 0.5) var regen_delay: float = 3.0
@export_range(1.0, 30.0, 0.5) var regen_duration: float = 6.0
var current_health: float = 100.0
var _since_damage: float = 999.0
var current_armor: float = 0.0
var _depleted_emitted: bool = false

func _ready() -> void:
    max_health = maxf(1.0, max_health)
    current_health = max_health

func _process(delta: float) -> void:
    if not regen_enabled or current_health <= 0.0:
        return
    _since_damage += delta
    if _since_damage < regen_delay or current_health >= max_health:
        return
    current_health = minf(max_health, current_health + max_health / regen_duration * delta)
    health_changed.emit(current_health, max_health)

func get_health_fraction() -> float:
    return clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)

func is_alive() -> bool:
    return current_health > 0.0

func apply_damage(amount: float, source: Node = null) -> float:
    if amount <= 0.0 or current_health <= 0.0:
        return current_health
    var absorbed: float = 0.0
    if current_armor > 0.0:
        absorbed = minf(current_armor, amount * armor_absorption)
        current_armor -= absorbed
        armor_changed.emit(current_armor, max_armor)
    _since_damage = 0.0
    current_health = maxf(0.0, current_health - (amount - absorbed))
    health_changed.emit(current_health, max_health)
    damaged.emit(amount, source)
    if current_health <= 0.0 and not _depleted_emitted:
        _depleted_emitted = true
        depleted.emit()
    return current_health

func restore(amount: float) -> float:
    if amount <= 0.0 or current_health <= 0.0:
        return current_health
    current_health = minf(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
    return current_health

func add_armor(amount: float) -> float:
    if amount <= 0.0 or current_health <= 0.0:
        return current_armor
    current_armor = minf(max_armor, current_armor + amount)
    armor_changed.emit(current_armor, max_armor)
    return current_armor

func reset() -> void:
    current_health = max_health
    current_armor = 0.0
    _since_damage = 999.0
    _depleted_emitted = false
    health_changed.emit(current_health, max_health)
    armor_changed.emit(current_armor, max_armor)

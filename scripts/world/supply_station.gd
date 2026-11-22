extends InteractableBase
class_name SupplyStation

## Heals, adds armor and refills ammunition, then recharges for a few seconds.

@export var recharge_seconds: float = 6.0

func _ready() -> void:
    interaction_text = Loc.t("supply_prompt")
    interacted.connect(_on_interacted)

func _on_interacted(actor: Node) -> void:
    var health := actor.get_node_or_null("HealthComponent") as HealthComponent
    if health != null:
        health.restore(health.max_health)
        health.add_armor(health.max_armor)
    var weapon := actor.get_node_or_null("WeaponController")
    if weapon != null and weapon.has_method("refill"):
        weapon.call("refill")
    interaction_enabled = false
    get_tree().create_timer(recharge_seconds).timeout.connect(func() -> void:
        if is_instance_valid(self):
            interaction_enabled = true)

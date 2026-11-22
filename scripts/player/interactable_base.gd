extends StaticBody3D
class_name InteractableBase

signal interacted(actor: Node)

@export var interaction_text: String = "Interact"
@export var interaction_enabled: bool = true

func get_interaction_text() -> String:
    return interaction_text if interaction_enabled else ""

func can_interact(_actor: Node) -> bool:
    return interaction_enabled

func interact(actor: Node) -> void:
    if not can_interact(actor):
        return
    interacted.emit(actor)
    print("[IronYard] Interaction: %s" % interaction_text)

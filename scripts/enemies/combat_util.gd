extends RefCounted
class_name CombatUtil

## Small shared rules for anything that can shoot or be shot: teams, hostility, damage.
## A fighter's team is stored as node meta "team". Free-for-all bots each get a unique team
## string, so everybody is hostile to everybody; zombies use the team "zombie".

static func team_of(node: Node) -> String:
    if node == null or not is_instance_valid(node):
        return ""
    return str(node.get_meta("team", ""))

static func is_alive(node: Node) -> bool:
    if node == null or not is_instance_valid(node):
        return false
    if node.has_method("is_alive"):
        return bool(node.call("is_alive"))
    if node.has_method("is_dead"):
        return not bool(node.call("is_dead"))
    return false

static func is_hostile(a: Node, b: Node) -> bool:
    var team_a: String = team_of(a)
    var team_b: String = team_of(b)
    if team_a.is_empty() or team_b.is_empty():
        return false
    return team_a != team_b

## Applies damage to a bot (through receive_hit) or to the player (through HealthComponent).
static func apply_damage(target: Node, amount: float, source: Node, info: Dictionary) -> Dictionary:
    if target == null or not is_instance_valid(target) or amount <= 0.0:
        return {"headshot": false, "killed": false}
    if target.has_method("receive_hit"):
        var payload: Dictionary = info.duplicate()
        payload["damage"] = amount
        payload["source"] = source
        return target.call("receive_hit", payload)
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    if health != null:
        var was_alive: bool = health.is_alive()
        health.apply_damage(amount, source)
        return {"headshot": false, "killed": was_alive and not health.is_alive()}
    return {"headshot": false, "killed": false}

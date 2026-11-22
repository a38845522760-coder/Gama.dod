extends RefCounted
class_name ShopCatalog

## What the shop sells and the rules for buying/using it. Prices are in credits, which are
## earned from kills, wave bonuses and match results.

const SUPPLIES: Dictionary = {
    "medkit": {"price": 40, "name_fa": "کیت درمان", "name_en": "Medkit", "desc_fa": "۵۰ جان را برمی‌گرداند.", "desc_en": "Restores 50 health.", "color": "#3ddc84"},
    "armor": {"price": 60, "name_fa": "صفحه زره", "name_en": "Armor plate", "desc_fa": "۵۰ زره اضافه می‌کند.", "desc_en": "Adds 50 armor.", "color": "#44b5ee"},
    "ammo": {"price": 50, "name_fa": "بسته مهمات", "name_en": "Ammo pack", "desc_fa": "برای همه تفنگ‌ها مهمات اضافه می‌کند.", "desc_en": "Adds reserve ammo to every gun.", "color": "#ffc94a"},
}

const UPGRADES: Dictionary = {
    "health": {"costs": [250, 500, 900, 1500], "name_fa": "جان بیشتر", "name_en": "Max health", "desc_fa": "+۲۵ جان بیشینه در هر سطح.", "desc_en": "+25 max health per level.", "color": "#ff7a6b"},
    "damage": {"costs": [300, 600, 1000, 1600], "name_fa": "قدرت شلیک", "name_en": "Firepower", "desc_fa": "+۱۰٪ آسیب همه تفنگ‌ها در هر سطح.", "desc_en": "+10% damage with every gun per level.", "color": "#ffb86b"},
    "armor": {"costs": [200, 400, 700, 1100], "name_fa": "زره شروع", "name_en": "Starting armor", "desc_fa": "+۲۵ زره در شروع هر بازی و پس از مرگ.", "desc_en": "+25 armor at match start and after respawn.", "color": "#7fd6ff"},
}

static func supply_name(item_id: String, language: String) -> String:
    var item: Dictionary = SUPPLIES.get(item_id, {})
    return str(item.get("name_" + language, item_id))

static func supply_desc(item_id: String, language: String) -> String:
    var item: Dictionary = SUPPLIES.get(item_id, {})
    return str(item.get("desc_" + language, ""))

static func upgrade_name(upgrade_id: String, language: String) -> String:
    var item: Dictionary = UPGRADES.get(upgrade_id, {})
    return str(item.get("name_" + language, upgrade_id))

static func upgrade_desc(upgrade_id: String, language: String) -> String:
    var item: Dictionary = UPGRADES.get(upgrade_id, {})
    return str(item.get("desc_" + language, ""))

static func upgrade_max_level(upgrade_id: String) -> int:
    var item: Dictionary = UPGRADES.get(upgrade_id, {})
    return (item.get("costs", []) as Array).size()

## Cost of the next level, or -1 when the upgrade is maxed out.
static func upgrade_next_cost(upgrade_id: String) -> int:
    var item: Dictionary = UPGRADES.get(upgrade_id, {})
    var costs: Array = item.get("costs", [])
    var level: int = SaveManager.get_upgrade_level(upgrade_id)
    if level >= costs.size():
        return -1
    return int(costs[level])

static func buy_weapon(weapon_id: String, player: Node = null) -> bool:
    if not WeaponDefinitions.exists(weapon_id) or SaveManager.owns_weapon(weapon_id):
        return false
    var price: int = WeaponDefinitions.get_price(weapon_id)
    if not SaveManager.spend_credits(price):
        return false
    SaveManager.add_weapon(weapon_id)
    if player != null:
        var controller := player.get_node_or_null("WeaponController")
        if controller != null and controller.has_method("add_weapon"):
            controller.call("add_weapon", weapon_id, true)
    SaveManager.flush()
    return true

static func buy_supply(item_id: String) -> bool:
    if not SUPPLIES.has(item_id):
        return false
    var price: int = int((SUPPLIES[item_id] as Dictionary)["price"])
    if not SaveManager.spend_credits(price):
        return false
    SaveManager.add_inventory(item_id, 1)
    SaveManager.flush()
    return true

static func buy_upgrade(upgrade_id: String) -> bool:
    var cost: int = upgrade_next_cost(upgrade_id)
    if cost < 0 or not SaveManager.spend_credits(cost):
        return false
    SaveManager.set_upgrade_level(upgrade_id, SaveManager.get_upgrade_level(upgrade_id) + 1)
    SaveManager.flush()
    return true

## Uses one owned supply on the player. Returns true when something was consumed.
static func use_supply(item_id: String, player: Node) -> bool:
    if player == null or SaveManager.get_inventory(item_id) <= 0:
        return false
    if player.has_method("is_dead") and bool(player.call("is_dead")):
        return false
    var health := player.get_node_or_null("HealthComponent") as HealthComponent
    var weapon := player.get_node_or_null("WeaponController")
    match item_id:
        "medkit":
            if health == null or health.current_health >= health.max_health:
                return false
            health.restore(50.0)
        "armor":
            if health == null or health.current_armor >= health.max_armor:
                return false
            health.add_armor(50.0)
        "ammo":
            if weapon == null or not weapon.has_method("give_ammo_pack"):
                return false
            weapon.call("give_ammo_pack")
        _:
            return false
    SaveManager.use_inventory(item_id)
    return true

extends RefCounted
class_name BotDefinitions

## Every kind of AI fighter: five armed soldier types (each with its own gun and tactics)
## and five zombie types. Difficulty scales accuracy, reaction time and damage.

const DIFFICULTY_NAMES: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTY_AIM: Array[float] = [1.9, 1.0, 0.62]
const DIFFICULTY_REACTION: Array[float] = [1.7, 1.0, 0.6]
const DIFFICULTY_DAMAGE: Array[float] = [0.7, 1.0, 1.25]
const DIFFICULTY_HEALTH: Array[float] = [0.85, 1.0, 1.2]

const NAMES: Array[String] = [
    "Arash", "Babak", "Cyrus", "Dariush", "Farhad", "Kaveh", "Mehrdad", "Nima",
    "Omid", "Parsa", "Reza", "Sina", "Siavash", "Yashar", "Kian", "Bahram",
]

const PROFILES: Dictionary = {
    # ------------------------------------------------------------- soldiers
    "grunt": {
        "kind": "soldier", "name_fa": "سرباز", "name_en": "Grunt",
        "health": 100.0, "armor": 0.0, "speed": 3.5, "weapon": "rifle",
        "damage_scale": 0.42, "aim_error": 2.8, "reaction": 0.45,
        "range_min": 12.0, "range_max": 32.0, "sight": 70.0, "fov": 130.0,
        "burst_min": 3, "burst_max": 7, "burst_pause": 0.7, "strafe": 0.6, "points": 100,
        "look": {"primary": "#55633f", "secondary": "#2f3a2a", "headgear": "helmet", "bulk": 1.0, "scale": 1.0},
    },
    "rusher": {
        "kind": "soldier", "name_fa": "هجومی", "name_en": "Rusher",
        "health": 85.0, "armor": 0.0, "speed": 5.2, "weapon": "shotgun",
        "damage_scale": 0.5, "aim_error": 3.6, "reaction": 0.30,
        "range_min": 2.0, "range_max": 11.0, "sight": 55.0, "fov": 150.0,
        "burst_min": 1, "burst_max": 1, "burst_pause": 0.5, "strafe": 0.9, "points": 120,
        "look": {"primary": "#6a2a24", "secondary": "#201a1a", "headgear": "bandana", "bulk": 0.95, "scale": 1.0},
    },
    "marksman": {
        "kind": "soldier", "name_fa": "تک‌تیرانداز", "name_en": "Marksman",
        "health": 70.0, "armor": 0.0, "speed": 2.9, "weapon": "sniper",
        "damage_scale": 0.42, "aim_error": 0.55, "reaction": 1.1,
        "range_min": 30.0, "range_max": 95.0, "sight": 130.0, "fov": 70.0,
        "burst_min": 1, "burst_max": 1, "burst_pause": 1.4, "strafe": 0.05, "points": 200,
        "look": {"primary": "#4d5738", "secondary": "#3b3427", "headgear": "hood", "bulk": 0.95, "scale": 1.0},
        "laser": true,
    },
    "heavy": {
        "kind": "soldier", "name_fa": "سنگین‌اسلحه", "name_en": "Heavy",
        "health": 260.0, "armor": 0.3, "speed": 2.5, "weapon": "lmg",
        "damage_scale": 0.38, "aim_error": 3.4, "reaction": 0.7,
        "range_min": 14.0, "range_max": 40.0, "sight": 75.0, "fov": 110.0,
        "burst_min": 10, "burst_max": 22, "burst_pause": 1.0, "strafe": 0.15, "points": 250,
        "look": {"primary": "#3a3f45", "secondary": "#22262a", "headgear": "heavy", "bulk": 1.22, "scale": 1.1},
    },
    "officer": {
        "kind": "soldier", "name_fa": "افسر", "name_en": "Officer",
        "health": 140.0, "armor": 0.1, "speed": 3.9, "weapon": "revolver",
        "damage_scale": 0.42, "aim_error": 1.3, "reaction": 0.4,
        "range_min": 8.0, "range_max": 38.0, "sight": 80.0, "fov": 120.0,
        "burst_min": 1, "burst_max": 1, "burst_pause": 0.55, "strafe": 0.7, "points": 180,
        "look": {"primary": "#2f4a63", "secondary": "#1d2630", "headgear": "cap", "bulk": 1.0, "scale": 1.02},
    },
    "ffa_fighter": {
        "kind": "soldier", "name_fa": "جنگجو", "name_en": "Fighter",
        "health": 100.0, "armor": 0.0, "speed": 3.8, "weapon": "rifle",
        "damage_scale": 0.55, "aim_error": 2.2, "reaction": 0.4,
        "range_min": 8.0, "range_max": 30.0, "sight": 75.0, "fov": 140.0,
        "burst_min": 3, "burst_max": 8, "burst_pause": 0.55, "strafe": 0.8, "points": 100,
        "look": {"primary": "#4a5a3c", "secondary": "#2b2f33", "headgear": "helmet", "bulk": 1.0, "scale": 1.0},
    },
    # ------------------------------------------------------------- zombies
    "walker": {
        "kind": "zombie", "name_fa": "زامبی", "name_en": "Walker",
        "health": 75.0, "armor": 0.0, "speed": 2.1, "weapon": "",
        "damage_scale": 1.0, "aim_error": 0.0, "reaction": 0.0,
        "range_min": 0.0, "range_max": 0.0, "sight": 90.0, "fov": 360.0,
        "points": 60, "strafe": 0.0,
        "melee": {"damage": 12.0, "reach": 1.7, "cooldown": 1.1, "windup": 0.3},
        "look": {"primary": "#4b4538", "secondary": "#2a2a2a", "skin": "#7f9468", "headgear": "none", "bulk": 1.0, "scale": 1.0},
    },
    "runner": {
        "kind": "zombie", "name_fa": "زامبی تندرو", "name_en": "Runner",
        "health": 48.0, "armor": 0.0, "speed": 5.4, "weapon": "",
        "damage_scale": 1.0, "aim_error": 0.0, "reaction": 0.0,
        "range_min": 0.0, "range_max": 0.0, "sight": 90.0, "fov": 360.0,
        "points": 80, "strafe": 0.0,
        "melee": {"damage": 9.0, "reach": 1.6, "cooldown": 0.65, "windup": 0.18},
        "look": {"primary": "#3d4a55", "secondary": "#2a2a2a", "skin": "#8aa070", "headgear": "none", "bulk": 0.88, "scale": 0.98},
    },
    "brute": {
        "kind": "zombie", "name_fa": "زامبی غول", "name_en": "Brute",
        "health": 620.0, "armor": 0.2, "speed": 2.0, "weapon": "",
        "damage_scale": 1.0, "aim_error": 0.0, "reaction": 0.0,
        "range_min": 0.0, "range_max": 0.0, "sight": 90.0, "fov": 360.0,
        "points": 300, "strafe": 0.0,
        "melee": {"damage": 45.0, "reach": 2.2, "cooldown": 1.6, "windup": 0.5},
        "look": {"primary": "#5a3a30", "secondary": "#2a2a2a", "skin": "#6e8760", "headgear": "none", "bulk": 1.5, "scale": 1.32},
    },
    "sprinter": {
        "kind": "zombie", "name_fa": "زامبی برق‌آسا", "name_en": "Sprinter",
        "health": 30.0, "armor": 0.0, "speed": 7.4, "weapon": "",
        "damage_scale": 1.0, "aim_error": 0.0, "reaction": 0.0,
        "range_min": 0.0, "range_max": 0.0, "sight": 110.0, "fov": 360.0,
        "points": 90, "strafe": 0.0,
        "melee": {"damage": 6.0, "reach": 1.6, "cooldown": 0.5, "windup": 0.12},
        "look": {"primary": "#2e3640", "secondary": "#1c1c1c", "skin": "#a3b88a", "headgear": "none", "bulk": 0.82, "scale": 0.96},
    },
    "pyro": {
        "kind": "zombie", "name_fa": "زامبی آتش‌افکن", "name_en": "Pyro",
        "health": 1700.0, "armor": 0.2, "speed": 2.4, "weapon": "",
        "damage_scale": 1.0, "aim_error": 2.0, "reaction": 0.4,
        "range_min": 3.5, "range_max": 13.0, "sight": 100.0, "fov": 360.0,
        "points": 900, "strafe": 0.1,
        "melee": {"damage": 40.0, "reach": 2.6, "cooldown": 1.4, "windup": 0.45},
        "spit": {"damage": 4.5, "cooldown": 0.16, "range": 13.0, "speed": 60.0},
        "flame": true,
        "look": {"primary": "#6a2a1a", "secondary": "#201410", "skin": "#8a5a40", "headgear": "none", "bulk": 1.7, "scale": 1.9},
    },
    "spitter": {
        "kind": "zombie", "name_fa": "زامبی اسیدی", "name_en": "Spitter",
        "health": 60.0, "armor": 0.0, "speed": 2.9, "weapon": "",
        "damage_scale": 1.0, "aim_error": 3.0, "reaction": 0.5,
        "range_min": 10.0, "range_max": 22.0, "sight": 90.0, "fov": 360.0,
        "points": 110, "strafe": 0.3,
        "melee": {"damage": 8.0, "reach": 1.6, "cooldown": 1.2, "windup": 0.3},
        "spit": {"damage": 11.0, "cooldown": 1.9, "range": 26.0, "speed": 38.0},
        "look": {"primary": "#3b5a2f", "secondary": "#2a2a2a", "skin": "#9bc24a", "headgear": "none", "bulk": 0.95, "scale": 1.0},
    },
    "tyrant": {
        "kind": "zombie", "name_fa": "ابرزامبی", "name_en": "Tyrant",
        "health": 2400.0, "armor": 0.25, "speed": 3.1, "weapon": "",
        "damage_scale": 1.0, "aim_error": 0.0, "reaction": 0.0,
        "range_min": 0.0, "range_max": 0.0, "sight": 120.0, "fov": 360.0,
        "points": 1200, "strafe": 0.0,
        "melee": {"damage": 48.0, "reach": 2.8, "cooldown": 1.3, "windup": 0.5},
        "boss": true,
        "look": {"primary": "#3a2a2a", "secondary": "#2a2a2a", "skin": "#7a5a50", "headgear": "none", "bulk": 1.7, "scale": 1.75},
    },
}

static func get_profile(profile_id: String) -> Dictionary:
    var source: Dictionary = PROFILES["grunt"]
    if PROFILES.has(profile_id):
        source = PROFILES[profile_id]
    var result: Dictionary = source.duplicate(true)
    result["id"] = profile_id if PROFILES.has(profile_id) else "grunt"
    return result

static func get_display_name(profile_id: String, language: String) -> String:
    var profile: Dictionary = get_profile(profile_id)
    if language == "fa":
        return str(profile.get("name_fa", profile_id))
    return str(profile.get("name_en", profile_id))

static func random_name(rng: RandomNumberGenerator) -> String:
    return NAMES[rng.randi() % NAMES.size()]

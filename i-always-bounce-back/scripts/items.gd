extends Node
func get_items(rarity=-1)->Array:
	var l = []
	if rarity == -1:
		return items
	for i in items:
		if i["rarity"]==rarity:
			l.append(i)
	return l
#key -> 
#stats: health, damage, damage_mult, speed_mult, bounces, cooldown_mult, 
#draw_mult, gravity_mult, restitution_mult, extra_dash, combo_mult, charge_power_mult, style_mult
#one offs: shureikens,shield
#effects, glass_cannon,chain_bolt,explode_bounce,shureikens,auto_bounce,trail_damage,overcharge,fire_debuff,ice_debuff
#heal_on_hit
#todo #parry kb stat



var items: Array = [
	{
		"id": "parry_kb",
		"name": "Slap Hand",
		"desc": "Fling enemies away on parry",
		"rarity": 0,
		"parry_kb": 50,
		"icon": "res://ui/items/damdage.png",
	},
	{
		"id": "pierce",
		"name": "Pure Spirit",
		"desc": "Pierce one additional enemy before bouncing",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "pierce",
		"effect_value": 1, #pierces
	},
	{
		"id": "time_stop_q",
		"name": "Stopwatch",
		"desc": "Press (Q) to slow down time for 10 seconds",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "time_stop",
		"effect_value": 10, #secods
	},
	{
		"id": "heal_q",
		"name": "Restoration Prayer",
		"desc": "Press (Q) to regain half your max HP, only 3 uses",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "heal",
		"effect_value": 3 #uses left
	},
	{
		"id": "ground_pound",
		"name": "Ground Pound",
		"desc": "Lose all air dashes, but landing creates and AOE earthquake",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "earthquake_on_land",
		"effect_value": 10, #range meters
	},
	{
		"id": "overcharge",
		"name": "ULTRAKILL",
		"desc": "Charging beyond limits adds to damage",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"effect": "overcharge",
		"effect_value": 2, #max mult
	},
	{
		"id": "spam",
		"name": "Spam",
		"desc": "No cooldowns, half damage",
		"rarity": 1,
		"cooldown_mult": 0.01,
		"draw_mult": 3,
		"damage_mult": 0.5,
		"icon": "res://ui/items/damdage.png",
	},
	{
		"id": "damage_trail",
		"name": "Effervescence",
		"desc": "Your trail leaves damageing sparks",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"effect": "damage_trail",
		"effect_value": 20, #damage +current damage and mult
	},
	{
		"id": "auto_bounce",
		"name": "Nano Bounce",
		"desc": "Automatically bounce to a nearby enemy on kill",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "auto_bounce",
		#"effect_value": 3, #distrance?
	},
	{
		"id": "shureiken",
		"name": "Shureiken",
		"desc": "A shureiken orbits you and damages foes",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"effect": "shureiken",
		"effect_value": 1, #amount
	},
	{
		"id": "lightning_hit",
		"name": "Chain Bolt",
		"desc": "A bespoke arc of electricity strikes 3 foes upon bouncing",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"effect": "lightning_on_hit",
		"effect_value": 3, #arcs
	},
	{
		"id": "more_air_dashes",
		"name": "Aeronautics",
		"desc": "Gain extra dashes when bouncing that can be used in mid air",
		"rarity": 1,
		"extra_dash": 1,
		"icon": "res://ui/items/damdage.png",
	},
	{
		"id": "more_combo_mult",
		"name": "Adrenaline",
		"desc": "Double combo multiplier",
		"rarity": 0,
		"combo_mult": 2,
		"icon": "res://ui/items/damdage.png",
	},
	{
		"id": "more_restitution",
		"name": "Rubber ball",
		"desc": "Bounce higher and faster ",
		"rarity": 0,
		"restitution_mult": 1.5,
		"charge_power_mult": 1.5,
		"icon": "res://ui/items/damdage.png",
	},
	{
		"id": "shield",
		"name": "Grimoire of Protection",
		"desc": "Summons a magical barrier that will deflect damage every so often",
		"rarity": 0,
		"icon": "res://ui/items/damdage.png",
		"effect": "shield",
		"effect_value": 1 #no of shields
	},
	{
		"id": "ice_debuff",
		"name": "Frostbite",
		"desc": "Slow enemies on hit",
		"rarity": 0,
		"icon": "res://ui/items/damdage.png",
		"effect": "ice_debuff",
		"effect_value": 0.5, #speed mult
	},
	{
		"id": "fire_debuff",
		"name": "Into the Fire",
		"desc": "Light enemies ablaze on hit",
		"rarity": 0,
		"icon": "res://ui/items/damdage.png",
		"effect": "fire_debuff",
		"effect_value": 1.0, #dps for 10 seconds
	},
	{
		"id": "glass_cannon",
		"name": "Glass cannon",
		"desc": "50 max HP, but ludicrous damage",
		"rarity": 2,
		"damage":10,
		"damage_mult": 5,
		"icon": "res://ui/items/damdage.png",
		"effect": "glass",
	},
		{
		"id": "more_bounces",
		"name": "Ricoshet",
		"desc": "Bounce more times before landing",
		"rarity": 0,
		"icon": "res://ui/items/damdage.png",
		"bounces": 3
	},		{
		"id": "cooldown_down",
		"name": "Thyme Brew",
		"desc": "Halves dash cooldown",
		"cooldown_mult": 0.5,
		"rarity":1,
		"icon": "res://ui/items/damdage.png",
	},		{
		"id": "fast_charge",
		"name": "Quick Charge",
		"desc": "Doubles wind-up speed",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"draw_mult": 0.5,
	},{
		"id": "heal_on_kill",
		"name": "Vampirism",
		"desc": "Steal the lifeforce of vanquished foes",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "heal_on_hit",
		"effect_value": 3.0,
	},		
	{	"id": "confusion_q",
		"name": "Confusion",
		"desc": "Confuse enemies on (Q)",
		"rarity": 2,
		"icon": "res://ui/items/damdage.png",
		"effect": "confuse",
		"effect_value": 5.0,
		
	},	{	"id": "explosion_on_hit",
		"name": "Thermite",
		"desc": "Your bounces have an explosive kick..",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"effect": "explode_bounce",
		"effect_value": 1,
		
	},	{	"id": "light_damage",
		"name": "Light as a-",
		"desc": "Deal less damage but decrease all cooldowns and become faster",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"speed_mult": 2,
		"charge_power_mult": 2,
		"gravity_mult": 0.5,
		"damage_mult": 0.5,
		"cooldown": 0.5,
		"draw": 0.5
		
		
	},	{	"id": "heavy_damage",
		"name": "Heavy Core",
		"desc": "Become heavier and deal more damage based on speed",
		"rarity": 1,
		"icon": "res://ui/items/damdage.png",
		"charge_power_mult": 0.9,
		"damage": 20,
		"damage_mult": 1.2,
		"gravity_mult": 2,
		"cooldown_mult": 2,
		"draw_mult": 2,
		"effect": "speed_hit",
		"effect_value": 10.0,
		
	},
]

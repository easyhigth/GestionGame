class_name PlayerNeeds
extends RefCounted
## Besoins du héros, sortis de player.gd : la faim qui se creuse, la nourriture qu'on mange et les potions qu'on boit.
## L'état (hunger, potions_drunk...) reste sur le joueur, que tout le jeu lit ; ici, seulement la logique.

var p: Player


func _init(player: Player) -> void:
	p = player


## Un pas de faim (appelé à chaque pas de physique par le joueur).
func update(delta: float) -> void:
	# option du monde : sans faim, le héros reste rassasié
	if not SaveGame.world_flag("hunger"):
		p.hunger = Player.HUNGER_MAX
		return
	if not p.is_alive() or p.building or p.ui_open:
		return
	var rate := Player.HUNGER_PER_SECOND
	if Vector2(p.velocity.x, p.velocity.z).length() > 2.5:
		rate *= 1.4
	# le froid creuse l'appétit
	var weather: Node = p._weather
	if weather and is_instance_valid(weather) and weather.cold:
		rate *= 1.5
	var before := p.hunger
	p.hunger = maxf(0.0, p.hunger - rate * delta)
	if int(before) != int(p.hunger):
		p.hunger_changed.emit(p.hunger)
	on_state_changed()
	# affamé : on perd de la vie petit à petit (sans descendre sous 10 %)
	if p.hunger <= 0.0:
		p._starve_timer -= delta
		if p._starve_timer <= 0.0:
			p._starve_timer = 3.0
			if p.health.current > p.health.max_health * 0.1:
				p.health.current = maxi(1, p.health.current - 2)
				p.health.changed.emit(p.health.current, p.health.max_health)


## À appeler quand la faim change : prévient le joueur quand il passe affamé ou mourant.
func on_state_changed() -> void:
	var st := p.hunger_state()
	if st == p._hunger_state:
		return
	var old: int = p._hunger_state
	p._hunger_state = st
	p.refresh_stats()
	p.hunger_changed.emit(p.hunger)
	if st == 0 and old > 0:
		p.notify.emit("Tu as faim : mange quelque chose ({eat}). Plus de régénération de vie.")
	elif st == -1:
		p.notify.emit("Tu meurs de faim ! Mange vite ({eat}).")


## Boit une potion (touche R) : une potion de soin si le héros est blessé, sinon une potion de renfort
## dont l'effet n'est pas déjà actif. Renvoie la potion bue (null sinon).
func drink_potion() -> ItemData:
	var hurt := p.health.ratio() < 0.9
	var heal: ItemData = null
	var buff: ItemData = null
	for e in p.inventory.entries:
		var it := e.item as ItemData
		if it == null or not it.is_potion():
			continue
		if it.potion_heal > 0.0 and heal == null:
			heal = it
		elif not it.potion_buff.is_empty() and buff == null and p.skill and not p.skill.buffs.has(it.potion_buff.keys()[0]):
			buff = it
	var pick: ItemData = heal if hurt and heal else buff
	if pick == null:
		p.notify.emit("Aucune potion à boire." if heal == null else "Tu es en pleine forme : garde ta potion de soin.")
		return null
	p.inventory.remove(pick, 1)
	p.potions_drunk += 1
	if pick.potion_heal > 0.0:
		p.health.heal(roundi(p.health.max_health * pick.potion_heal * (1.5 if Crafts.hero_job(p) == "alchimiste" else 1.0)))
	if p.skill:
		for k in pick.potion_buff:
			p.skill.buffs[k] = [float(pick.potion_buff[k]), pick.potion_time]
	p.refresh_stats()
	Sound.play("potion", Vector3.INF, 0.0)
	VoxelBurst.spawn(p, p.global_position + Vector3(0, 1.2, 0), Color(0.9, 0.3, 0.4) if pick.potion_heal > 0.0 else Color(0.5, 0.8, 1.0), 20, 2.5, 0.07, 0.6, "up", -2.0, false)
	p.notify.emit("Tu bois : %s." % pick.display_name)
	return pick


## Mange la nourriture du sac la mieux adaptée à sa faim. Renvoie l'objet mangé (null sinon).
func eat(item: ItemData = null) -> ItemData:
	if item == null:
		var need := Player.HUNGER_MAX - p.hunger
		var best: ItemData = null
		var smallest: ItemData = null
		for e in p.inventory.entries:
			var it := e.item as ItemData
			if it == null or not it.is_food():
				continue
			if smallest == null or it.food < smallest.food:
				smallest = it
			# le plus nourrissant qui ne gaspille pas trop
			if it.food <= need + 10.0 and (best == null or it.food > best.food):
				best = it
		item = best if best else smallest
	if item == null:
		p.notify.emit("Tu n'as rien à manger. Cueille des baies (buissons) ou chasse des animaux.")
		return null
	if p.hunger >= Player.HUNGER_MAX - 2.0:
		p.notify.emit("Tu n'as pas faim.")
		return null
	if not p.inventory.remove(item, 1):
		return null
	var cook := 1.4 if Crafts.hero_job(p) == "cuisinier" else 1.0
	p.hunger = minf(Player.HUNGER_MAX, p.hunger + item.food * cook)
	if item.food_heal > 0:
		p.health.heal(roundi(item.food_heal * (1.5 if cook > 1.0 else 1.0)))
	Sound.play("eat", Vector3.INF, -2.0)
	VoxelBurst.spawn(p, p.global_position + Vector3(0, 1.4, 0) + p.facing * 0.3, Color(0.9, 0.6, 0.3), 8, 1.6, 0.05, 0.3, "up", 4.0, false)
	p.notify.emit("Tu manges : %s." % item.display_name)
	on_state_changed()
	p.hunger_changed.emit(p.hunger)
	p.ate.emit(item.id)
	return item

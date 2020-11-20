
/datum/action/item_action/enter_overwatch
	name = "Enter Overwatch"
	desc = "Set up a field of fire where you're facing, and fire on the first valid target that enters your view there."

/datum/component/overwatch
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// The gun we're using and will shoot with for the overwatch
	var/obj/item/gun/weapon
	/// Are we committed to firing? If so, ignore everything else
	var/point_of_no_return = FALSE
	/// The turfs we're watching for movement
	var/list/watched_turfs
	/// How deep our field of fire goes in the direction we're facing
	var/cone_levels = 5
	/// What mode we're using to decide whether to shoot at a given target. Defaults to only shooting at assistants.
	var/trigger_mode = OVERWATCH_FIRE_ASSISTANTS

/datum/component/overwatch/Initialize(obj/item/gun/wep, mode = OVERWATCH_FIRE_ASSISTANTS)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

	var/mob/living/shooter = parent
	weapon = wep
	trigger_mode = mode

	// attacking on enemy actions requires Covering Fire
	//RegisterSignal(targ, list(COMSIG_MOB_ATTACK_HAND, COMSIG_MOB_ITEM_ATTACK, COMSIG_MOVABLE_MOVED, COMSIG_MOB_FIRED_GUN), .proc/trigger_reaction)
	RegisterSignal(weapon, list(COMSIG_ITEM_DROPPED, COMSIG_ITEM_EQUIPPED), .proc/cancel)

	var/list/lines = list("Overwatch, aye aye.", "On overwatch.", "I’ve got my eyes on.", "Scanning.")
	shooter.say(pick(lines))
	playsound(get_turf(shooter), 'sound/weapons/gun/general/chunkyrack.ogg')

	watched_turfs = cone_helper(get_turf(shooter), shooter.dir, cone_levels = 5)
	for(var/turf/T in watched_turfs)
		RegisterSignal(T, COMSIG_ATOM_ENTERED, .proc/check_trigger)

/datum/component/overwatch/Destroy(force, silent)
	var/mob/living/shooter = parent
	if(istype(shooter) && !point_of_no_return)
		to_chat(shooter, "<span class='notice'>You are no longer on overwatch.</span>")
	return ..()

/datum/component/overwatch/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, .proc/check_cancel)
	RegisterSignal(parent, COMSIG_MOB_APPLY_DAMGE, .proc/check_flinch)

/datum/component/overwatch/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_APPLY_DAMGE))
	return ..()

/// Someone has entered our called area, see if they meet the criteria according to our trigger_mode
/datum/component/overwatch/proc/check_trigger(turf/entered_turf, atom/movable/potential_target, oldLoc)
	SIGNAL_HANDLER

	var/mob/living/shooter = parent
	if(potential_target.invisibility > shooter.see_invisible || shooter == potential_target || !can_see(shooter, entered_turf))
		return FALSE

	switch(trigger_mode)
		// shoot at literally anything that moves
		if(OVERWATCH_FIRE_ANYTHING)

		// only try shooting if it's a mob
		if(OVERWATCH_FIRE_MOBS)
			if(!ismob(potential_target))
				return FALSE

		// only try shooting if beepsky would arrest them
		if(OVERWATCH_FIRE_SECHUD)
			if(!iscarbon(potential_target))
				return FALSE
			var/mob/living/carbon/carbon_target = potential_target
			var/check_flags = (JUDGE_RECORDCHECK | JUDGE_IDCHECK | JUDGE_WEAPONCHECK)
			var/threatlevel = carbon_target.assess_threat(check_flags, weaponcheck=CALLBACK(src, .proc/check_for_weapons))
			if(threatlevel < 4)
				return FALSE

		// only try shooting if they're an assistant
		if(OVERWATCH_FIRE_ASSISTANTS)
			if(!ishuman(potential_target))
				return FALSE
			var/mob/living/carbon/human/human_target = potential_target
			var/obj/item/card/id/visible_id = human_target.wear_id?.GetID()
			if(!((visible_id?.assignment == "Assistant") || (human_target.mind?.assigned_role == "Assistant"))) // you can't hide your true colors
				return FALSE

	INVOKE_ASYNC(src, .proc/trigger_reaction, potential_target)

/// For actually trying to shoot at the target
/datum/component/overwatch/proc/trigger_reaction(atom/movable/target)
	point_of_no_return = TRUE
	var/mob/living/shooter = parent
	if(weapon.check_botched(shooter))
		return

	if(isliving(target))
		var/mob/living/living_target = target
		living_target.Immobilize(0.1 SECONDS) // slight immobilize so you have a better chance to hit a running target
	weapon.process_fire(target, shooter)
	qdel(src)

/// Stolen from secbots or whatever, for seeing if a given item is illegal without a permit
/datum/component/overwatch/proc/check_for_weapons(obj/item/slot_item)
	return(slot_item && (slot_item.item_flags & NEEDS_PERMIT))

/datum/component/overwatch/proc/check_cancel(mob/living/shooter)
	SIGNAL_HANDLER
	qdel(src)

/datum/component/overwatch/proc/check_flinch(attacker, damage, damagetype, def_zone)
	SIGNAL_HANDLER
	qdel(src)

///This proc adjusts the cones width depending on the level.
/datum/component/overwatch/proc/calculate_cone_shape(current_level)
	var/end_taper_start = round(cone_levels * 0.8)
	if(current_level > end_taper_start)
		return (current_level % end_taper_start) * 2 //someone more talented and probably come up with a better formula.
	else
		return 2

///This proc creates a list of turfs that are hit by the cone
/datum/component/overwatch/proc/cone_helper(turf/starter_turf, dir_to_use, cone_levels = 3)
	var/list/turfs_to_return = list()
	var/turf/turf_to_use = starter_turf
	var/turf/left_turf
	var/turf/right_turf
	var/right_dir
	var/left_dir
	switch(dir_to_use)
		if(NORTH)
			left_dir = WEST
			right_dir = EAST
		if(SOUTH)
			left_dir = EAST
			right_dir = WEST
		if(EAST)
			left_dir = NORTH
			right_dir = SOUTH
		if(WEST)
			left_dir = SOUTH
			right_dir = NORTH


	for(var/i in 1 to cone_levels)
		var/list/level_turfs = list()
		turf_to_use = get_step(turf_to_use, dir_to_use)
		level_turfs += turf_to_use
		if(i != 1)
			left_turf = get_step(turf_to_use, left_dir)
			level_turfs += left_turf
			right_turf = get_step(turf_to_use, right_dir)
			level_turfs += right_turf
			for(var/left_i in 1 to i -calculate_cone_shape(i))
				left_turf = get_step(left_turf, left_dir)
				level_turfs += left_turf
			for(var/right_i in 1 to i -calculate_cone_shape(i))
				right_turf = get_step(right_turf, right_dir)
				level_turfs += right_turf
		turfs_to_return += level_turfs // remove levels
		if(i == cone_levels)
			continue
	return turfs_to_return

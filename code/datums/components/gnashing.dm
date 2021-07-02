/datum/component/gnashing

	/// The interval we perform attacks in
	var/gnash_start_delay = 2 SECONDS
	/// The interval we perform attacks in
	var/gnash_attack_interval = 0.75 SECONDS
	/// The interval we perform attacks in
	var/gnash_attack_interval_delta = 0.1 SECONDS
	var/gnash_attack_interval_min = 0.1 SECONDS
	/// How much we multiple the normal damage by per gnash
	var/gnash_damage_multiplier = 0.75

	var/gnash_iteration = 0

	var/gnash_wound_bonus_growth = 5

	var/currently_gnashing = FALSE



/datum/component/gnashing/Initialize(_gnash_start_delay = 2 SECONDS, _gnash_attack_interval = 0.75 SECONDS)
	if(!isitem(parent))
		stack_trace("Kneecapping element added to non-item object: \[[parent]\]")
		return COMPONENT_INCOMPATIBLE

	gnash_start_delay = _gnash_start_delay
	gnash_attack_interval = _gnash_attack_interval

	RegisterSignal(parent, COMSIG_ITEM_ATTACK_SECONDARY , .proc/try_start_gnashing)
	RegisterSignal(parent, COMSIG_ITEM_ATTACK , .proc/check_block_attack)
	RegisterSignal(parent, COMSIG_ITEM_ATTACK_SELF , .proc/check_stop_gnashing)

/datum/component/gnashing/Destroy(force, silent)
	UnregisterSignal(parent, list(COMSIG_ITEM_ATTACK_SECONDARY, COMSIG_ITEM_ATTACK_SELF))

	return ..()

/**
 * Signal handler for COMSIG_ITEM_ATTACK_SECONDARY. Does checks for pacifism, zones and target state before either returning nothing
 * if the special attack could not be attempted, performing the ordinary attack procs instead - Or cancelling the attack chain if
 * the attack can be started.
 */
/datum/component/gnashing/proc/check_block_attack(obj/item/source, mob/living/carbon/target, mob/living/attacker, params)
	SIGNAL_HANDLER

	if(currently_gnashing)
		return COMPONENT_CANCEL_ATTACK_CHAIN
/**
 * Signal handler for COMSIG_ITEM_ATTACK_SECONDARY. Does checks for pacifism, zones and target state before either returning nothing
 * if the special attack could not be attempted, performing the ordinary attack procs instead - Or cancelling the attack chain if
 * the attack can be started.
 */
/datum/component/gnashing/proc/try_start_gnashing(obj/item/source, mob/living/carbon/target, mob/living/attacker, params)
	SIGNAL_HANDLER

	if(currently_gnashing)
		return

	if(HAS_TRAIT(attacker, TRAIT_PACIFISM))
		return

	if(!iscarbon(target))
		return

	//if(!target.buckled && !HAS_TRAIT(target, TRAIT_FLOORED) && !HAS_TRAIT(target, TRAIT_IMMOBILIZED))
		//return

	var/obj/item/bodypart/targeted_part = target.get_bodypart(attacker.zone_selected)

	if(!targeted_part)
		return

	. = COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN

	INVOKE_ASYNC(src, .proc/start_gnashing, source, targeted_part, target, attacker)

/**
 * After a short do_mob, attacker applies damage to the given leg with a significant wounding bonus, applying the weapon's force as damage.
 */
/datum/component/gnashing/proc/start_gnashing(obj/item/weapon, obj/item/bodypart/targeted_part, mob/living/carbon/target, mob/living/attacker)
	if(LAZYACCESS(attacker.do_afters, weapon))
		return

	gnash_iteration = 0
	currently_gnashing = TRUE
	attacker.Immobilize(gnash_start_delay)
	attacker.visible_message(span_warning("[attacker] revs up [attacker.p_their()] [weapon.name], closing in to press it to [target]'s [targeted_part.name]!"), span_danger("You rev up your [weapon.name], closing in to press it to [target]'s [targeted_part.name]!"))
	log_combat(attacker, target, "started a gnashing attack with", weapon)

	if(do_mob(attacker, target, gnash_start_delay, interaction_key = weapon))
		INVOKE_ASYNC(src, .proc/gnash_loop, weapon, targeted_part, target, attacker)
		return
	else
		end_gnashing()

/**
 * After a short do_mob, attacker applies damage to the given leg with a significant wounding bonus, applying the weapon's force as damage.
 */
/datum/component/gnashing/proc/gnash_loop(obj/item/weapon, obj/item/bodypart/targeted_part, mob/living/carbon/target, mob/living/attacker)
	if(!currently_gnashing || !istype(targeted_part) || !istype(target) || !(targeted_part in target.bodyparts))
		end_gnashing()
		return

	attacker.Immobilize(gnash_attack_interval)

	attacker.visible_message(span_warning("[attacker] continues pressing [attacker.p_their()] [weapon] wildly into [target]'s [targeted_part.name]!"), span_danger("You continue pressing your [weapon.name] into [target]'s [targeted_part.name]!"))
	log_combat(attacker, target, "continued gnashing", weapon)
	target.update_damage_overlays()
	attacker.do_attack_animation(target, used_item = weapon)
	playsound(source = get_turf(weapon), soundin = weapon.hitsound, vol = weapon.get_clamped_volume(), vary = TRUE)

	var/damage_dealt = weapon.force * gnash_damage_multiplier
	var/wound_bonus_dealt = weapon.wound_bonus + (gnash_wound_bonus_growth * gnash_iteration)
	var/bare_wound_bonus_dealt = weapon.bare_wound_bonus
	var/delay = max(gnash_attack_interval - (gnash_iteration * gnash_attack_interval_delta), gnash_attack_interval_min)

	targeted_part.receive_damage(brute = damage_dealt, wound_bonus = wound_bonus_dealt, bare_wound_bonus = bare_wound_bonus_dealt)
	gnash_iteration++
	//weapon.attack(target, attacker)


	if(do_mob(attacker, target, delay, interaction_key = weapon, progress = FALSE))
		INVOKE_ASYNC(src, .proc/gnash_loop, weapon, targeted_part, target, attacker)
		return
	else
		end_gnashing()

/datum/component/gnashing/proc/end_gnashing(obj/item/weapon, obj/item/bodypart/targeted_part, mob/living/carbon/target, mob/living/attacker)
	currently_gnashing = FALSE

/datum/component/gnashing/proc/check_stop_gnashing(obj/item/weapon, mob/living/attacker)
	SIGNAL_HANDLER

	if(!currently_gnashing || !istype(weapon) || !istype(attacker))
		return

	attacker.visible_message(span_warning("[attacker] ceases pressing [attacker.p_their()] [weapon]!"), span_danger("You cease pressing your [weapon.name]."))
	end_gnashing()

	return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/wound/stubbed_toe
	name = "Stubbed Toe"
	desc = "Patient's hallux has suffered a serious contusion, characterized by abject rupturing of multiple subdermal blood vessels, likely as a result of extreme diligence in operating company equipment to request station's imminient evacuation."
	treat_text = "Application of sudden, sharp percussive force to the patient's buccalar region may reset said patient's assessment of the severity of the situation, therefore fortifying their resilience."
	examine_desc = "is very slightly bruised on the big toe"
	occur_text = "is suddenly stubbed against the command console, stubbing its big toe"
	sound_effect = 'sound/effects/wounds/crack1.ogg'
	severity = WOUND_SEVERITY_TRIVIAL
	limp_slowdown = 2
	limp_chance = 5
	status_effect_type = /datum/status_effect/wound/special/stubbed_toe
	scar_keyword = "stubbedtoe"

/datum/wound/stubbed_toe/apply_wound(obj/item/bodypart/L, silent, datum/wound/old_wound, smited)
	. = ..()
	if(QDELING(src))
		return

	RegisterSignal(victim, COMSIG_PARENT_ATTACKBY, .proc/check_slap)

/datum/wound/stubbed_toe/remove_wound(ignore_limb, replaced)
	UnregisterSignal(victim, COMSIG_PARENT_ATTACKBY)
	return ..()

/datum/wound/stubbed_toe/proc/check_slap(datum/source, obj/item/attacking_item, user, params)
	SIGNAL_HANDLER

	if(!istype(attacking_item, /obj/item/slapper) || user.zone_selected != BODY_ZONE_PRECISE_MOUTH)
		return

	victim.visible_message(span_danger("[victim] looks on in shock at [user]'s slap, quickly sobering up and forgetting about their stubbed toe!"),
		span_userdanger("You look on in shock at [user]'s slap against you, then remember that you have much bigger problems than your stubbed toe, freeing you of your ailment!"), vision_distance = COMBAT_MESSAGE_RANGE)
	remove_wound(src)

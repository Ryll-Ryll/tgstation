/datum/wound/neck
	sound_effect = 'sound/effects/wounds/crack2.ogg'
	wound_type = WOUND_BLUNT
	wound_flags = (BONE_WOUND)
	var/datum/brain_trauma/wound_trauma


/datum/wound/neck/moderate
	name = "Spinal Spasms"
	desc = "Patient's spinal column has become jilted in a spectacular fashion, causing occasional spasms, weakness, and nausea."
	treat_text = "Surgical ."
	examine_desc = "appears badly bruised and swollen around the back of the neck, trailing downward"
	occur_text = "janks badly, accompanied by flecks of spit and blood"

/datum/wound/neck/severe
	name = "Thoracic Sheering"
	desc = "Patient has suffered extreme trauma to lower spinal column, causing paralysis of the legs."
	treat_text = "Surgical ."
	examine_desc = "appears to connect poorly to the rest of the lower body, with a strange bend in the spine"
	occur_text = "emits a sharp crunch from the lower spine"

/datum/wound/neck/critical
	name = "Aborted Cervix"
	desc = "Patient's spinal column has been violently severed at the neck, causing total paralysis or instant death."
	treat_text = "Surgical reconstruction of cervical spinal connections."
	examine_desc = "flops limply in a way no head ever should"
	occur_text = "splinters apart at the neck, shreds of spinal bone and fluid flying out"

/datum/wound/neck/wound_injury(datum/wound/old_wound)
	. = ..()
	if(!victim || !limb)
		return

	for(var/i in 1 to severity)
		playsound(victim, 'sound/effects/wounds/crack2.ogg', 80, FALSE, -3)

/datum/wound/neck/critical/wound_injury(datum/wound/old_wound)
	. = ..()
	if(!victim || !limb)
		return

	limb.receive_damage(300, wound_bonus=CANT_WOUND)
	wound_trauma = victim.gain_trauma_type(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_WOUND)

/datum/wound/neck/process()
	. = ..()

/datum/wound/neck/proc/promote()
	switch(severity)
		if(WOUND_SEVERITY_MODERATE)
			replace_wound(/datum/wound/neck/severe)
		if(WOUND_SEVERITY_SEVERE)
			replace_wound(/datum/wound/neck/critical)

/datum/wound/neck/critical/remove_wound(ignore_limb, replaced)
	QDEL_NULL(wound_trauma)
	. = ..()

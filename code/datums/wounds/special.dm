/datum/wound/neck
	sound_effect = 'sound/effects/wounds/crack2.ogg'
	wound_type = WOUND_BLUNT
	wound_flags = (BONE_WOUND)



/datum/wound/neck/moderate
	name = "Spinal Spasms"
	desc = "Patient's spinal column has become jilted in a spectacular fashion, causing occasional spasms, weakness, and nausea."
	treat_text = "Surgical ."
	examine_desc = "appears badly bruised and swollen around the back of the neck, trailing down"
	occur_text = "cracks apart, exposing broken bones to open air"

/datum/wound/neck/severe
	name = "Thoracic Sheering"
	desc = "Patient has suffered extreme trauma to lower spinal column, causing paralysis of the legs."
	treat_text = "Surgical ."
	examine_desc = "appears to connect poorly to the rest of the lower body, "
	occur_text = "cracks apart, exposing broken bones to open air"

/datum/wound/neck/critical
	name = "Aborted Cervix"
	desc = "Patient's spinal column has been violently severed at the neck, causing total paralysis or instant death."
	treat_text = "Surgical reconstruction of cervical spinal connections."
	examine_desc = "flops limply in a way no head ever should"
	occur_text = "splinters apart at the neck, shreds of spinal bone and fluid flying out"

/datum/wound/neck/wound_injury(datum/wound/old_wound)
	. = ..()
	if(!victim)
		return

	limb.receive_damage(300, wound_bonus=CANT_WOUND)

/datum/wound/neck/process()
	. = ..()
	limb.receive_damage(300, wound_bonus=CANT_WOUND)

#define CAN_STEP(cur_turf, next) (next && !next.density)

/// Will be replaced by a list(turf, jumps) tuple
/datum/bfs_node
	/// The turf this represents
	var/turf/tile
	/// How many steps it took to get here
	var/jumps

/datum/bfs_node/New(turf/our_tile, jumps_taken)
	. = ..()
	tile = our_tile
	jumps = jumps_taken


/proc/HeapStepsCompare(datum/bfs_node/a, datum/bfs_node/b)
	return b.jumps - a.jumps

/**
 * Uses BFS to find all reachable tiles within max_range cardinal steps. To be replaced with a more efficient solution that doesn't create nodes for each tile
 *
 * Arguments:
 * * starting - The turf you're starting from
 * * max_range - Take this many cardinal steps at most
 * * min_range - Optional- if set, only return the list of turfs that took at least this many steps to reach
 * * visualize - Debug tool, to be removed before merging
 */
/proc/get_turfs_bfs(turf/starting, max_range = 12, min_range, visualize)
	if(!istype(starting) || max_range < 1)
		return

	var/datum/bfs_node/starting_node = new(starting, 0)
	var/datum/bfs_node/current

	var/datum/heap/open = new /datum/heap(/proc/HeapStepsCompare)
	open.insert(starting_node)
	var/list/closed = list()

	var/list/final_band
	if(min_range)
		final_band = list()

	while(!open.is_empty())
		current = open.pop()
		var/turf/current_turf = current.tile
		var/current_jumps = current.jumps
		closed[current_turf] = current_jumps
		if(min_range && current_jumps >= min_range)
			final_band[current_turf] = current_jumps

		if(current_jumps >= max_range)
			continue

/*
		for(var/scan_direction in list(EAST, WEST, NORTH, SOUTH))
			var/turf/check_turf = current_turf
			var/turf/check_turf_next

			var/next_jumps = current_jumps

			for(var/iter_jumps in 1 to (max_range - current_jumps))
				check_turf_next = get_step(check_turf, scan_direction)
				next_jumps++
				closed[check_turf] = next_jumps
				if(!CAN_STEP(check_turf, check_turf_next) || (closed[check_turf_next] <= next_jumps))
					break
				var/datum/bfs_node/new_node = new(check_turf, next_jumps)
				open.insert(new_node)
				check_turf = check_turf_next
*/
		// check adj turfs
		for(var/turf/iter_turf in get_adjacent_open_turfs(current_turf))
			if(closed[iter_turf] || !CAN_STEP(current_turf, iter_turf))
				continue
			var/datum/bfs_node/new_node = new(iter_turf, current_jumps + 1)
			open.insert(new_node)

		// finished checking adjacent turfs


	if(visualize)
		for(var/turf/final_turfs in closed)
			var/final_jumps = closed[final_turfs]
			var/color_digit = min(final_jumps, 9)
			switch(visualize)
				if(1)
					final_turfs.color = "#[color_digit][color_digit]0000"
				if(2)
					final_turfs.color = "#00[color_digit][color_digit]00"
				if(3)
					final_turfs.color = "#0000[color_digit][color_digit]"
			if(visualize)
				final_turfs.maptext = "[final_jumps]"

	if(min_range)
		return final_band
	else
		return closed


/obj/item/toy/bfs_test
	name = "foam armblade"
	desc = "It says \"Sternside Changs #1 fan\" on it."
	icon = 'icons/obj/toys/toy.dmi'
	icon_state = "foamblade"
	inhand_icon_state = "arm_blade"
	lefthand_file = 'icons/mob/inhands/antag/changeling_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/changeling_righthand.dmi'
	attack_verb_continuous = list("pricks", "absorbs", "gores")
	attack_verb_simple = list("prick", "absorb", "gore")
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FLAMMABLE

	var/our_range = 7

	var/visualize = FALSE

	var/vis_color = 1

/obj/item/toy/bfs_test/attack_self(mob/user, modifiers)
	our_range = input("What new range?", "New range") as null|num

/obj/item/toy/bfs_test/attack_self_secondary(mob/user, modifiers)
	. = ..()
	visualize = input("Visualize?", "Vis") as null|num

/obj/item/toy/bfs_test/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(visualize)
		visualize = ((visualize + 1) % 3) + 1
	var/turf/target_turf = get_turf(target)
	get_turfs_bfs(target_turf, our_range, visualize)

#undef CAN_STEP

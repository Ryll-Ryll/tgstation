/// stripped down copy of the path.dm one for expediency
#define CAN_STEP(cur_turf, next) (next && !next.density)
/// in the 2 item lists for storing nodes, this represents the turf
#define BFS_TILE 1
/// in the 2 item lists for storing nodes, this represents the number of jumps it took to get here
#define BFS_JUMPS 2

/proc/HeapStepsCompare(list/a, list/b)
	return b[BFS_JUMPS] - a[BFS_JUMPS]

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

	var/list/starting_tile = list(starting, 0)
	var/list/current_tile

	var/list/open = list()
	open += list(starting_tile)
	var/list/closed = list()

	var/list/final_band
	if(min_range)
		final_band = list()

	while(open.len)
		current_tile = open[1]
		open.Cut(1,2)
		var/turf/current_turf = current_tile[BFS_TILE]
		var/current_jumps = current_tile[BFS_JUMPS]
		closed[current_turf] = current_jumps
		if(min_range && current_jumps >= min_range)
			final_band[current_turf] = current_jumps

		if(current_jumps >= max_range)
			continue

		// check adj turfs
		for(var/turf/iter_turf in get_adjacent_open_turfs(current_turf))
			if(closed[iter_turf] || !CAN_STEP(current_turf, iter_turf))
				continue
			open += list(list(iter_turf, current_jumps + 1))
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

	to_chat(world, "Closed len: [closed.len]")

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
	/// how big an area to show
	var/our_range = 7
	/// cycles to show colors
	var/visualize = 1


/obj/item/toy/bfs_test/attack_self(mob/user, modifiers)
	our_range = input("What new range?", "New range") as null|num

/obj/item/toy/bfs_test/attack_self_secondary(mob/user, modifiers)
	. = ..()
	visualize = input("Visualize?", "Vis") as null|num

/obj/item/toy/bfs_test/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	to_chat(world, "go")
	if(visualize)
		visualize = ((visualize + 1) % 3) + 1
	var/turf/target_turf = get_turf(target)
	get_turfs_bfs(target_turf, our_range, 0, visualize)

#undef CAN_STEP
#undef BFS_TILE
#undef BFS_STEPS

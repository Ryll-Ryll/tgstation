/// An individual microblog post (called a Shard)
/datum/blag
	/// The ckey associated with this
	var/owner_ckey

	/// The character name associated with this (or maybe the character's username? dna fingerprint? pref fingerprint???)
	var/owner_charname

	/// The actual message (text only, attachments will come later as another var)
	var/message_text

	/// When it was submitted
	var/sub_datetime

	/// The server it was submitted from
	var/sub_server

	/// If FALSE, this has been submitted this round and lacks a sql_id because we haven't submitted it to the sql server yet
	var/saved

	/// The ID for this blag associated with the sql (asdaod)
	var/sql_id

	var/local_id = 0

/datum/blag/New(mob/user, message)
	if(!user?.ckey)
		qdel(src)
		return

	owner_ckey = user.ckey
	owner_charname = user.real_name
	message_text = message
	sub_datetime = world.time // figure out what Now() returns in sql

/datum/blag/proc/get_db_row()
	return list(
		"author_ckey" = owner_ckey,
		"author_charname" = owner_charname,
		"message_text" = message_text,
		"submit_datetime" = "NOW()",
		"source_server" = world.url
	)


/datum/blag/proc/recreate(list/row)
	sql_id = text2num(row[1])
	owner_ckey = row[2]
	owner_charname = row[3]
	message_text = row[4]
	sub_datetime = row[5]
	sub_server = row[6]

	saved = TRUE
	return TRUE

/// This is the actual "microblog server" in that it handles all the in round saving and retrieving microblog posts.
/datum/microblag_server
	/// A list with all the microblog posts that people can look from
	var/list/blags
	/// Basically how many posts have been made on this server this round, kinda redundant
	var/local_id = 0
	/// To be set when the posts are loaded from sql, so we can start showing local ID's after these
	var/existing_sql_offset

/// Add a blag datum to the party
/datum/microblag_server/proc/submit_blag(datum/blag/new_blag)
	LAZYADD(blags, new_blag)
	local_id++
	new_blag.local_id = local_id

/// Run an SQL query to load all the DB posts
/datum/microblag_server/proc/load_server(datum/blag/new_blag)
	testing("TRYING TO LOAD BLAGS")
	if(!SSdbcore.Connect())
		return -1
	var/datum/db_query/load_the_blags = SSdbcore.NewQuery(
		"SELECT id, author_ckey, author_charname, message_text, submit_datetime, source_server FROM [format_table_name("blags")]"
	)
	if(!load_the_blags.Execute(async = TRUE))
		qdel(load_the_blags)
		return -1

	var/list/loading_blags = list()
	while(load_the_blags.NextRow())
		testing("starting load either [json_encode(load_the_blags.item)] or [json_encode(load_the_blags.item[1])]")
		loading_blags += list(load_the_blags.item)
		var/datum/blag/loaded_blag = new
		loaded_blag.recreate(load_the_blags.item)
		LAZYADD(blags, loaded_blag)
		testing("loaded blag [json_encode(loaded_blag)] | [json_encode(list(load_the_blags.item))]")
	testing("Loaded [length(loading_blags)] blags")
	qdel(load_the_blags)

/// Saving all of the new collected blag posts to the SQL DB
/datum/microblag_server/proc/save_server(datum/blag/new_blag)
	testing("Trying to save blags! Length of blags: [LAZYLEN(blags)]")
	if(!SSdbcore.Connect())
		return

	/*var/list/inserting_rows = list()
	for(var/datum/blag/iter_blag as anything in blags)
		if(isnull(iter_blag) || iter_blag.saved)
			testing("skip!")
			continue
		var/list/inner_list = list(iter_blag.get_db_row())
		testing("Iter save blag, either [json_encode(iter_blag.get_db_row())] or [json_encode(list(iter_blag.get_db_row()))]")
		inserting_rows += inner_list
		iter_blag.saved = TRUE // maybe check if it's successful actually
*/
	var/special_columns = list(
		"submit_datetime" = "NOW()",
	)
	var/list/sqlrowlist = list()
	for(var/datum/blag/iter_blag in blags)
		if(isnull(iter_blag) || iter_blag.saved)
			testing("skip!")
			continue
		sqlrowlist += list(list(
			"author_ckey" = iter_blag.owner_ckey,
			"author_charname" = iter_blag.owner_charname,
			"message_text" = iter_blag.message_text,
			"source_server" = world.url
		))
	testing("Blags to save: [length(sqlrowlist)]")
	//SSdbcore.MassInsert(format_table_name("blags"), inserting_rows)
	SSdbcore.MassInsert(format_table_name("blags"), sqlrowlist, special_columns=special_columns)

/// Get the blag datums we want for a given page
/datum/microblag_server/proc/get_blags(desired_page = 1, page_size = 5)
	if(!LAZYLEN(blags))
		return list()

	var/num_pages = CEILING(LAZYLEN(blags) / page_size, 1)
	var/access_page_index = min(desired_page, num_pages)
	var/start_index = (access_page_index - 1) * page_size + 1
	var/end_index = min(access_page_index * page_size, LAZYLEN(blags))

	var/list/ret = list()
	for(var/bi = start_index; bi <= end_index; bi++)
		var/datum/blag/iter_blag = blags[bi]
		ret += iter_blag

	return ret

/// Helper for outside to see how many pages of blag posts we have
/datum/microblag_server/proc/get_num_pages(page_size = 5)
	return CEILING(LAZYLEN(blags) / page_size, 1)

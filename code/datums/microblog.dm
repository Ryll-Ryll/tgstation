#define BLOG_USERNAME_MAX_LENGTH 10


/// An individual microblog post (called a Shard)
/datum/blog_post
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

	/// The ID for this post associated with the sql (asdaod)
	var/sql_id

	var/local_id = 0

/datum/blog_post/New(mob/user, message)
	owner_ckey = user.ckey
	owner_charname = user.real_name
	message_text = message
	sub_datetime = world.time // figure out what Now() returns in sql

/datum/blog_post/Destroy(force, ...)
	LAZYREMOVE(GLOB.microblog_server.blog_posts, src)
	return ..()


/datum/blog_post/proc/get_db_row()
	return list(
		"author_ckey" = owner_ckey,
		"author_charname" = owner_charname,
		"message_text" = message_text,
		"submit_datetime" = "NOW()",
		"source_server" = world.url
	)


/datum/blog_post/proc/recreate(list/row)
	sql_id = text2num(row[1])
	local_id = sql_id
	owner_ckey = row[2]
	owner_charname = row[3]
	message_text = row[4]
	sub_datetime = row[5]
	sub_server = row[6]

	saved = TRUE
	return TRUE

/// This is the actual "microblog server" in that it handles all the in round saving and retrieving microblog posts.
/datum/microblog_server
	/// A list with all the microblog posts that people can look from
	var/list/blog_posts
	/// Basically how many posts have been made on this server this round, kinda redundant
	var/local_id = 0
	/// To be set when the posts are loaded from sql, so we can start showing local ID's after these
	var/existing_sql_offset

	var/list/usernames_by_ckey = list()

/datum/microblog_server/proc/get_username(target_ckey)
	if(!target_ckey)
		stack_trace("ERROR: Tried getting ckey for post username of invalid target. Target value: [target_ckey]")
		return

	if(usernames_by_ckey[target_ckey])
		return usernames_by_ckey[target_ckey]

	var/datum/db_query/fetch_username = SSdbcore.NewQuery(
		"SELECT username FROM [format_table_name("blog_accounts")] WHERE ckey = '[target_ckey]' LIMIT 1"
	)
	if(!fetch_username.Execute())
		qdel(fetch_username)
		return

	testing("result from get: [json_encode(fetch_username.item)]")
	var/result = fetch_username.item
	if(result)
		usernames_by_ckey[target_ckey] = result
		return result

	return create_user(target_ckey)

/datum/microblog_server/proc/create_user(target_ckey)
	var/default_username = strip_html(target_ckey, BLOG_USERNAME_MAX_LENGTH)
	var/mob/living/possible_target_mob = get_mob_by_ckey(target_ckey)
	if(istype(possible_target_mob))
		var/list/name_split = splittext(possible_target_mob.real_name, " ")
		if(length(name_split) >= 2)
			default_username = "[name_split[1][1]][name_split[2]]" //flast
		else
			default_username = name_split[1]

	if(!default_username)
		CRASH("fc")

	testing("Trying to create user with name [default_username]")
	var/datum/db_query/insert_user = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("blog_accounts")] (ckey, username, registered_datetime) VALUES (:ckey, :username, :datetime)",\
		list("ckey" = target_ckey, "username" = default_username, "datetime" = SQLtime())
	)
	if(!insert_user.Execute())
		qdel(insert_user)
		return

	usernames_by_ckey[target_ckey] = default_username
	qdel(insert_user)
	return TRUE

/datum/microblog_server/proc/update_username(target_ckey, new_username)
	if(!new_username)
		new_username = target_ckey
	new_username = strip_html(new_username, BLOG_USERNAME_MAX_LENGTH)

	var/datum/db_query/update_username = SSdbcore.NewQuery(
		"UPDATE [format_table_name("blog_accounts")] SET username = '[new_username]` WHERE ckey = '[target_ckey]'"
	)
	if(!update_username.Execute())
		qdel(update_username)
		return

	usernames_by_ckey[target_ckey] = new_username
	qdel(update_username)
	return TRUE

/// Add a blog post datum to the party
/datum/microblog_server/proc/submit_blog_post(datum/blog_post/new_blog_post)
	LAZYADD(blog_posts, new_blog_post)
	local_id++
	new_blog_post.local_id = local_id
	if(!usernames_by_ckey[new_blog_post.owner_ckey])
		get_username(new_blog_post.owner_ckey)

/// Run an SQL query to load all the DB posts
/datum/microblog_server/proc/load_server(datum/blog_post/new_blog_post)
	testing("TRYING TO LOAD BLOG POSTS")
	if(!SSdbcore.Connect())
		return -1
	var/datum/db_query/load_blog_posts = SSdbcore.NewQuery(
		"SELECT id, author_ckey, author_charname, message_text, submit_datetime, source_server FROM [format_table_name("blog_posts")]"
	)
	if(!load_blog_posts.Execute(async = TRUE))
		qdel(load_blog_posts)
		return -1

	var/count

	while(load_blog_posts.NextRow())
		testing("starting load either [json_encode(load_blog_posts.item)] or [json_encode(load_blog_posts.item[1])]")
		var/datum/blog_post/loaded_blog_post = new
		loaded_blog_post.recreate(load_blog_posts.item)
		submit_blog_post(loaded_blog_post)
		count++
		testing("loaded blog post: [json_encode(loaded_blog_post)] | [json_encode(list(load_blog_posts.item))]")
	testing("Loaded [count] blog_posts")
	qdel(load_blog_posts)

/// Saving all of the new collected blog posts to the SQL DB
/datum/microblog_server/proc/save_server(datum/blog_post/new_blog_post)
	testing("Trying to save blog_posts! Length of blog_posts: [LAZYLEN(blog_posts)]")
	if(!SSdbcore.Connect())
		return

	var/special_columns = list(
		"submit_datetime" = "NOW()",
	)
	var/list/sqlrowlist = list()
	for(var/datum/blog_post/iter_blog in blog_posts)
		if(isnull(iter_blog) || iter_blog.saved)
			testing("skip!")
			continue
		sqlrowlist += list(list(
			"author_ckey" = iter_blog.owner_ckey,
			"author_charname" = iter_blog.owner_charname,
			"message_text" = iter_blog.message_text,
			"source_server" = world.url
		))
	testing("Blog posts to save: [length(sqlrowlist)]")
	SSdbcore.MassInsert(format_table_name("blog_posts"), sqlrowlist, special_columns=special_columns)

/// Get the blog post datums we want for a given page
/datum/microblog_server/proc/get_blog_posts(desired_page = 1, page_size = 5)
	if(!LAZYLEN(blog_posts))
		return list()

	var/num_pages = CEILING(LAZYLEN(blog_posts) / page_size, 1)
	var/access_page_index = min(desired_page, num_pages)
	var/start_index = (access_page_index - 1) * page_size + 1
	var/end_index = min(access_page_index * page_size, LAZYLEN(blog_posts))

	var/list/ret = list()
	for(var/bi = start_index; bi <= end_index; bi++)
		var/datum/blog_post/iter_blog_post = blog_posts[bi]
		ret += iter_blog_post

	return ret

/// Helper for outside to see how many pages of blog posts we have
/datum/microblog_server/proc/get_num_pages(page_size = 5)
	return CEILING(LAZYLEN(blog_posts) / page_size, 1)

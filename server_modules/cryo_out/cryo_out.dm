
#define CRYO_OUT_STORED 1
#define CRYO_OUT_RESTORING 2

GLOBAL_LIST_EMPTY(cryo_out_records)

/datum/cryo_out_record
	var/player_ckey
	var/mob/living/stored_mob
	var/datum/mind/stored_mind
	var/datum/job/original_job
	var/obj/machinery/cryo_out/original_bed
	var/state = CRYO_OUT_STORED
	var/job_slot_released = FALSE
	var/pod_destroyed = FALSE

/datum/cryo_out_record/New(mob/living/character, obj/machinery/cryo_out/bed, player_ckey)
	. = ..()

	src.player_ckey = ckey(player_ckey)
	stored_mob = character
	stored_mind = character.mind
	original_job = character.mind?.assigned_role
	original_bed = bed

/datum/cryo_out_record/proc/release_job_slot()
	if(job_slot_released || !original_job)
		return

	if(original_job.current_positions > 0)
		original_job.current_positions--
		job_slot_released = TRUE

/datum/cryo_out_record/proc/restore_job_slot()
	if(!job_slot_released)
		return

	if(original_job)
		original_job.current_positions++

	job_slot_released = FALSE

/proc/cryo_out_get_record(player_ckey)
	if(!player_ckey)
		return null

	return GLOB.cryo_out_records[ckey(player_ckey)]

/proc/cryo_out_store_character(mob/living/character, obj/machinery/cryo_out/bed)
	world.log << "CRYO OUT: Storage requested."

	if(QDELETED(character) || QDELETED(bed))
		return FALSE

	if(!character.client || !character.mind)
		return FALSE

	if(bed.occupant_record)
		return FALSE

	var/client/player_client = character.client
	var/player_key = character.key
	var/player_ckey = ckey(player_client.ckey)
	var/turf/original_turf = get_turf(character)

	if(!player_key || !player_ckey || !original_turf)
		return FALSE

	if(cryo_out_get_record(player_ckey))
		return FALSE

	var/datum/cryo_out_record/record = new(character, bed, player_ckey)

	if(!record.original_job)
		qdel(record)
		return FALSE

	var/mob/dead/new_player/lobby = new()

	if(QDELETED(lobby))
		qdel(record)
		return FALSE

	world.log << "CRYO OUT: Character = [character]"
	world.log << "CRYO OUT: Pod = [bed]"
	world.log << "CRYO OUT: Pod type = [bed.type]"
	world.log << "CRYO OUT: Character location before storage = [character.loc]"

	// Stop the character from dragging or remaining buckled
	// before moving it into the machine.
	character.stop_pulling()

	if(character.buckled)
		character.buckled.unbuckle_mob(character, force = TRUE)

	if(character.has_buckled_mobs())
		character.unbuckle_all_mobs(force = TRUE)

	// Move the original mob into our independent machine.
	// No new mob is created and no equipment is copied.
	var/moved = character.doMove(bed)

	world.log << "CRYO OUT: doMove returned [moved]"
	world.log << "CRYO OUT: Character location after movement = [character.loc]"
	world.log << "CRYO OUT: Inside pod = [character.loc == bed]"

	if(character.loc != bed)
		world.log << "CRYO OUT ERROR: Unable to contain character."

		if(character.loc != original_turf)
			character.doMove(original_turf)

		qdel(lobby)
		qdel(record)
		return FALSE

	// Mark the chamber occupied.
	bed.occupant_record = record
	bed.reset_cryo_visual()

	GLOB.cryo_out_records[player_ckey] = record

	// Keep the original mind associated with its original mob.
	record.stored_mind.active = FALSE

	world.log << "CRYO OUT: Transferring client to lobby."

	lobby.key = player_key

	world.log << "CRYO OUT: Client mob after transfer = [player_client.mob]"
	world.log << "CRYO OUT: Character location after transfer = [character.loc]"

	if(player_client.mob != lobby)
		world.log << "CRYO OUT ERROR: Lobby transfer failed."

		record.stored_mind.active = TRUE

		if(character.loc != original_turf)
			character.doMove(original_turf)

		bed.occupant_record = null
		bed.reset_cryo_visual()

		GLOB.cryo_out_records -= player_ckey

		qdel(lobby)
		qdel(record)
		return FALSE

	// If the client transfer moved the body, do not silently
	// accept a broken storage state.
	if(character.loc != bed)
		world.log << "CRYO OUT ERROR: Character moved during lobby transfer."

		character.key = player_key
		record.stored_mind.active = TRUE

		if(character.loc != original_turf)
			character.doMove(original_turf)

		bed.occupant_record = null
		bed.reset_cryo_visual()

		GLOB.cryo_out_records -= player_ckey

		if(player_client.mob == character)
			qdel(lobby)

		qdel(record)
		return FALSE

	record.release_job_slot()

	world.log << "CRYO OUT: Storage successful."
	world.log << "CRYO OUT: Stored mob location = [character.loc]"
	world.log << "CRYO OUT: Stored mob client = [character.client]"
	world.log << "CRYO OUT: Job slot released = [record.job_slot_released]"

	to_chat(lobby, span_notice("You have entered cryogenic sleep."))
	to_chat(lobby, span_notice("Your original body and equipment remain inside the chamber."))
	to_chat(lobby, span_notice("Use OOC > Return from Cryo to resume your character."))

	return TRUE

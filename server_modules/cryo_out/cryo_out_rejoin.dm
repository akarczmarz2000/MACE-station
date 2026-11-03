
/mob/dead/new_player/verb/resume_cryo_character()
	set name = "Return from Cryo"
	set category = "OOC"

	if(!client)
		return

	var/datum/cryo_out_record/record = cryo_out_get_record(client.ckey)

	if(!record)
		to_chat(src, span_warning("You do not have a character in cryogenic storage."))
		return

	if(record.state != CRYO_OUT_STORED)
		to_chat(src, span_warning("Your character is already being restored."))
		return

	var/choice = tgui_alert(
		src,
		"Return to your original character?",
		"Return from Cryo",
		list("Yes", "No")
	)

	if(choice != "Yes" || !client)
		return

	if(!cryo_out_restore_character(src, record))
		to_chat(src, span_warning("Unable to restore your cryogenic character."))

/proc/cryo_out_restore_character(mob/dead/new_player/lobby, datum/cryo_out_record/record)
	if(QDELETED(lobby) || !lobby.client || !record)
		return FALSE

	if(record.state != CRYO_OUT_STORED)
		return FALSE

	if(ckey(lobby.client.ckey) != record.player_ckey)
		return FALSE

	if(GLOB.cryo_out_records[record.player_ckey] != record)
		return FALSE

	var/mob/living/character = record.stored_mob
	var/datum/mind/original_mind = record.stored_mind
	var/obj/machinery/cryo_out/bed = record.original_bed

	if(QDELETED(character) || !original_mind)
		return FALSE

	if(character.mind != original_mind)
		return FALSE

	if(character.client)
		return FALSE

	// If the pod is intact, the body must still be inside it.
	if(!record.pod_destroyed)
		if(QDELETED(bed))
			return FALSE

		if(bed.occupant_record != record)
			return FALSE

		if(character.loc != bed)
			return FALSE

		var/turf/exit_turf = get_turf(bed)

		if(!exit_turf)
			return FALSE

		world.log << "CRYO OUT: Releasing character from intact pod."

		character.doMove(exit_turf)

		if(character.loc != exit_turf)
			world.log << "CRYO OUT ERROR: Unable to release stored character."
			return FALSE

	// If the pod was destroyed, leave the body exactly
	// where it currently is, including if another player
	// moved it after the chamber ruptured.
	record.state = CRYO_OUT_RESTORING

	var/client/player_client = lobby.client
	var/player_key = lobby.key

	world.log << "CRYO OUT: Restoring character [character]."
	world.log << "CRYO OUT: Pod destroyed = [record.pod_destroyed]"
	world.log << "CRYO OUT: Character location = [character.loc]"

	lobby.spawning = TRUE

	// Return the original player to the original mob.
	character.key = player_key

	if(player_client.mob != character)
		world.log << "CRYO OUT ERROR: Character transfer failed."

		lobby.spawning = FALSE

		if(player_client.mob == character)
			lobby.key = player_key

		if(!record.pod_destroyed && !QDELETED(bed))
			character.doMove(bed)

		record.state = CRYO_OUT_STORED
		return FALSE

	original_mind.active = TRUE
	original_mind.set_current(character)

	record.restore_job_slot()

	GLOB.cryo_out_records -= record.player_ckey

	if(!record.pod_destroyed && !QDELETED(bed))
		if(bed.occupant_record == record)
			bed.occupant_record = null
			bed.reset_cryo_visual()

	world.log << "CRYO OUT: Character restoration complete."
	world.log << "CRYO OUT: Character location = [character.loc]"
	world.log << "CRYO OUT: Character client = [character.client]"

	to_chat(character, span_notice("You have returned from cryogenic sleep."))

	qdel(lobby)
	qdel(record)

	return TRUE

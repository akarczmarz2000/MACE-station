
/obj/machinery/cryo_out
	name = "cryogenic sleep chamber"
	desc = "A chamber designed to preserve crew members during extended cryogenic sleep."
	icon = 'server_modules/cryo_out/icons/cryogenic.dmi'
	icon_state = "cryopod-open"
	density = TRUE
	anchored = TRUE
	max_integrity = 300

	var/busy = FALSE
	var/datum/cryo_out_record/occupant_record

/obj/machinery/cryo_out/attack_hand(mob/user, list/modifiers)
	if(occupant_record || busy)
		to_chat(user, span_warning("Cryogenic chamber is currently in use."))
		return TRUE

	if(!isliving(user))
		return TRUE

	var/mob/living/character = user

	if(!character.client || !character.mind)
		return TRUE

	if(character.stat != 0)
		to_chat(character, span_warning("You must be conscious to enter cryogenic sleep."))
		return TRUE

	if(!Adjacent(character))
		return TRUE

	if(cryo_out_get_record(character.ckey))
		to_chat(character, span_warning("You already have a character in cryogenic storage."))
		return TRUE

	busy = TRUE

	var/choice = tgui_alert(
		character,
		"Enter cryogenic sleep? Your original character will be stored in this chamber until you return.",
		"Cryogenic Sleep",
		list("Yes", "No")
	)

	if(QDELETED(src))
		return TRUE

	if(choice != "Yes")
		busy = FALSE
		return TRUE

	if(QDELETED(character) || !character.client || !character.mind)
		busy = FALSE
		return TRUE

	if(character.stat != 0 || !Adjacent(character) || occupant_record)
		busy = FALSE
		return TRUE

	world.log << "CRYO OUT: Entry confirmed for [character]."

	if(!cryo_out_store_character(character, src))
		world.log << "CRYO OUT ERROR: Storage failed for [character]."

		if(!QDELETED(character) && character.client)
			to_chat(character, span_warning("Cryogenic storage failed."))

	busy = FALSE
	return TRUE

/obj/machinery/cryo_out/proc/reset_cryo_visual()
	icon_state = occupant_record ? "cryopod" : "cryopod-open"

/obj/machinery/cryo_out/proc/release_cryo_occupant()
	var/datum/cryo_out_record/record = occupant_record

	if(!record)
		return

	var/mob/living/character = record.stored_mob
	var/turf/release_turf = get_turf(src)

	world.log << "CRYO OUT: Chamber destroyed or opened by destruction."
	world.log << "CRYO OUT: Stored character = [character]"

	// Keep the player's cryo record.
	// They must still be able to return to the original body.
	record.pod_destroyed = TRUE
	record.original_bed = null

	if(!QDELETED(character) && release_turf)
		character.doMove(release_turf)

		world.log << "CRYO OUT: Ejected character location = [character.loc]"

		release_turf.visible_message(
			span_warning("The cryogenic chamber ruptures, spilling freezing fluid across the floor as [character] tumbles out!")
		)

	occupant_record = null

/obj/machinery/cryo_out/Destroy()
	if(occupant_record)
		release_cryo_occupant()

	return ..()

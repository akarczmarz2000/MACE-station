
// Server module: per-job ckey whitelist.
// Include this file in tgstation.dme AFTER upstream DM includes.

#define SERVER_JOB_WHITELIST_PATH "server_modules/job_whitelist/job_whitelist.json"

GLOBAL_VAR_INIT(server_job_whitelist_loaded, FALSE)
GLOBAL_LIST_EMPTY(server_job_whitelist)

/proc/server_job_whitelist_load()
    if(!fexists(SERVER_JOB_WHITELIST_PATH))
        world.log << "JOB WHITELIST: Missing [SERVER_JOB_WHITELIST_PATH]; restricted jobs denied."
        GLOB.server_job_whitelist_loaded = FALSE
        return FALSE

    var/raw = file2text(SERVER_JOB_WHITELIST_PATH)
    var/list/decoded

    try
        decoded = json_decode(raw)
    catch(var/exception/e)
        world.log << "JOB WHITELIST: Invalid JSON: [e]"
        GLOB.server_job_whitelist_loaded = FALSE
        return FALSE

    if(!islist(decoded))
        GLOB.server_job_whitelist_loaded = FALSE
        return FALSE

    var/list/parsed = list()

    for(var/job_title in decoded)
        var/list/players = decoded[job_title]

        if(!islist(players))
            GLOB.server_job_whitelist_loaded = FALSE
            return FALSE

        var/list/approved = list()

        for(var/key in players)
            if(!istext(key))
                GLOB.server_job_whitelist_loaded = FALSE
                return FALSE

            var/normalized = ckey(key)

            if(normalized)
                approved[normalized] = TRUE

        parsed[job_title] = approved

    GLOB.server_job_whitelist = parsed
    GLOB.server_job_whitelist_loaded = TRUE

    world.log << "JOB WHITELIST: Loaded [length(parsed)] job lists."
    return TRUE


/proc/server_job_whitelist_restricted(datum/job/job)
    if(!job)
        return FALSE

    // All heads of staff require approval.
    if(job.job_flags & JOB_HEAD_OF_STAFF)
        return TRUE

    // Silicon jobs require approval.
    if(job.title == "AI" || job.title == "Cyborg")
        return TRUE

    // Additional jobs listed in JSON are restricted.
    return !isnull(GLOB.server_job_whitelist[job.title])


/proc/server_job_whitelist_allowed(client/player, datum/job/job)
    if(!job || !player || !player.ckey)
        return FALSE

    if(!GLOB.server_job_whitelist_loaded)
        server_job_whitelist_load()

    if(!server_job_whitelist_restricted(job))
        return TRUE

    // Deny restricted jobs if configuration failed.
    if(!GLOB.server_job_whitelist_loaded)
        return FALSE

    var/list/approved = GLOB.server_job_whitelist[job.title]

    return islist(approved) && !!approved[ckey(player.ckey)]


#undef SERVER_JOB_WHITELIST_PATH

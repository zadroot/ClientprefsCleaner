/**
* Clientprefs Cleaner (Cookies Purge) by Root
*
* Description:
*   Removes old cookies from clientprefs database.
*
* Version 1.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

#include <clientprefs>

// ====[ CONSTANTS ]===========================================================
#define PLUGIN_NAME    "Clientprefs Cleaner (Cookies Purge)"
#define PLUGIN_VERSION "1.0"

// ====[ PLUGIN ]==============================================================
new Handle:db = INVALID_HANDLE, Handle:purge_days = INVALID_HANDLE;

public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Removes old cookies from clientprefs database",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Connect to a clientprefs database, which is already defined in databases config
	decl String:error[PLATFORM_MAX_PATH];
	db = SQL_Connect("clientprefs", true, error, sizeof(error));

	// If clientprefs library or database is not available...
	if (!LibraryExists("clientprefs") || db == INVALID_HANDLE)
	{
		// ...disable a plugin and log the actual error
		SetFailState("Plugin encountered fatal error: %s", error);
	}

	// Create plugin ConVars
	CreateConVar("sm_clientprefs_cleaner", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	purge_days = CreateConVar("sm_cookies_removedays", "30", "Removes cookies which hasn't updated for X days", FCVAR_PLUGIN, true, 0.0);
}

/* OnMapStart()
 *
 * When the map starts.
 * ---------------------------------------------------------------------------- */
public OnMapStart()
{
	if (GetConVarInt(purge_days))
	{
		// Prepare and execute a purging query with current timestamp
		new String:query[512];
		Format(query, sizeof(query), "DELETE FROM sm_cookie_cache WHERE timestamp <= %i; VACUUM", GetTime() - (GetConVarInt(purge_days) * 86400));
		SQL_TQuery(db, CP_PurgeCallback, query);
	}
}

/* OnClientCookiesCached()
 *
 * Called once a client's saved cookies have been loaded from the database.
 * ---------------------------------------------------------------------------- */
public OnClientCookiesCached(client)
{
	new String:client_steamid[MAX_NAME_LENGTH];

	// Make sure client is authorized, or in worst case invalid steam id may be passed in query
	if (GetClientAuthString(client, client_steamid, sizeof(client_steamid)))
	{
		// Prepare query and make SQL safer by removing bad characters from player's steamid
		new String:query[512], String:safe_steamid[(MAX_NAME_LENGTH*2)+1];
		SQL_EscapeString(db, client_steamid, safe_steamid, sizeof(safe_steamid));

		// Refresh timestamp because its wont manually update to newest when client cookies just cached
		// It's requred because by default timestamp updates when client actually changed cookie value - not just connects
		Format(query, sizeof(query), "UPDATE sm_cookie_cache SET timestamp = %i WHERE player = '%s'", GetTime(), safe_steamid);
		SQL_TQuery(db, CP_CheckErrors, query);
	}
}

/* CP_CheckErrors()
 *
 * Executes a query.
 * ---------------------------------------------------------------------------- */
public CP_CheckErrors(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (error[0]) LogError(error);
}

/* CP_PurgeCallback()
 *
 * Threaded query callback (database purge).
 * ---------------------------------------------------------------------------- */
public CP_PurgeCallback(Handle:owner, Handle:handle, const String:error[], any:data)
{
	// If any row were affected by purging query - clientprefs database was purged!
	if (SQL_GetAffectedRows(owner))
	{
		// Log information how many cookies were pruged
		LogMessage("Clientprefs purged: cookies of %i players was removed due of inactivity.", SQL_GetAffectedRows(owner));
	}
}
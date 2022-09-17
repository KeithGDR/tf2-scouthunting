#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <dhooks>
#include <tf2items>

bool g_Late;

enum TF2Quality {
	TF2Quality_Normal = 0, // 0
	TF2Quality_Rarity1,
	TF2Quality_Genuine = 1,
	TF2Quality_Rarity2,
	TF2Quality_Vintage,
	TF2Quality_Rarity3,
	TF2Quality_Rarity4,
	TF2Quality_Unusual = 5,
	TF2Quality_Unique,
	TF2Quality_Community,
	TF2Quality_Developer,
	TF2Quality_Selfmade,
	TF2Quality_Customized, // 10
	TF2Quality_Strange,
	TF2Quality_Completed,
	TF2Quality_Haunted,
	TF2Quality_ToborA
};

#define	SHAKE_START 0				// Starts the screen shake for all players within the radius.
#define	SHAKE_STOP 1				// Stops the screen shake for all players within the radius.
#define	SHAKE_AMPLITUDE 2			// Modifies the amplitude of an active screen shake for all players within the radius.
#define	SHAKE_FREQUENCY 3			// Modifies the frequency of an active screen shake for all players within the radius.
#define	SHAKE_START_RUMBLEONLY 4	// Starts a shake effect that only rumbles the controller, no screen effect.
#define	SHAKE_START_NORUMBLE 5		// Starts a shake that does NOT rumble the controller.

// enum struct Player {

// }

// Player g_Player[MAXPLAYERS + 1];

Handle g_EquipWearable;
Handle g_RemoveAmmo;

bool g_Jumping[MAXPLAYERS + 1];

bool g_Live;

int g_Glow[MAXPLAYERS + 1] = {-1, ...};

public Plugin myinfo = {
	name = "[TF2] Scout Hunting", 
	author = "Drixevel, ktaeouh", 
	description = "Hunt Civilian Scouts as a Soldier with the Rocket Jumper, Mantreads and Market Gardener.", 
	version = "1.0.0", 
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("player_death", Event_OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("rocket_jump", Event_RocketJump);
	HookEvent("rocket_jump_landed", Event_RocketJump);

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	AddCommandListener(Listener_Kill, "kill");
	AddCommandListener(Listener_Kill, "explode");

	GameData gamedata = new GameData("sm-tf2.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual( gamedata.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_EquipWearable = EndPrepSDKCall()) == null) {
		LogError("Failed to create call: CBasePlayer::EquipWearable");
	}
	
	gamedata.Close();

	gamedata = new GameData("tf2.scouthunting");

	if (gamedata == null) {
		SetFailState("Could not find tf2.scouthunting gamedata!");
	}
	
	int iOffset = GameConfGetOffset(gamedata, "CTFPlayer::RemoveAmmo");
	if ((g_RemoveAmmo = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CTFPlayer_RemoveAmmo)) == null) {
		SetFailState("Failed to create DHook for CTFPlayer::RemoveAmmo offset!");
	}
	DHookAddParam(g_RemoveAmmo, HookParamType_Int); //iCount
	DHookAddParam(g_RemoveAmmo, HookParamType_Int); //iAmmoIndex

	gamedata.Close();

	if (g_Late && GetTotalPlayers() > 1) {
		HandleMapLogic();

		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);

				if (IsPlayerAlive(i)) {
					CreateTimer(0.2, Timer_DelaySpawn, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}

		g_Live = true;
		ServerCommand("mp_restartgame 2");
	}

	CreateTimer(1.0, Timer_ShowHud, _, TIMER_REPEAT);
}

public void OnConfigsExecuted() {
	FindConVar("tf_dropped_weapon_lifetime").IntValue = 0;
	FindConVar("mp_autoteambalance").IntValue = 0;
	FindConVar("mp_scrambleteams_auto").IntValue = 0;
}

public void OnMapEnd() {
	g_Live = false;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (GetTotalPlayers() < 2) {
		return;
	} else if (!g_Live) {
		g_Live = true;
		ServerCommand("mp_restartgame 2");
	}

	CreateTimer(0.2, Timer_DelaySpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	if (GetTotalPlayers() < 2) {
		return;
	}

	CreateTimer(0.2, Timer_DelaySpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}

	SetThirdperson(client, false);

	if (g_Glow[client] != -1 && IsValidEntity(g_Glow[client])) {
		if (g_Glow[client] > 0) {
			AcceptEntityInput(g_Glow[client], "Kill");
		}
		g_Glow[client] = -1;
	}

	switch (TF2_GetClientTeam(client)) {
		case TFTeam_Red: {
			TF2_SetPlayerClass(client, TFClass_Scout, true, true);
			TF2_RegeneratePlayer(client);
			TF2_RemoveAllWeapons(client);
			SetThirdperson(client, true);
		}
		case TFTeam_Blue: {
			TF2_SetPlayerClass(client, TFClass_Soldier, true, true);
			TF2_RegeneratePlayer(client);
			TF2_RemoveAllWeapons(client);
			TF2_GiveItem(client, "tf_weapon_rocketlauncher", 237);
			TF2_GiveItem(client, "tf_wearable", 444);
			TF2_GiveItem(client, "tf_weapon_shovel", 416);
			g_Glow[client] = TF2_CreateGlow(client, view_as<int>({255, 255, 255, 200}));
		}
	}

	return Plugin_Stop;
}

public Action Event_OnPlayerDeathPre(Event event, const char[] name, bool dontBroadcast) {
	//Defaults to true so the killfeed is OFF.
	bool hidefeed = true;
	
	//Actively hide the feed from this specific client.
	event.BroadcastDisabled = hidefeed;
	return Plugin_Changed;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (GetTotalPlayers() < 2) {
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	g_Jumping[client] = false;

	if (TF2_GetClientTeam(client) == TFTeam_Red && client != attacker) {
		ScreenShakeAll(SHAKE_START, 25.0, 100.0, 0.5);
		EmitGameSoundToAll(GetRandomInt(0, 1) == 0 ? "Scout.Death" : "Scout.CritDeath");

		float origin[3];
		GetClientAbsOrigin(attacker, origin);

		float origin2[3]; char sSound[PLATFORM_MAX_PATH];
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
				GetClientAbsOrigin(i, origin2);

				if (GetVectorDistance(origin, origin2) <= 300.0) {
					FormatEx(sSound, sizeof(sSound), "Scout.HelpMe0%i", GetRandomInt(1, 4));
					EmitGameSoundToAll(sSound, i);
				}
			}
		}
	}

	int reds = GetAliveReds() - 1;

	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		if (reds < 1) {
			TF2_ForceWin(TFTeam_Blue);
		} else if (client != attacker) {
			PrintToChatAll("[Mode] %i Scout Remains.", reds);
		}
	}

	if (g_Glow[client] != -1 && IsValidEntity(g_Glow[client])) {
		if (g_Glow[client] > 0) {
			AcceptEntityInput(g_Glow[client], "Kill");
		}
		g_Glow[client] = -1;
	}
}

int GetAliveReds() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			count++;
		}
	}

	return count;
}

int GetTotalPlayers() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			count++;
		}
	}

	return count;
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (GetTotalPlayers() < 2) {
		return;
	}

	HandleMapLogic();

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue) {
			TF2_ChangeClientTeam(i, TFTeam_Red);
			TF2_RespawnPlayer(i);
		}
	}

	int random = GetRandomSoldier();

	if (random > 0) {
		TF2_ChangeClientTeam(random, TFTeam_Blue);
		TF2_RespawnPlayer(random);
	} else {
		PrintToChatAll("[Mode] Couldn't find a Soldier.");
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			switch (TF2_GetClientTeam(i)) {
				case TFTeam_Red: {
					PrintToChat(i, "[Mode] Survive until the end of the round to win.");
				}
				case TFTeam_Blue: {
					PrintToChat(i, "[Mode] Kill all Scouts to win the match, you can only Market Garden them.");
				}
			}
		}
	}

	TF2_CreateTimer(15, 300);
}

int GetRandomSoldier() {
	int[] clients = new int[MaxClients];
	int amount;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i)) {
			continue;
		}

		clients[amount++] = i;
	}

	return (amount == 0) ? -1 : clients[GetRandomInt(0, amount - 1)];
}

public Action OnClientCommand(int client, int args) {
	if (GetTotalPlayers() < 2) {
		return Plugin_Continue;
	}

	char sCommand[32];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	PrintToChat(client, sCommand);

	if (StrEqual(sCommand, "jointeam", false) && GetClientTeam(client) > 2) {
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

int TF2_GiveItem(int client, char[] classname, int index, TF2Quality quality = TF2Quality_Normal, int level = 0, const char[] attributes = "") {
	char sClass[64];
	strcopy(sClass, sizeof(sClass), classname);
	
	if (StrContains(sClass, "saxxy", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Scout: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bat");
			}
			case TFClass_Sniper: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_club");
			}
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shovel");
			}
			case TFClass_DemoMan: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bottle");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_wrench");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fireaxe");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fists");
			}
			case TFClass_Spy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_knife");
			}
			case TFClass_Medic: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bonesaw");
			}
		}
	} else if (StrContains(sClass, "shotgun", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_soldier");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_pyro");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_hwg");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_primary");
			}
		}
	}
	
	Handle item = TF2Items_CreateItem(PRESERVE_ATTRIBUTES | FORCE_GENERATION);	//Keep reserve attributes otherwise random issues will occur... including crashes.
	TF2Items_SetClassname(item, sClass);
	TF2Items_SetItemIndex(item, index);
	TF2Items_SetQuality(item, view_as<int>(quality));
	TF2Items_SetLevel(item, level);
	
	char sAttrs[32][32];
	int count = ExplodeString(attributes, " ; ", sAttrs, 32, 32);
	
	if (count > 1) {
		TF2Items_SetNumAttributes(item, count / 2);
		
		int i2;
		for (int i = 0; i < count; i += 2) {
			TF2Items_SetAttribute(item, i2, StringToInt(sAttrs[i]), StringToFloat(sAttrs[i + 1]));
			i2++;
		}
	} else {
		TF2Items_SetNumAttributes(item, 0);
	}

	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	if (StrEqual(sClass, "tf_weapon_builder", false) || StrEqual(sClass, "tf_weapon_sapper", false)) {
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}
	
	if (StrContains(sClass, "tf_weapon_", false) == 0) {
		EquipPlayerWeapon(client, weapon);
	}

	if (StrContains(sClass, "tf_wearable", false) == 0 && g_EquipWearable != null) {
		SDKCall(g_EquipWearable, client, weapon);
	}
	
	return weapon;
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	DHookEntity(g_RemoveAmmo, false, client);
}

public void OnClientDisconnect_Post(int client) {
	g_Jumping[client] = false;
}

public MRESReturn CTFPlayer_RemoveAmmo(int pThis, Handle hReturn, Handle hParams) {
	if (GetTotalPlayers() < 2) {
		return MRES_Ignored;
	}

	DHookSetParam(hParams, 1, 0);
	DHookSetReturn(hReturn, DHookGetReturn(hReturn));
	
	return MRES_Supercede;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (GetTotalPlayers() < 2) {
		return Plugin_Continue;
	}

	if (victim == attacker) {
		return Plugin_Continue;
	}

	if ((damagetype & DMG_FALL) == DMG_FALL) {
		damage = 0.0;
		return Plugin_Changed;
	}

	if ((IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != 416) || (GetEntityFlags(attacker) & FL_ONGROUND) == FL_ONGROUND || !g_Jumping[attacker]) {
		switch (GetRandomInt(1, 4)) {
			case 1: {
				EmitGameSoundToClient(victim, "Scout.InvincibleChgUnderFire01");
				EmitGameSoundToClient(attacker, "Scout.InvincibleChgUnderFire01");
			}
			case 2: {
				EmitGameSoundToClient(victim, "Scout.InvincibleChgUnderFire02");
				EmitGameSoundToClient(attacker, "Scout.InvincibleChgUnderFire02");
			}
			case 3: {
				EmitGameSoundToClient(victim, "Scout.InvincibleChgUnderFire03");
				EmitGameSoundToClient(attacker, "Scout.InvincibleChgUnderFire03");
			}
			case 4: {
				EmitGameSoundToClient(victim, "Scout.InvincibleChgUnderFire04");
				EmitGameSoundToClient(attacker, "Scout.InvincibleChgUnderFire04");
			}
		}
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

void SetThirdperson(int client, bool value) {
	SetVariantInt(view_as<int>(value));
	AcceptEntityInput(client, "SetForcedTauntCam");
}

bool ScreenShakeAll(int command = SHAKE_START, float amplitude = 50.0, float frequency = 150.0, float duration = 3.0, float distance = 0.0, float origin[3] = NULL_VECTOR) {
	if (amplitude <= 0.0) {
		return false;
	}
		
	if (command == SHAKE_STOP) {
		amplitude = 0.0;
	}
	
	bool pb = GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;
	
	Handle userMessage; float vecOrigin[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		
		GetClientAbsOrigin(i, vecOrigin);
			
		if (distance > 0.0 && GetVectorDistance(origin, vecOrigin) > distance) {
			continue;
		}
		
		userMessage = StartMessageOne("Shake", i);

		if (pb) {
			PbSetInt(userMessage, "command", command);
			PbSetFloat(userMessage, "local_amplitude", amplitude);
			PbSetFloat(userMessage, "frequency", frequency);
			PbSetFloat(userMessage, "duration", duration);
		} else {
			BfWriteByte(userMessage, command);		// Shake Command
			BfWriteFloat(userMessage, amplitude);	// shake magnitude/amplitude
			BfWriteFloat(userMessage, frequency);	// shake noise frequency
			BfWriteFloat(userMessage, duration);	// shake lasts this long
		}

		EndMessage();
	}
	
	return true;
}

void HandleMapLogic() {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_regenerate")) != -1) {
		AcceptEntityInput(entity, "Disable");
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "item_healthkit_*")) != -1) {
		AcceptEntityInput(entity, "Disable");
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "item_ammopack_*")) != -1) {
		AcceptEntityInput(entity, "Disable");
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_respawnroomvisualizer")) != -1) {
		AcceptEntityInput(entity, "Disable");
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "tf_logic_koth")) {
		SDKHook(entity, SDKHook_Spawn, OnKOTHLogicSpawned);
	}
}

public Action OnKOTHLogicSpawned(int entity) {
	AcceptEntityInput(entity, "Kill");
	return Plugin_Stop;
}

stock int TF2_GetTimer() {
	int entity = FindEntityByClassname(-1, "team_round_timer");

	if (!IsValidEntity(entity)) {
		entity = CreateEntityByName("team_round_timer");
	}
	
	return entity;
}

stock int TF2_CreateTimer(int setup_time, int round_time) {
	int entity = TF2_GetTimer();

	GameRules_SetProp("m_bInSetup", true);

	HookSingleEntityOutput(entity, "OnFinished", Timer_OnFinished);
	
	char sSetup[32];
	IntToString(setup_time + 1, sSetup, sizeof(sSetup));
	
	char sRound[32];
	IntToString(round_time + 1, sRound, sizeof(sRound));
	
	DispatchKeyValue(entity, "reset_time", "1");
	DispatchKeyValue(entity, "show_time_remaining", "1");
	DispatchKeyValue(entity, "setup_length", sSetup);
	DispatchKeyValue(entity, "timer_length", sRound);
	DispatchKeyValue(entity, "auto_countdown", "1");
	DispatchSpawn(entity);

	AcceptEntityInput(entity, "Enable");
	AcceptEntityInput(entity, "Resume");

	SetVariantInt(1);
	AcceptEntityInput(entity, "ShowInHUD");

	return entity;
}

public void Timer_OnFinished(const char[] output, int caller, int activator, float delay) {
	TF2_ForceWin(TFTeam_Red);
}

void TF2_ForceWin(TFTeam team = TFTeam_Unassigned) {
	int flags = GetCommandFlags("mp_forcewin");
	SetCommandFlags("mp_forcewin", flags &= ~FCVAR_CHEAT);
	ServerCommand("mp_forcewin %i", view_as<int>(team));
	SetCommandFlags("mp_forcewin", flags);
}

public void Event_RocketJump(Event event, char[] name, bool dontBroadcast) {
	if (GetTotalPlayers() < 2) {
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (StrEqual(name, "rocket_jump")) {
		g_Jumping[client] = true;
	} else {
		g_Jumping[client] = false;
	}
}

public Action Timer_ShowHud(Handle timer) {
	if (GetTotalPlayers() < 2 && !g_Live) {
		PrintCenterTextAll("Waiting for 2 or more players to start.");
	}
	return Plugin_Continue;
}

stock int TF2_CreateGlow(int target, int color[4] = {255, 255, 255, 255}) {
	char sClassname[64];
	GetEntityClassname(target, sClassname, sizeof(sClassname));

	char sTarget[128];
	Format(sTarget, sizeof(sTarget), "%s%i", sClassname, target);
	DispatchKeyValue(target, "targetname", sTarget);

	int glow = CreateEntityByName("tf_glow");

	if (IsValidEntity(glow)) {
		char sGlow[64];
		Format(sGlow, sizeof(sGlow), "%i %i %i %i", color[0], color[1], color[2], color[3]);

		DispatchKeyValue(glow, "target", sTarget);
		DispatchKeyValue(glow, "Mode", "1"); //Mode is currently broken.
		DispatchKeyValue(glow, "GlowColor", sGlow);
		DispatchSpawn(glow);
		
		SetVariantString("!activator");
		AcceptEntityInput(glow, "SetParent", target, glow);

		AcceptEntityInput(glow, "Enable");
	}

	return glow;
}

public Action Listener_VoiceMenu(int client, const char[] command, int argc) {
	char sVoice[32];
	GetCmdArg(1, sVoice, sizeof(sVoice));

	char sVoice2[32];
	GetCmdArg(2, sVoice2, sizeof(sVoice2));
	
	//MEDIC! is called if both of these values are 0.
	if (!StrEqual(sVoice, "0", false) || !StrEqual(sVoice2, "0", false)) {
		return Plugin_Continue;
	}

	char sSound[PLATFORM_MAX_PATH];
	FormatEx(sSound, sizeof(sSound), "Scout.No0%i", GetRandomInt(1, 3));
	EmitGameSoundToAll(sSound, client);
	
	return Plugin_Stop;
}

public Action Listener_Kill(int client, const char[] command, int argc) {
	return Plugin_Stop;
}
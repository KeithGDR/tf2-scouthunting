#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
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
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("teamplay_round_start", Event_OnRoundStart);

	GameData gamedata = new GameData("sm-tf2.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual( gamedata.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_EquipWearable = EndPrepSDKCall()) == null) {
		LogError("Failed to create call: CBasePlayer::EquipWearable");
	}
	
	gamedata.Close();

	if (g_Late) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);

				if (IsPlayerAlive(i)) {
					CreateTimer(0.2, Timer_DelaySpawn, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(0.2, Timer_DelaySpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(0.2, Timer_DelaySpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}

	SetThirdperson(client, false);

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
		}
	}

	return Plugin_Stop;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		ScreenShakeAll(SHAKE_START, 25.0, 100.0, 0.5);
	}
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue) {
			TF2_ChangeClientTeam(i, TFTeam_Red);
		}
	}

	int random = GetRandomSoldier();

	if (random > 0) {
		TF2_ChangeClientTeam(random, TFTeam_Blue);
	}
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
	char sCommand[32];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	//PrintToChat(client, sCommand);

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
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (victim == attacker) {
		return Plugin_Continue;
	}

	if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != 416 || (GetEntityFlags(attacker) & FL_ONGROUND) == FL_ONGROUND) {
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
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#pragma semicolon 1

#define PLUGIN_VERSION		"1.0"
//##################
//# Plugin Details
//##################
public Plugin myinfo =
{
	name = "DOD:S RaidBoss",
	author = "ChesterSmitty aka T/Sgt C. Smith |8th ID|",
	description = "Raid Boss Minigame by T/Sgt C. Smith |8th ID|",
	version = PLUGIN_VERSION,
	url = "https://github.com/ChesterSmitty/dod_raidboss"
};

//##################
//# Constants
//##################
#define DOD_MAXPLAYERS	33

#define TEAM_SPECTATOR  1
#define TEAM_ALLIES  		2
#define TEAM_AXIS  			3
#define TEAM_RANDOM  		4

#define MAXCLASSES		14
#define MAXWEAPONS		22

#define NOTEAM	0
#define SPEC	1
#define ALLIES	2
#define AXIS	3

#define MAXCLASSES		14
#define MAXWEAPONS		22
#define MAXVOICECMDS	39
#define BLINDOVERLAY	"Effects/tp_eyefx/tp_black"
#define HIDEHUD_ALL		( 1<<2 )

//##################
//# Configs
//##################

#define MATCHCFG		"cfg/dod_raidboss/dod_raidboss.ini"
#define INACTIVECFG     "dod_raidboss/inactive.cfg"
#define INITCFG			"dod_raidboss/init.cfg"
#define STARTCFG		"dod_raidboss/start.cfg"
#define LIVECFG		    "dod_raidboss/live.cfg"
#define ROUNDENDCFG		"dod_raidboss/roundend.cfg"

new Handle:v_TextEnabled = INVALID_HANDLE;

//##################
//# Variables
//##################
char g_sSounds[2][] = {"", "dod_raidboss/bfgdivision.wav"};
new Handle:ScoreToWin = INVALID_HANDLE;
new bool:g_bModRunning = true;
new bool:g_bRoundActive = true;

new g_numBosses = 0;
new g_Boss 		= 0;
new g_Boss2 	= 0;

new Handle:LiveTime = INVALID_HANDLE;
new Handle:AllowObjectives = INVALID_HANDLE
new Handle:AllowVoiceCmds = INVALID_HANDLE
new Handle:AllowStuckCmd = INVALID_HANDLE
new Handle:GameTimer = INVALID_HANDLE
new Handle:BossHealth = INVALID_HANDLE
new g_PluginSwitched[MAXPLAYERS+1]
new bool:g_PrimedNade[MAXPLAYERS+1]
new g_PluginClass[MAXPLAYERS+1]
new g_PlayerTeam[MAXPLAYERS+1]
new Float:g_PlayerSpawnPos[MAXPLAYERS+1][3]
new Handle:AFKTimer[MAXPLAYERS+1] = INVALID_HANDLE
new g_Started = 0, g_Live = 0, g_RoundCount = 0, g_AVA = 0, g_Init = 0
new Float:g_StartTime = 0.0
new CPM = -1
new Score[2]
new g_MatchWinner, g_CmdsAvailable
new g_iAmmo, g_iClip1
new Float:g_LastStuck[MAXPLAYERS+1]
new Kills[MAXPLAYERS+1]
new Deaths[MAXPLAYERS+1]
new InitialTeam, InitMinPlayers
new String:ChangeToMap[256]
new Handle:OnRaidBossStarted = INVALID_HANDLE
new Handle:OnRaidBossEnded = INVALID_HANDLE
new Handle:OnRoundStart = INVALID_HANDLE
new Handle:OnRoundLive = INVALID_HANDLE

new String:ClassCmd[MAXCLASSES][] =
{
	"cls_garand", "cls_tommy", "cls_bar", "cls_spring", "cls_30cal", "cls_bazooka",
	"cls_k98", "cls_mp40", "cls_mp44", "cls_k98s", "cls_mg42", "cls_pschreck",
	"cls_random", "joinclass"
}

new String:VoiceCmd[MAXVOICECMDS][]=
{
	"voice_attack", "voice_hold", "voice_left", "voice_right", "voice_sticktogether",
	"voice_cover", "voice_usesmoke", "voice_usegrens", "voice_ceasefire", "voice_yessir",
	"voice_negative", "voice_backup", "voice_fireinhole", "voice_grenade", "voice_sniper",
	"voice_niceshot", "voice_thanks", "voice_areaclear", "voice_dropweapons", "voice_displace",
	"voice_mgahead", "voice_enemybehind", "voice_wegothim", "voice_moveupmg", "voice_needammo",
	"voice_usebazooka", "voice_bazookaspotted", "voice_gogogo", "voice_wtf", "voice_medic",
	"voice_fireleft", "voice_fireright", "voice_coverflanks", "voice_cover", "voice_fallback",
	"voice_movewithtank", "voice_takeammo", "voice_tank", "voice_enemyahead"
}

new String:AlliesAttackSnd[3][] =
{
	"player/american/startround/us_flags.wav",
	"player/american/startround/us_flags3.wav",
	"player/american/startround/us_flags6.wav"
}

new String:AxisDefendSnd[3][] =
{
	"player/german/startround/ger_defense.wav",
	"player/german/startround/ger_defense2.wav",
	"player/german/startround/ger_defense3.wav"
}
//##################
//# Actions
//##################

public void OnConfigsExecuted()
{

	char sSound[64];

	for (int i = 1; i < sizeof(g_sSounds); i++) {

		Format(sSound, sizeof(sSound), "sound/%s", g_sSounds[i]);
		PrecacheSound(g_sSounds[i]);
		AddFileToDownloadsTable(sSound);
	}
	return;
}

public void OnPluginStart()
{
	CreateConVar("dod_raidboss_version", PLUGIN_VERSION, "DoD RaidBoss", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	SetConVarString(FindConVar("dod_raidboss"), PLUGIN_VERSION)
	RegAdminCmd("sm_raidboss", RaidBoss, ADMFLAG_ROOT, "sm_raidboss");
	LoadTranslations("common.phrases.txt");
	AllowVoiceCmds = CreateConVar("dod_rmhelper_allowvcmds", "0", "<1/0> = enable/disable VoiceCommands on Init/Start", FCVAR_PLUGIN, true, 0.0, true, 1.0)
	LiveTime = CreateConVar("dod_rmhelper_livetime", "5", "<#> = time in minutes for live round", FCVAR_PLUGIN, true, 1.0, true, 30.0)
	BossHealth = CreateConVar("dod_raidboss_health", "10000", "<#> = Health of Bosses", FCVAR_PLUGIN, true, 1.0, true, 30.0)
	HookEvent("player_team", OnJoinTeam, EventHookMode_Pre)
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre)
	HookEventEx("player_spawn", OnPlayerSpawn, EventHookMode_Post)
	HookEventEx("dod_round_active", RoundActive, EventHookMode_Post)
	HookEventEx("dod_round_start", RoundStart, EventHookMode_Post)
	AddNormalSoundHook(NormalSHook:BlockStartVoice)
	OnRaidBossStarted = CreateGlobalForward("OnRaidBossStarted", ET_Event)
	OnRaidBossEnded   = CreateGlobalForward("OnRaidBossEnded", ET_Event)
	OnRoundStart = CreateGlobalForward("OnRoundStart", ET_Event)
	OnRoundLive  = CreateGlobalForward("OnRoundLive",  ET_Event)
	for(new i = 0; i < MAXVOICECMDS; i++)
	{
		RegConsoleCmd(VoiceCmd[i], cmd_voice)
	}
	RegAdminCmd("say", cmd_say, 0)
	RegAdminCmd("kill", cmd_kill, 0)
	RegAdminCmd("explode", cmd_kill, 0)
	RegAdminCmd("jointeam", cmd_jointeam, 0)
	RegAdminCmd("sm_init", cmdInit, ADMFLAG_KICK)
	RegAdminCmd("sm_start", cmdStart, ADMFLAG_KICK)
	RegAdminCmd("sm_suicide", cmdSuicide, 0)
	RegAdminCmd("sm_stuck", cmdStuck, 0)
	AutoExecConfig(true,"dod_raidboss", "dod_raidboss")
}

public Action:BlockStartVoice(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(g_Init == 0 && g_Started == 0)
	{
		return Plugin_Continue
	}
	if((g_Started == 1 || g_Init == 1) && g_Live == 0 && StrContains(sample, "player") != -1 && (StrContains(sample, "american") != -1 || StrContains(sample, "german") != -1) && StrContains(sample, "startround") != -1)
	{
		return Plugin_Stop
	}
	return Plugin_Continue
}

public OnMapStart()
{
	g_Init = 0
	g_CmdsAvailable = 0
	g_Boss = 0
	//PrecacheModel(EFFECT_MDL , true);
	//PrecacheModel("materials/sprites/physbeam.vmt");
	//PrecacheModel("models/player/b4p/b4p_bdroid/bdroid.mdl"); // 1

// Materials and Models Download
	//AddFileToDownloadsTable("materials/models/player/b4p/sidious/arms.vmt");

	// Sprites
	//fire=PrecacheModel("materials/sprites/fire2.vmt");

	// Sounds
	//PrecacheSound( "ambient/explosions/explode_8.wav", true);

	// Sound downloads
	//AddFileToDownloadsTable("sound/vox/alert.wav");
}

public OnPreThink(client)
{
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))//, grenade
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) <= SPEC)
	{
		return Plugin_Continue
	}
	ClientCommand(client, "r_screenoverlay 0")
	//g_LastStuck[client] = 0.0
	//g_PrimedNade[client] = false
	if(g_Started == 0)
	{
		return Plugin_Continue
	}
	GetClientAbsOrigin(client, g_PlayerSpawnPos[client])
	g_PlayerTeam[client] = GetClientTeam(client)
	if(g_Started == 1)
	{
		SetEntProp(client, Prop_Data, "m_iDeaths", Deaths[client])
		SetEntProp(client, Prop_Data, "m_iFrags", Kills[client])
	}
	if(g_Started == 1 && g_Init == 1 && GetClientTeam(client) == AXIS)
	{
		SetEntityHealth(client, GetConVarInt(BossHealth));
		SetEntityModel(client,"models/player/vad36santa/red.mdl");
	}
	return Plugin_Continue
}


public Event_PlayerDeath(Handle:event, const String:szName[], bool:bDontBroadcast)
{
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client < 1 || !IsClientInGame(client) || GetClientTeam(client) <= SPEC || g_Live == 0)
	{
		return Plugin_Continue
	}
	if(AFKTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(AFKTimer[client])
	}
	g_PluginClass[client] = 0
	AFKTimer[client] = INVALID_HANDLE
	CreateTimer(1.0, SoldierDown, client, TIMER_FLAG_NO_MAPCHANGE)
	return Plugin_Continue
}

public OnClientPutInServer(client)
{
}

public Action:RaidBoss(int client, int args)
{
	ReplyToCommand(client, "T/Sgt. Smith's Raid Boss here!");
	return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
}

public Action:RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_CmdsAvailable = 0
	return Plugin_Continue
}

public Action:RoundActive(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_StartTime = GetGameTime()
	g_CmdsAvailable = 1
	if(g_Init == 0 && g_Started == 0)
	{
		ServerCommand("exec %s", INACTIVECFG)
	}
	if(g_Started == 1 && g_Live == 0)
	return Plugin_Continue
}

public Action:cmd_jointeam(client, args)
{
	decl String:teamnumber[2]
	GetCmdArg(1,teamnumber,2)
	new team = StringToInt(teamnumber)
	new currteam = GetClientTeam(client)
	if((team == ALLIES || team == AXIS || team == NOTEAM) && g_Live == 1)
	{
		if(currteam == NOTEAM)
		{
			FakeClientCommandEx(client, "jointeam %i", SPEC)
		}
		if(team != SPEC && team != ALLIES)
		{
			PrintHintText(client, "Match is LIVE, you CANNOT join the bosses team!")
		}
		return Plugin_Handled
	}
	if((team == ALLIES || team == AXIS) && g_Live == 0 && (g_Init == 1 || g_Started == 1))
	{
		if(currteam != SPEC && currteam != NOTEAM)
		{
			g_PluginSwitched[client] = 1
			ChangeClientTeam(client, SPEC)
		}
		if(g_Init == 1 && team == ALLIES && currteam == NOTEAM)
		{
			team = AXIS
		}
		ChangeClientTeam(client, team)
		ShowVGUIPanel(client, team == AXIS ? "class_ger" : "class_us", INVALID_HANDLE, false)
		g_PluginClass[client] = 1
		FakeClientCommand(client, "%s", team == AXIS ? "cls_k98" : "cls_garand")
		return Plugin_Handled
	}
	return Plugin_Continue
}

public Action:SoldierDown(Handle:timer, any:client)
{
	if(IsClientInGame(client) && GetClientTeam(client) == AXIS)
	{
		g_PluginSwitched[client] = 1
		ChangeClientTeam(client,SPEC)
	}
	new axiscount = GetTeamClientCount(AXIS)
	if(axiscount == 0 && g_Live == 1)
	{
		if(GameTimer != INVALID_HANDLE)
		{
			CloseHandle(GameTimer)
			GameTimer = INVALID_HANDLE
		}
		g_Live = 0
		PrintHintTextToAll("Round is over! The Boss has been defeated!")
		PrintToChatAll("\x04Round is over! The Boss has been defeated!")
		HandleRoundEnd()
	}
	return Plugin_Handled
}

public Action:HandleRoundEnd()
{
	ServerCommand("exec %s", ROUNDENDCFG)
	g_CmdsAvailable = 0
	ResetRaidBoss()
	AllPlayersInit()
	return Plugin_Handled
}

public Action:CommandSetAmmo(client, args)
{
	return Plugin_Handled;
}

public Action:SelectBoss(client)
{
	new Handle:BossMenu = CreateMenu(Handle_BossMenu)
	decl String:menutitle[256]
	Format(menutitle, sizeof(menutitle), "Select Boss")
	SetMenuTitle(BossMenu, menutitle)
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			new currteam = GetClientTeam(i)
			if(currteam == ALLIES)
			{
				decl String:TargetName[32]
				GetClientName(i, TargetName, sizeof(TargetName))
				new userid = GetClientUserId(i)
				decl String:userid_str[32]
				IntToString(userid, userid_str, sizeof(userid_str))
				AddMenuItem(BossMenu, userid_str, TargetName)
			}
		}
	}
	SetMenuExitButton(BossMenu, true)
	SetMenuExitBackButton(BossMenu, false)
	DisplayMenu(BossMenu, client, MENU_TIME_FOREVER)
	return Plugin_Handled
}

public Handle_BossMenu(Handle:BossMenu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Select)
	{
		new String:userid[MAX_TARGET_LENGTH]
		GetMenuItem(BossMenu, itemNum, userid, sizeof(userid))
		new target = GetClientOfUserId(StringToInt(userid))
		g_Boss = target
		PrintToChat(client, "\x01Player \x04%N \x01has been choosen as the \x04BOSS\x01!", target)
		if(g_numBosses == 2)
		{
			SelectBoss2(client)	
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_Exit)
		{
			if(GetClientMenu(client))
			{
				CancelClientMenu(client)
			}
			g_Boss = 0
			PrintToChat(client, "\x01RaidBoss can \x04NOT \x01be started until you choose the Boss!")
		}
	}
}

public Action:SelectBoss2(client)
{
	new Handle:Boss2Menu = CreateMenu(Handle_Boss2Menu)
	decl String:menutitle[256]
	Format(menutitle, sizeof(menutitle), "Select 2nd Boss")
	SetMenuTitle(Boss2Menu, menutitle)
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			new currteam = GetClientTeam(i)
			if(currteam == ALLIES)
			{
				decl String:TargetName[32]
				GetClientName(i, TargetName, sizeof(TargetName))
				new userid = GetClientUserId(i)
				decl String:userid_str[32]
				IntToString(userid, userid_str, sizeof(userid_str))
				AddMenuItem(Boss2Menu, userid_str, TargetName)
			}
		}
	}
	SetMenuExitButton(Boss2Menu, true)
	SetMenuExitBackButton(Boss2Menu, true)
	DisplayMenu(Boss2Menu, client, MENU_TIME_FOREVER)
	return Plugin_Handled
}

public Handle_Boss2Menu(Handle:Boss2Menu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Select)
	{
		new String:userid[MAX_TARGET_LENGTH]
		GetMenuItem(Boss2Menu, itemNum, userid, sizeof(userid))
		new target = GetClientOfUserId(StringToInt(userid))
		g_Boss2 = target
		PrintToChat(client, "\x01Player \x04%N \x01has been choosen as \x04Axis Team Leader\x01!", target)
		ConfirmBosses(client)
	}
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_ExitBack)
		{
			if(GetClientMenu(client))
			{
				CancelClientMenu(client)
			}
			g_Boss = 0
			SelectBoss(client)
		}
		else if(itemNum == MenuCancel_Exit)
		{
			if(GetClientMenu(client))
			{
				CancelClientMenu(client)
			}
			g_Boss2 = 0
			PrintToChat(client, "\x01RaidBoss will \x04NOT \x01be started until you choose the Bosses!")
		}
	}
}

public Action:ConfirmBosses(client)
{
	new Handle:ConfirmBossesMenu = CreateMenu(Handle_ConfirmBossesMenu)
	decl String:menutitle[256]
	Format(menutitle, sizeof(menutitle), "Confirm Boss(es) and start RaidBoss\n \nBoss1: %N\nBoss2: %N\n ", g_Boss, g_Boss2)
	SetMenuTitle(ConfirmBossesMenu, menutitle)
	decl String:Selection[256]
	Format(Selection, sizeof(Selection), "Start RaidBoss")
	AddMenuItem(ConfirmBossesMenu, "rmh_Start", Selection, ITEMDRAW_DEFAULT)
	Format(Selection, sizeof(Selection), "Change Boss(es)")
	AddMenuItem(ConfirmBossesMenu, "rmh_Change", Selection, ITEMDRAW_DEFAULT)
	SetMenuExitButton(ConfirmBossesMenu, true)
	SetMenuExitBackButton(ConfirmBossesMenu, false)
	DisplayMenu(ConfirmBossesMenu, client, MENU_TIME_FOREVER)
}

public Handle_ConfirmBossesMenu(Handle:ConfirmBossesMenu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Select)
	{
		decl String:menuchoice[256]
		GetMenuItem(ConfirmBossesMenu, itemNum, menuchoice, sizeof(menuchoice))
		if(strcmp(menuchoice, "rmh_Start", true) == 0)
		{
			PrintToChatAll("\x01Starting RaidBoss")
			PrintToChatAll("\x04Boss1: %N  \x01-  \x04Boss2: %N", g_Boss, g_Boss2)
			RaidBossStartNow()
		}
		else if(strcmp(menuchoice, "rmh_Change", true) == 0)
		{
			g_Boss = 0
			g_Boss2 = 0
			SelectBoss(client)
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_Exit)
		{
			if(GetClientMenu(client))
			{
				CancelClientMenu(client)
			}
			g_Boss = 0
			g_Boss2 = 0
			PrintToChat(client, "\x01RaidBoss will \x04NOT \x01be started until you choose the Boss(es)!")
		}
	}
}

public Action:cmdStart(client, args)
{
	if(g_Started == 0 && g_Live == 0 && g_Init == 1)
	{
		if(g_CmdsAvailable != 0)
		{
			g_Boss = 0
			SelectBoss(client)
			Call_StartForward(OnRaidBossStarted)
			Call_Finish()
		}
		else
		{
			ReplyToCommand(client, "Please try again once the current round is active!")
		}
		return Plugin_Handled
	}
	return Plugin_Handled
}

RaidBossStartNow()
{
	ServerCommand("exec %s", STARTCFG)
	g_Started = 1
	g_Init = 0
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			Deaths[i] = 0
			Kills[i] = 0
		}
	}
	AllPlayersStart()
	HandleRoundLive()
	PrintToChatAll("\x04Rip and Tear!!")
}

public Action:cmdLive(client, args)
{
	if(g_Started == 1 && g_Live == 0)
	{
		if(g_CmdsAvailable != 0)
		{
			new plteam = GetClientTeam(client)
			if(plteam != g_Boss || plteam != g_Boss2)
			{
				PrintToChat(client, "\x04Sorry, \x01ONLY \x04the Bosses can call 'live'!")
				return Plugin_Handled
			}

			HandleRoundLive()
			PrintToChatAll("\x01Boss \x04%N \x01has lived the round!", client)
		}
		else
		{
			ReplyToCommand(client, "Please try again once the current round is active!")
		}
		return Plugin_Handled
	}
	return Plugin_Handled
}

public Action:HandleRoundLive()
{
	g_Live = 1
	ServerCommand("exec %s", LIVECFG)
	Call_StartForward(OnRoundLive);
	Call_Finish();

	new Float:livetimer = (GetConVarFloat(LiveTime)*60.0)
	GameTimer = CreateTimer(livetimer, TimerEnd, _, TIMER_FLAG_NO_MAPCHANGE)
	//ZeroTimerWarmup()
	StartLiveTimer()
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			new team = GetClientTeam(i)
			if(team == ALLIES)
			{
				EmitSoundToClient(i, AlliesAttackSnd[GetRandomInt(0, 2)])
			}
			else if(team == AXIS)
			{	
				SetEntityHealth(i, BossHealth)
				EmitSoundToClient(i, AxisDefendSnd[GetRandomInt(0, 2)])
			}
		}
	}
	return Plugin_Handled
}

public Action:ChangeLevel(Handle:timer)
{
	ServerCommand("changelevel %s", ChangeToMap)
	return Plugin_Handled
}

public Action:TimerEnd(Handle:timer)
{
	g_Live = 0
	PrintHintTextToAll("Round is over! The Boss has won!")
	PrintToChatAll("\x04Round is over! \x01The Boss \x04has won!")
	GameTimer = INVALID_HANDLE
	HandleRoundEnd()
	return Plugin_Handled
}

stock SetAmmo(client, slot, amount)
{
    new weapon = GetPlayerWeaponSlot(client, slot);
    if (weapon == -1)
        return 0;

    new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (ammotype == -1)
        return 0;

    return GivePlayerAmmo(client, amount, ammotype);
}

RemoveWeapons(client)
{
	for (new i = 0, iWeapon; i < 5; i++)
	{
		if ((iWeapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEdict(iWeapon);
		}
	}
}

stock AllPlayersInit()
{
	g_Init = 1
	ServerCommand("exec %s", INITCFG)
	Call_StartForward(OnRaidBossStarted)
	Call_Finish()
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			ChangeClientTeam(i, SPEC)
			g_PluginSwitched[i] = 1
			ChangeClientTeam(i, InitialTeam)
			ShowVGUIPanel(i, InitialTeam == AXIS ? "class_ger" : "class_us", INVALID_HANDLE, false)
			g_PluginClass[i] = 1
			FakeClientCommand(i, "%s", InitialTeam == AXIS ? "cls_k98" : "cls_garand")
		}
	}
	SetConVarInt(FindConVar("mp_clan_restartround"), 1, true, false)
}

stock AllPlayersStart()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			Deaths[i] = GetEntProp(i, Prop_Data, "m_iDeaths")
			Kills[i] = GetEntProp(i, Prop_Data, "m_iFrags")
			new team = GetClientTeam(i)
			if(team != SPEC)
			{
				g_PluginSwitched[i] = 1
				ChangeClientTeam(i,SPEC)
				g_PluginSwitched[i] = 1
				ChangeClientTeam(i, team)
				ShowVGUIPanel(i, team == AXIS ? "class_ger" : "class_us", INVALID_HANDLE, false)
				g_PluginClass[i] = 1
				FakeClientCommand(i, "%s", team == AXIS ? "cls_k98" : "cls_garand")
			}
		}
	}
	SetConVarInt(FindConVar("mp_clan_restartround"), 1, true, false)
}

/*stock ZeroTimerWarmup()
{
	new Float:time = (GetConVarFloat(SetupTime)*60) - (GetGameTime() - g_StartTime)
	decl String:timestr[12]
	FloatToString(time, timestr, sizeof(timestr))
	Format(timestr, sizeof(timestr), "-%s", timestr)
	SetVariantString(timestr)
	AcceptEntityInput(CPM, "AddTimerSeconds")
}*/

stock StartLiveTimer()
{
	new Float:time = GetConVarFloat(LiveTime) * 60
	decl String:timestr[12]
	FloatToString(time, timestr, sizeof(timestr))
	Format(timestr, sizeof(timestr), "+%s", timestr)
	SetVariantString(timestr)
	AcceptEntityInput(CPM, "AddTimerSeconds")
}

public Action:OnJoinTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client < 1)
	{
		return Plugin_Continue
	}
	new team = GetEventInt(event, "team")
	if(IsClientInGame(client) && g_PluginSwitched[client] == 1)
	{
		if(team == SPEC)
		{
			g_PluginSwitched[client] = 0
		}
		else if(team == ALLIES || team == AXIS)
		{
			g_PluginSwitched[client] = 0
			return Plugin_Handled
		}
		return Plugin_Handled
	}
	return Plugin_Continue
}


public OnEntityCreated(entity, const String:classname[])
{
	if(entity > 0
	&& entity > MaxClients
	&& IsValidEntity(entity)
	&& IsValidEdict(entity))
	{
		SDKHook(entity, SDKHook_Spawn, OnEntitySpawned)
	}
}

public OnEntitySpawned(entity)
{
	decl String:classname[128]
	GetEdictClassname(entity, classname, sizeof(classname))
	if(g_Started == 1)
	{
		if(StrEqual(classname, "dod_control_point_master"))
		{
			CPM = entity
			//new Float:time
			//decl String:timestr[12]
			//DispatchKeyValue(CPM, "cpm_use_timer", "1")
			/*if(g_RoundCount != 4)
			{
				time = GetConVarFloat(SetupTime) * 60
				FloatToString(time, timestr, sizeof(timestr))
				DispatchKeyValue(CPM, "cpm_timer_length", timestr)
			}
			else
			{
				time = GetConVarFloat(AvASetupTime)
				FloatToString(time, timestr, sizeof(timestr))
				DispatchKeyValue(CPM, "cpm_timer_length", timestr)
			}*/
			DispatchKeyValue(CPM, "cpm_timer_team", "0")
		}
		else if(StrEqual(classname, "func_teamblocker"))
		{
			decl String:BlockTeam[2]
			//IntToString(OpTeam[DefendingTeam[g_RoundCount+1]], BlockTeam, sizeof(BlockTeam))
			DispatchKeyValue(entity, "TeamNum", BlockTeam)
		}
		else if(StrEqual(classname, "func_team_wall"))
		{
			decl String:BlockTeam[2]
			//IntToString(OpTeam[DefendingTeam[g_RoundCount+1]], BlockTeam, sizeof(BlockTeam))
			DispatchKeyValue(entity, "blockteam", BlockTeam)
		}
		else if(StrEqual(classname, "dod_capture_area") || StrEqual(classname, "dod_control_point"))
		{
			if(GetConVarInt(AllowObjectives) == 0)
			{
				AcceptEntityInput(entity, "Disable")
			}
			else
			{
				AcceptEntityInput(entity, "Enable")
			}
		}
		else if(StrEqual(classname, "dod_bomb_target") || StrEqual(classname, "dod_bomb_dispenser") || StrEqual(classname, "dod_bomb_dispenser_icon"))
		{
			if(StrEqual(classname, "dod_bomb_target"))
			{
				DispatchKeyValue(entity, "add_timer_seconds", "0")
			}
			AcceptEntityInput(entity, "Enable")
		}
	}
	else if(g_Init == 1)
	{
		if(StrEqual(classname, "dod_capture_area") || StrEqual(classname, "dod_control_point") || StrEqual(classname, "dod_bomb_target") || StrEqual(classname, "dod_bomb_dispenser") || StrEqual(classname, "dod_bomb_dispenser_icon"))
		{
			AcceptEntityInput(entity, "Disable")
		}
		else if(StrEqual(classname, "dod_control_point_master"))
		{
			DispatchKeyValue(entity, "cpm_use_timer", "0")
		}
	}
}

public Action:cmd_voice(client, args)
{
	if((g_Init == 1 || (g_Started == 1 && g_Live == 0)) && GetConVarInt(AllowVoiceCmds) == 0)
	{
		return Plugin_Handled
	}
	return Plugin_Continue
}


DealDamage(victim, damage, attacker = 0, dmg_type = DMG_GENERIC, String:weapon[]="")
{
	if(victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage > 0)
	{
		new String:dmg_str[16]
		IntToString(damage, dmg_str, 16)
		new String:dmg_type_str[32]
		IntToString(dmg_type,dmg_type_str, 32)
		new pointHurt = CreateEntityByName("point_hurt")
		if(pointHurt)
		{
			DispatchKeyValue(victim, "targetname", "killme")
			DispatchKeyValue(pointHurt, "DamageTarget", "killme")
			DispatchKeyValue(pointHurt, "Damage", dmg_str)
			DispatchKeyValue(pointHurt, "DamageType", dmg_type_str)
			if(!StrEqual(weapon, ""))
			{
				DispatchKeyValue(pointHurt, "classname", weapon)
			}
			DispatchSpawn(pointHurt)
			AcceptEntityInput(pointHurt, "Hurt", (attacker>0)?attacker:-1)
			DispatchKeyValue(pointHurt, "classname", "point_hurt")
			DispatchKeyValue(victim, "targetname", "dontkillme")
			RemoveEdict(pointHurt)
		}
	}
}

KillPlayer(client)
{
	new health = GetClientHealth(client)
	DealDamage(client, health+1, client, DMG_BULLET)
}

public Action:cmd_say(client, args)
{
	if (client > 0)
	{
		new AdminId:Admin = GetUserAdmin(client)
		if(g_Started == 1 && (Admin == INVALID_ADMIN_ID || !GetAdminFlag(Admin, Admin_Kick, Access_Effective)))
		{
			decl String:ChatText[256]
			GetCmdArg(1, ChatText, sizeof(ChatText))
			if(StrEqual(ChatText, "!medic") || StrEqual(ChatText, "!info") || StrEqual(ChatText, "!live") || StrEqual(ChatText, "!stuck") || StrEqual(ChatText, "!suicide") || StrEqual(ChatText, "*Salute*", false))
			{
				return Plugin_Continue
			}
			PrintToChat(client, "\x04Sorry, \x01Global Chat \x04is \x01DISABLED \x04!")
			return Plugin_Handled
		}
	}
	return Plugin_Continue
}

public Action:cmd_kill(client, args)
{
	if(g_Init == 1 || g_Started == 1)
	{
		return Plugin_Handled
	}
	return Plugin_Continue
}

public Action:cmdSuicide(client, args)
{
	if(g_Started == 1 && IsPlayerAlive(client))
	{
		KillPlayer(client)
	}
	return Plugin_Handled
}

public Action:cmdStuck(client, args)
{
	if(g_Started == 1 && IsPlayerAlive(client) && GetGameTime() > g_LastStuck[client] + 3.0 && GetConVarInt(AllowStuckCmd) == 1)
	{
		g_LastStuck[client] = GetGameTime()
		SlapPlayer(client, 0, true)
	}
	return Plugin_Handled
}

/*public Action:cmdInfo(client, args)
{
	new team = g_PlayerTeam[client]
	if(g_Init == 0 && (g_Started == 1 || g_Live == 1) && team > SPEC)
	{
		PrintToChat(client, "\x04Round \x01%i  \x04-  You are \x01%s \x04this round!", g_RoundCount, DefendingTeam[g_RoundCount] == team ? "DEFENDING" : "ATTACKING")
		PrintToChat(client, "\x01Scores: \x04Your Team \x01%i\x04:\x01%i \x04Enemy Team", RoundScoreTeam[g_RoundCount] == team ? Score[0] : Score[1], RoundScoreTeam[g_RoundCount] != team ? Score[0] : Score[1])
	}
	return Plugin_Handled
}*/

public Action:cmdInit(client, args)
{
	if(g_CmdsAvailable != 0)
	{
		if(g_Started == 1 || g_Init == 1)
		{
			if(GameTimer != INVALID_HANDLE)
			{
				CloseHandle(GameTimer)
				GameTimer = INVALID_HANDLE
			}
			ResetRaidBoss()
			PrintHintTextToAll("RESTARTING RaidBoss")
			PrintToChatAll("\x01RESTARTING \x04RaidBoss \x01!")
		}
		if((GetTeamClientCount(ALLIES) + GetTeamClientCount(AXIS)) < InitMinPlayers)
		{
			ReplyToCommand(client, "Sorry, at least %i active players needed to init RaidBoss!", InitMinPlayers)
			return Plugin_Handled
		}
		AllPlayersInit()
	}
	else
	{
		ReplyToCommand(client, "Please try again once the current round is active!")
	}
	return Plugin_Handled
}

stock ResetRaidBoss()
{
	ServerCommand("exec %s", INACTIVECFG)
	Call_StartForward(OnRaidBossEnded)
	Call_Finish()
	g_Live = 0
	g_Started = 0
	g_StartTime = 0.0
}
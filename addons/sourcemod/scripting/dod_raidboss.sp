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
//char g_sSounds[2][] = {"", "dod_raidboss/bfgdivision.wav"};
const MaxRoundCount = 1

new g_numBosses = 1;
new g_Boss 		= 0;
new g_Boss2 	= 0;

new Handle:LiveTime = INVALID_HANDLE;
new Handle:AllowVoiceCmds = INVALID_HANDLE
new Handle:AllowStuckCmd = INVALID_HANDLE
new Handle:GameTimer = INVALID_HANDLE
new Handle:BossHealth = INVALID_HANDLE
new g_PluginSwitched[MAXPLAYERS+1]
new g_PluginClass[MAXPLAYERS+1]
new g_Started = 0, g_Live = 0, g_Init = 0
new Float:g_StartTime = 0.0
new CPM = -1
new g_CmdsAvailable
new g_iAmmo, g_iClip1
new Float:g_LastStuck[MAXPLAYERS+1]
new Kills[MAXPLAYERS+1]
new Deaths[MAXPLAYERS+1]
new InitialTeam = ALLIES
new InitMinPlayers
new String:ChangeToMap[256]
new BossSoundClipKillTracker = 0
new BossSoundClipToPlay = 0
const MaxBossSoundClip = 13
const MaxBossMusic = 1
const MaxModels = 17
new RoundCount = 1
new Handle:OnRaidBossStarted = INVALID_HANDLE
new Handle:OnRaidBossEnded = INVALID_HANDLE
new Handle:OnRoundStart = INVALID_HANDLE
new Handle:OnRoundLive = INVALID_HANDLE
new m_iAmmo;

enum Slots
{
    Slot_Primary,
    Slot_Secondary,
    Slot_Melee,
    Slot_Grenade
};

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

new String:BossVoiceSndPath[MaxBossSoundClip][] =
{
	"dod_raidboss/bbgun.mp3",
	"dod_raidboss/call_me_santa.mp3",
	"dod_raidboss/filthy_animal.mp3",
	"dod_raidboss/have_you_been_a_good_boy.mp3",
	"dod_raidboss/hohoho.mp3",
	"dod_raidboss/im_an_eating_drinking.mp3",
	"dod_raidboss/lump_of_coal.mp3",
	"dod_raidboss/Naughty_Indeed.mp3",
	"dod_raidboss/Red_Xmas.mp3",
	"dod_raidboss/santy-dont-visit-the-funeral-homes-little-buddy.mp3",
	"dod_raidboss/Something_Special.mp3",
	"dod_raidboss/Thats_So_Naughty.mp3",
	"dod_raidboss/were-gonna-press-on-and-were-gonna-have-the-hap-hap-happiest-christmas-since-bing-crosby-tap-danced-with-danny-kaye.mp3"
}

new String:BossVoiceSnd[MaxBossSoundClip][] =
{
	"bbgun.mp3",
	"call_me_santa.mp3",
	"filthy_animal.mp3",
	"have_you_been_a_good_boy.mp3",
	"hohoho.mp3",
	"im_an_eating_drinking.mp3",
	"lump_of_coal.mp3",
	"Naughty_Indeed.mp3",
	"Red_Xmas.mp3",
	"santy-don't-visit-the-funeral-homes-little-buddy.mp3",
	"Something_Special.mp3",
	"Thats_So_Naughty.mp3",
	"we're-gonna-press-on-and-we're-gonna-have-the-hap-hap-happiest-christmas-since-bing-crosby-tap-danced-with-danny-kaye.mp3"
}

new String:BossMusicPath[1][] = {"dod_raidboss/bfgdivision.wav"};

new String:RaidbossModels[MaxModels][] = 
{
	"models/player/vad36santa/red.mdl",
	"models/player/vad36santa/blue.dx80.vtx",
	"models/player/vad36santa/blue.dx90.vtx",
	"models/player/vad36santa/blue.mdl",
	"models/player/vad36santa/blue.phy",
	"models/player/vad36santa/blue.sw.vtx",
	"models/player/vad36santa/blue.vvd",
	"models/player/vad36santa/red.dx80.vtx",
	"models/player/vad36santa/red.dx90.vtx",
	"models/player/vad36santa/red.phy",
	"models/player/vad36santa/red.sw.vtx",
	"models/player/vad36santa/red.vvd",
	"materials/models/player/vad36santa/Santa_D.vmt",
	"materials/models/player/vad36santa/Santa_D.vtf",
	"materials/models/player/vad36santa/Santa_D_B.vmt",
	"materials/models/player/vad36santa/Santa_D_B.vtf",
	"materials/models/player/vad36santa/Santa_N.vtf"
}
//##################
//# Actions
//##################

public void OnConfigsExecuted()
{

	/*char sSound[64];

	for (int i = 1; i < sizeof(g_sSounds); i++) {

		Format(sSound, sizeof(sSound), "sound/%s", g_sSounds[i]);
		PrecacheSound(g_sSounds[i]);
		AddFileToDownloadsTable(sSound);
	}
	return;*/
}

public void OnPluginStart()
{
	CreateConVar("dod_raidboss", PLUGIN_VERSION, "DoD RaidBoss", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	SetConVarString(FindConVar("dod_raidboss"), PLUGIN_VERSION)
	RegAdminCmd("sm_raidboss", RaidBoss, ADMFLAG_ROOT, "sm_raidboss");
	LoadTranslations("common.phrases.txt");
	AllowVoiceCmds = CreateConVar("dod_raidboss_allowvcmds", "0", "<1/0> = enable/disable VoiceCommands on Init/Start", FCVAR_PLUGIN, true, 0.0, true, 1.0)
	LiveTime = CreateConVar("dod_raidboss_livetime", "5", "<#> = time in minutes for live round", FCVAR_PLUGIN, true, 1.0, true, 30.0)
	BossHealth = CreateConVar("dod_raidboss_health", "6000", "<#> = Health of Bosses", FCVAR_PLUGIN, true, 1.0, false, 10000)
	HookEvent("player_team", OnJoinTeam, EventHookMode_Pre)
	HookEvent("player_death", OnPlayerDeath)
	HookEvent("player_spawn", OnPlayerSpawn)
	HookEventEx("dod_round_active", RoundActive, EventHookMode_Post)
	HookEventEx("dod_round_start", RoundStart, EventHookMode_Post)
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
	m_iAmmo = FindSendPropOffs("CDODPlayer", "m_iAmmo");
}

/*public Action:BlockStartVoice(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
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
}*/

public OnMapStart()
{
	g_Init = 0
	g_CmdsAvailable = 0
	g_Boss = 0
	g_Boss2 = 0

	if(FileExists(MATCHCFG, true))
	{
		new Handle:KeyValues = CreateKeyValues("RaidBossConfig")
		FileToKeyValues(KeyValues, MATCHCFG)
		KvRewind(KeyValues)
		if(KvJumpToKey(KeyValues, "MatchSetup"))
		{
			InitMinPlayers = KvGetNum(KeyValues, "InitMinPlayers", 0)
			g_Init = KvGetNum(KeyValues, "MapStartAutoOn", 0)
		}
		KvRewind(KeyValues)
		CloseHandle(KeyValues)
	}

	for(new i = 0; i < MaxModels; i++)
	{
		PrecacheModel(RaidbossModels[i], true)
		AddFileToDownloadsTable(RaidbossModels[i])
	}
	for(new i = 0; i < 3; i++)
	{
		PrecacheSound(AlliesAttackSnd[i], true)
		PrecacheSound(AxisDefendSnd[i], true)
	}
	char sSound[128];
	for(new i = 0; i < MaxBossSoundClip; i++)
	{
		Format(sSound, sizeof(sSound), "sound/%s", BossVoiceSndPath[i]);
		AddFileToDownloadsTable(sSound)
		PrecacheSound(BossVoiceSndPath[i], true)
	}
	for(new i = 0; i < MaxBossMusic; i++)
	{
		Format(sSound, sizeof(sSound), "sound/%s", BossMusicPath[i]);
		AddFileToDownloadsTable(sSound)
		PrecacheSound(BossMusicPath[i], true)
	}
	ResetRaidBoss()
	m_iAmmo = FindSendPropOffs("CDODPlayer", "m_iAmmo")
}

//public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
public OnPlayerSpawn(Handle:event, const String:name[], bool:Broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) <= SPEC)
	{
		return Plugin_Continue
	}
	if(g_Started == 0)
	{
		return Plugin_Continue
	}
	//GetClientAbsOrigin(client, g_PlayerSpawnPos[client])
	//g_PlayerTeam[client] = GetClientTeam(client)
	if(g_Started == 1)
	{
		SetEntProp(client, Prop_Data, "m_iDeaths", Deaths[client])
		SetEntProp(client, Prop_Data, "m_iFrags", Kills[client])
		if(GetClientTeam(client) == AXIS && IsValidClient(client))
		{
			SetEntityHealth(client, GetConVarInt(BossHealth))
			SetEntityModel(client,"models/player/vad36santa/red.mdl")
			SetEntityRenderColor(client, 255, 255, 255, 255)
			SetBossAmmo(client, Slot_Primary)
			SetBossAmmo(client, Slot_Secondary)
			SetBossAmmo(client, Slot_Grenade)
		}
	}
	//if(g_Started == 1 && g_Init == 1 && GetClientTeam(client) == AXIS)
	return Plugin_Continue
}

/*public Event_PlayerSpawn(Handle:Event, const String:Name[], bool:Broadcast)
{
	new client = GetClientOfUserId(GetEventInt(Event, "userid"));
	SetEntityModel(client,"models/player/vad36santa/red.mdl");
	SetEntityRenderColor(client, 255, 255, 255, 255);
}*/

public Event_PlayerDeath(Handle:event, const String:szName[], bool:bDontBroadcast)
{
	return Plugin_Continue
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	BossSoundClipKillTracker += 1
	if(BossSoundClipKillTracker == 5)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				EmitSoundToAll(BossVoiceSnd[BossSoundClipToPlay])
			}
		}
		BossSoundClipKillTracker = 0
		BossSoundClipToPlay += 1
		if(BossSoundClipToPlay >= MaxBossSoundClip)
		{
			BossSoundClipToPlay = 0
		}
	}
	if(client < 1 || !IsClientInGame(client) || GetClientTeam(client) <= SPEC || g_Live == 0)
	{
		return Plugin_Continue
	}
	g_PluginClass[client] = 0
	CreateTimer(1.0, SoldierDown, client, TIMER_FLAG_NO_MAPCHANGE)
	return Plugin_Continue
}

public Action:RaidBoss(int client, int args)
{
	ReplyToCommand(client, "T/Sgt. Smith's Raid Boss here!");
	return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	return Plugin_Continue
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
	{
		Call_StartForward(OnRoundStart)
		Call_Finish()
		g_Init = 0
	}
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
		else if(team == AXIS)
		{
			PrintHintText(client, "Match is LIVE, you CANNOT join the bosses team!")
			return Plugin_Handled
		}
		else if(team == ALLIES)
		{
			FakeClientCommandEx(client, "jointeam %i", ALLIES)
			PrintHintText(client, "Welcome in, go kill the bosses!")
		}
		return Plugin_Handled
	}
	if((team == ALLIES || team == AXIS) && g_Live == 0 && (g_Init == 1 || g_Started == 1))
	{
		if(g_Init == 1 && GetClientTeam(client) == g_Boss || GetClientTeam(client) == g_Boss2)
		{
			team = AXIS
		}
		else
		{
			team = ALLIES
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
		if(GetClientOfUserId(client) == g_Boss)
		{
			g_Boss = 0
		}
		if(GetClientOfUserId(client) == g_Boss2)
		{
			g_Boss2 = 0
		}
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
		PrintHintTextToAll("Round is over! The Bosses have been defeated!")
		PrintToChatAll("\x04Round is over! The Bosses have been defeated!")
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
	Format(menutitle, sizeof(menutitle), "Select Boss 1")
	SetMenuTitle(BossMenu, menutitle)
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			new currteam = GetClientTeam(i)
			//if(currteam == ALLIES)
			//{
			decl String:TargetName[32]
			GetClientName(i, TargetName, sizeof(TargetName))
			new userid = GetClientUserId(i)
			decl String:userid_str[32]
			IntToString(userid, userid_str, sizeof(userid_str))
			AddMenuItem(BossMenu, userid_str, TargetName)
			//}
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
		ChangeClientTeam(g_Boss, AXIS)
		PrintToChat(client, "\x01Player \x04%N \x01has been choosen as the \x04BOSS\x01!", target)
		if(g_numBosses == 2)
		{
			SelectBoss2(client)	
		}
		else
		{
			ConfirmBosses(client)
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
			ChangeClientTeam(g_Boss, ALLIES)
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
			//if(currteam == ALLIES)
			//{
			decl String:TargetName[32]
			GetClientName(i, TargetName, sizeof(TargetName))
			new userid = GetClientUserId(i)
			decl String:userid_str[32]
			IntToString(userid, userid_str, sizeof(userid_str))
			AddMenuItem(Boss2Menu, userid_str, TargetName)
			//}
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
		ChangeClientTeam(g_Boss2, AXIS)
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
			ChangeClientTeam(g_Boss, ALLIES)
			g_Boss = 0
			ChangeClientTeam(g_Boss2, ALLIES)
			g_Boss2 = 0
			SelectBoss(client)
		}
		else if(itemNum == MenuCancel_Exit)
		{
			if(GetClientMenu(client))
			{
				CancelClientMenu(client)
			}
			ChangeClientTeam(g_Boss, ALLIES)
			g_Boss = 0
			ChangeClientTeam(g_Boss2, ALLIES)
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
			ChangeClientTeam(g_Boss, ALLIES)
			g_Boss = 0
			ChangeClientTeam(g_Boss2, ALLIES)
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
			ChangeClientTeam(g_Boss, ALLIES)
			g_Boss = 0
			ChangeClientTeam(g_Boss2, ALLIES)
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
			g_Boss2 = 0
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
}

public Action:HandleRoundLive()
{
	g_Live = 1
	PrintToChatAll("\x04Rip and Tear!!")
	PrintHintTextToAll("Rip and Tear!!!")
				EmitSoundToAll(BossMusicPath[0], _, _, SNDVOL_NORMAL, _, _, _, _)
	ServerCommand("exec %s", LIVECFG)
	Call_StartForward(OnRoundLive);
	Call_Finish();

	new Float:livetimer = (GetConVarFloat(LiveTime)*60.0)
	GameTimer = CreateTimer(livetimer, TimerEnd, _, TIMER_FLAG_NO_MAPCHANGE)
	ZeroTimerWarmup()
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
				EmitSoundToClient(i, BossVoiceSnd[2])
			}
			//EmitSoundToAll(BossMusic[0], _, _, _, _, SNDVOL_NORMAL, _, _, _, _, _, _)
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
				//FakeClientCommand(i, "%s", team == AXIS ? "cls_k98" : "cls_garand")
			}
		}
	}
	SetConVarInt(FindConVar("mp_clan_restartround"), 1, true, false)
}

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
			DispatchKeyValue(CPM, "cpm_timer_team", "0")
		}
		else if(StrEqual(classname, "func_teamblocker"))
		{
			decl String:BlockTeam[2]
			DispatchKeyValue(entity, "TeamNum", BlockTeam)
		}
		else if(StrEqual(classname, "func_team_wall"))
		{
			decl String:BlockTeam[2]
			DispatchKeyValue(entity, "blockteam", BlockTeam)
		}
		else if(StrEqual(classname, "dod_capture_area") || StrEqual(classname, "dod_control_point"))
		{
			AcceptEntityInput(entity, "Disable")
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

stock ZeroTimerWarmup()
{
	new Float:time = (60 - (GetGameTime() - g_StartTime))
	decl String:timestr[12]
	FloatToString(time, timestr, sizeof(timestr))
	Format(timestr, sizeof(timestr), "-%s", timestr)
	SetVariantString(timestr)
	AcceptEntityInput(CPM, "AddTimerSeconds")
}

public IsValidClient( client )
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) )
        return false;

    return true;
}

stock SetBossAmmo(client, Slots:slot)
{
	
	new weapon = GetPlayerWeaponSlot(client, _:slot);
    if (IsValidEntity(weapon))
    {
        switch (GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1) * 4)
        {
            case 4:  SetEntData(client, m_iAmmo + 4,  1000); /* Colt */
            case 8:  SetEntData(client, m_iAmmo + 8,  1000); /* P38 */
            case 12: SetEntData(client, m_iAmmo + 12, 1000); /* C96 */
            case 16: SetEntData(client, m_iAmmo + 16, 1000); /* Garand */
            case 20: SetEntData(client, m_iAmmo + 20, 1000); /* K98+scoped */
            case 24: SetEntData(client, m_iAmmo + 24, 1000); /* M1 Carbine */
            case 28: SetEntData(client, m_iAmmo + 28, 1000); /* Spring */
            case 32: SetEntData(client, m_iAmmo + 32, 1000); /* Thompson, MP40 & STG44 */
            case 36: SetEntData(client, m_iAmmo + 36, 1000); /* BAR */
            case 40: SetEntData(client, m_iAmmo + 40, 1000); /* 30cal */
            case 44: SetEntData(client, m_iAmmo + 44, 1000); /* MG42 */
            case 48: SetEntData(client, m_iAmmo + 48, 1000); /* Bazooka, Panzerschreck */
            case 52: SetEntData(client, m_iAmmo + 52, 1000); /* US frag gren */
            case 56: SetEntData(client, m_iAmmo + 56, 1000); /* Stick gren */
            case 68: SetEntData(client, m_iAmmo + 68, 1000); /* US Smoke */
            case 72: SetEntData(client, m_iAmmo + 72, 1000); /* Stick smoke */
            case 84: SetEntData(client, m_iAmmo + 84, 1000); /* Riflegren US */
            case 88: SetEntData(client, m_iAmmo + 88, 1000); /* Riflegren GER */
        }
    }

}
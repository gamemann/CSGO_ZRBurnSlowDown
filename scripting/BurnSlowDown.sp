#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>

#define PL_VERSION "1.3"

public Plugin:myinfo = 
{
	name = "Burn Slow Down",
	author = "Roy (Christian Deacon), That One Guy, KyleS, and [Lickaroo Johnson McPhaley]",
	description = "Slows you down if you're being burned",
	version = PL_VERSION,
	url = "GFLClan.com & AlliedMods.net & TheDevelopingCommunity.com"
};

// ConVars
new Handle:g_hAmount = INVALID_HANDLE;
new Handle:g_hAmountEnd = INVALID_HANDLE;
new Handle:g_hEnabled = INVALID_HANDLE;
new Handle:g_hTime = INVALID_HANDLE;
new Handle:g_hProp = INVALID_HANDLE;
new Handle:g_hDebug = INVALID_HANDLE;

// ConVar Values
new Float:g_fAmount;
new Float:g_fAmountEnd;
new bool:g_bEnabled;
new Float:g_fTime;
new String:g_sProp[MAX_NAME_LENGTH];
new bool:g_bDebug;

// Other
new bool:g_bIsBurning[MAXPLAYERS+1];

public OnPluginStart() 
{
	// ConVars
	g_hAmount = CreateConVar("sm_bsd_amount", "125.0", "The amount to slow the player down?");
	g_hAmountEnd = CreateConVar("sm_bsd_amount_end", "260.0", "What to assign to the prop when the player is done burning.");
	g_hEnabled = CreateConVar("sm_bsd_enabled", "1", "Enable this plugin?");
	g_hTime = CreateConVar("sm_bsd_time", "5.0", "The time the burn damage lasts for?");
	g_hProp = CreateConVar("sm_bsd_prop", "m_flMaxspeed", "Prop to use to slow down players (don't mess with this unless you know what you're doing).");
	g_hDebug = CreateConVar("sm_bsd_debug", "0", "Enable debugging for BSD?");
	
	// AlliedMods Release
	CreateConVar("sm_bsd_version", PL_VERSION, "Burn Slow Down's plugin version");
	
	// Change these convars!
	HookConVarChange(g_hAmount, CVarChanged);
	HookConVarChange(g_hAmountEnd, CVarChanged);
	HookConVarChange(g_hTime, CVarChanged);
	HookConVarChange(g_hEnabled, CVarChanged);
	HookConVarChange(g_hProp, CVarChanged);
	HookConVarChange(g_hDebug, CVarChanged);
	
	// Auto Execute the config
	AutoExecConfig(true, "sm_BurnSlowDown");
	
	// Late loading.
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		}
	}
}

public CVarChanged(Handle:hCVar, const String:sOldV[], const String:sNewV[]) 
{
	OnConfigsExecuted();
}

public OnConfigsExecuted() 
{
	g_fAmount = GetConVarFloat(g_hAmount);
	g_bEnabled = GetConVarBool(g_hEnabled);
	g_fTime = GetConVarFloat(g_hTime);
	GetConVarString(g_hProp, g_sProp, sizeof(g_sProp));
	g_bDebug = GetConVarBool(g_hDebug);
}

public OnClientPutInServer(iClient) 
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeBurnDamage);
	SDKHook(iClient, SDKHook_PostThink, OnThink);
	g_bIsBurning[iClient] = false;
}

public OnClientDisconnect(iClient) 
{
	g_bIsBurning[iClient] = false;
}

public Action:OnTakeBurnDamage(iVictim, &iAttacker, &inflictor, &Float:damage, &damagetype) 
{
	if (iVictim > MaxClients || iVictim <= 0 || !IsClientInGame(iVictim) || !IsPlayerAlive(iVictim) || !g_bEnabled || ZR_IsClientHuman(iVictim) || !(damagetype & DMG_BURN) || g_bIsBurning[iVictim]) 
	{
		return Plugin_Continue;
	}
	
	g_bIsBurning[iVictim] = true;
	
	
	if (g_bDebug) 
	{
		PrintToChat(iVictim, "Burning started (Prop: \"%s\" and Amount: %f)...", g_sProp, g_fAmount);
		
		if (iAttacker && iAttacker <= MaxClients && IsClientInGame(iAttacker))
		{
			PrintToChat(iAttacker, "Burning started (Prop: \"%s\" and Amount: %f)...", g_sProp, g_fAmount);
		}
	}
	
	SetEntPropFloat(iVictim, Prop_Send, g_sProp, g_fAmount);
	CreateTimer(g_fTime, Timer_DisableSlowDown, iVictim, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public OnThink (iClient) 
{
	if (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && g_bIsBurning[iClient] && StrEqual(g_sProp, "m_flStamina") && !ZR_IsClientHuman(iClient)) {
		new Float:i = GetEntPropFloat(iClient, Prop_Send, "m_flStamina");
		
		if (i <= 0.0) 
		{
			SetEntPropFloat(iClient, Prop_Send, g_sProp, g_fAmount);
			
			if (g_bDebug) 
			{
				PrintToChat(iClient, "You were in the air! Stamina reset (Amount: %f)", g_fAmount);
			}
		}
	}
}

public Action:Timer_DisableSlowDown(Handle:hTimer, any:iVictim) 
{
	if (IsClientInGame(iVictim)) 
	{
		SetEntPropFloat(iVictim, Prop_Send, g_sProp, g_fAmountEnd);
		
		if (g_bDebug) 
		{
			PrintToChat(iVictim, "Burning Ended (Amount End: %f)...", g_fAmountEnd);
		}
	}
	g_bIsBurning[iVictim] = false;
}
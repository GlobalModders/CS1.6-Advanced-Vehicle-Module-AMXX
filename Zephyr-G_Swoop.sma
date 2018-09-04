#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>

#define PLUGIN "Zephyr-G Swoop"
#define VERSION "1.0"
#define AUTHOR "GlobalModders.net"

#define VEHICLE_BASESPEED 400.0
#define VEHICLE_MAXSPEED 650.0

#define VEHICLE_CLASSNAME "vehicle_newgen"
#define MODEL_VEHICLE "models/swooper.mdl"
#define MODEL_ANIMATION "models/Anim_Riding.mdl"

new const VehicleSounds[5][] = 
{
	"Vehicle/VehicleIdle.wav",
	"Vehicle/VehicleStart.wav",
	"Vehicle/VehicleLoop.wav",
	"Vehicle/VehicleLoopBoost.wav",
	"Vehicle/VehicleStop.wav"
}

// Camera
#define CAMERA_CLASSNAME "Olympus_OM4"
#define CAMERA_MODEL "models/winebottle.mdl"

new g_ViewCamera, g_MyCamera[33], Float:g_CameraOrigin[33][3]

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

// OffSet
#define PDATA_SAFE 2
#define OFFSET_LINUX 5
#define OFFSET_CSTEAMS 114
const OFFSET_CSDEATHS = 444
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX_WEAPONS = 4 // weapon offsets are only 4 steps higher on Linux			
			
// Vars
new g_AnimEnt[33], g_AvtEnt[33], g_Controlled[33], g_MoveEnt[33], g_SpeedBoost[33], g_SprId_LaserBeam
new Float:g_DroppingSpeed[33], Float:g_VehicleSpeed[33], Float:SoundDelay[33], g_Fire_SprID, 
Float:SoundEnd[33], Float:SoundRun[33], Float:g_ButtonDelay[33], Float:g_FireDelay[33]

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	
	register_clcmd("say /get", "Test")
}

public plugin_precache()
{
	precache_model(MODEL_VEHICLE)
	precache_model(MODEL_ANIMATION)
	
	precache_model(CAMERA_MODEL)
	
	for(new i = 0; i < sizeof(VehicleSounds); i++)
		precache_sound(VehicleSounds[i])
		
	g_Fire_SprID = precache_model("sprites/fire_cannon.spr")
	g_SprId_LaserBeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}
// Them code len them` nhu trong zombie giant
public Test(id)
{
	static Float:Origin[3], Float:Angles[3]

	Origin[0] = -294.039764
	Origin[1] = -1797.813964
	Origin[2] = -284.0
	
	//Angles[0] = 10.0
	Angles[1] = 90.0
	//Angles[2] = 0.0
	
	Vehicle_Create(Origin, Angles)
}

public Event_NewRound()
{
	for(new i = 0; i < get_maxplayers(); i++)
	{
		if(!is_user_connected(i))
			continue
			
		Vehicle_Reset(i)
	}
}

public client_PreThink(id)
{
	if(!is_user_alive(id))
		return
		
	static Button; Button = pev(id, pev_button)
	if(Button & IN_USE)
	{
		if(get_gametime() - 0.25 > g_ButtonDelay[id])
		{
			Button_E(id)
			g_ButtonDelay[id] = get_gametime()
		}
	}
		
	// Handle Camera
	if(g_MyCamera[id] && Get_BitVar(g_ViewCamera, id))
	{
		if(pev_valid(g_MyCamera[id]))
		{
			static Float:fVecPlayerOrigin[3], Float:fVecCameraOrigin[3], 
			Float:fVecAngles[3], Float:fVecBack[3]
		
			pev(id, pev_origin, fVecPlayerOrigin)
			pev(id, pev_view_ofs, fVecAngles)
			
			fVecPlayerOrigin[2] += fVecAngles[2]
			pev(id, pev_v_angle, fVecAngles)
		
			angle_vector(fVecAngles, ANGLEVECTOR_FORWARD, fVecBack)
		
			fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (-fVecBack[0] * 150.0)
			fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (-fVecBack[1] * 150.0)
			fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (-fVecBack[2] * 150.0)
		
			engfunc(EngFunc_TraceLine, fVecPlayerOrigin, fVecCameraOrigin, IGNORE_MONSTERS, id, 0)
			static Float:flFraction; get_tr2(0, TR_flFraction, flFraction)
		    
			if(flFraction != 1.0)
			{
				flFraction *= 150.0
				
				fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (-fVecBack[0] * flFraction)
				fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (-fVecBack[1] * flFraction)
				fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (-fVecBack[2] * flFraction)
			}
			
			set_pev(g_MyCamera[id], pev_origin, fVecCameraOrigin)
			set_pev(g_MyCamera[id], pev_angles, fVecAngles)
		} else {
			g_MyCamera[id] = 0
		}
	}
	
	if(g_Controlled[id])
	{
		if(!pev_valid(g_Controlled[id]))
		{
			g_Controlled[id] = 0
			return
		}
		
		static Button; Button = get_user_button(id)
		static OldButton; OldButton = get_user_oldbutton(id)
		
		if(get_gametime() - 5.0 > SoundDelay[id])
		{
			emit_sound(g_Controlled[id], CHAN_BODY, VehicleSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			SoundDelay[id] = get_gametime()
		}
		
		if(get_gametime() - 0.05 > g_FireDelay[id])
		{
			Create_Fire(g_Controlled[id])
			g_FireDelay[id] = get_gametime()
		}
		
		static Float:Vel[3]; pev(g_MoveEnt[id], pev_velocity, Vel)
		client_print(id, print_center, "Current Speed: %i", floatround(vector_length(Vel) / 1.89))
			
		if(Button & IN_FORWARD)
		{
			if(!(OldButton & IN_FORWARD))
			{
				// Beam
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_BEAMFOLLOW)
				write_short(id)
				write_short(g_SprId_LaserBeam)
				write_byte(1)
				write_byte(3)
				write_byte(244)
				write_byte(120)
				write_byte(120)
				write_byte(150)
				message_end()
				
				SoundEnd[id] = get_gametime() + 1.0;
				SoundRun[id] = get_gametime() - 3.8;
				
				emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				Play_Animation(g_AnimEnt[id], 1, 1.0)
			}
			
			static Float:AverageSpeed; AverageSpeed = VEHICLE_BASESPEED
				
			if(Button & IN_DUCK)
			{
				if(!g_SpeedBoost[id])
				{
					g_SpeedBoost[id] = 1;
					
					emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					SoundRun[id] = get_gametime()
				}
				
				if(get_gametime() - 4.4 > SoundRun[id])
				{
					emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					SoundRun[id] = get_gametime()
				}
				
				if(g_VehicleSpeed[id] < VEHICLE_MAXSPEED)
				{
					g_VehicleSpeed[id] += 5.0;
					if(g_VehicleSpeed[id] > VEHICLE_MAXSPEED)
						g_VehicleSpeed[id] = VEHICLE_MAXSPEED
				}
			} else {
				if(g_SpeedBoost[id])
				{
					g_SpeedBoost[id] = 0
					
					emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					SoundRun[id] = get_gametime()
				}
				
				if(get_gametime() - 4.4 > SoundRun[id])
				{
					emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					SoundRun[id] = get_gametime()
				}
				
				
				if(g_VehicleSpeed[id] < AverageSpeed)
				{
					g_VehicleSpeed[id] += 5.0;
					if(g_VehicleSpeed[id] > AverageSpeed)
						g_VehicleSpeed[id] = AverageSpeed
				} else if(g_VehicleSpeed[id] > AverageSpeed) {
					g_VehicleSpeed[id] -= 2.5;
					if(g_VehicleSpeed[id] < AverageSpeed)
						g_VehicleSpeed[id] = AverageSpeed
				}
			}
			
			if((Button & IN_MOVELEFT) && (Button & IN_MOVERIGHT))
			{
				Vehicle_Move(id, g_MoveEnt[id], 1, 0)
			} else if(Button & IN_MOVELEFT) {
				Vehicle_Move(id, g_MoveEnt[id], 1, -1)
			} else if(Button & IN_MOVERIGHT) {
				Vehicle_Move(id, g_MoveEnt[id], 1, 1)
			} else {
				Vehicle_Move(id, g_MoveEnt[id], 1, 0)
			}
		} else if(Button & IN_BACK) {
			//if(!(OldButton & IN_BACK))
			//	Play_Animation(g_AnimEnt[id], 1, 1.0)
			
			static Float:AverageSpeed; AverageSpeed = VEHICLE_BASESPEED
				
			if(g_VehicleSpeed[id] < AverageSpeed)
			{
				g_VehicleSpeed[id] += 5.0;
			}
			
			if((Button & IN_MOVELEFT) && (Button & IN_MOVERIGHT))
			{
				Vehicle_Move(id, g_MoveEnt[id], 0, 0)
			} else if(Button & IN_MOVELEFT) {
				Vehicle_Move(id, g_MoveEnt[id], 0, -1)
			} else if(Button & IN_MOVERIGHT) {
				Vehicle_Move(id, g_MoveEnt[id], 0, 1)
			} else {
				Vehicle_Move(id, g_MoveEnt[id], 0, 0)
			}
		} else {
			if(g_VehicleSpeed[id] > 0.0)
			{
				g_VehicleSpeed[id] -= 5.0;
				if(g_VehicleSpeed[id] < 0.0)
					g_VehicleSpeed[id] = 0.0
			}
			
			if((OldButton & IN_FORWARD))
			{
				if(get_gametime() >= SoundEnd[id])
					emit_sound(g_Controlled[id], CHAN_ITEM, VehicleSounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				Play_Animation(g_AnimEnt[id], 0, 1.0)
			}
			
			if((OldButton & IN_BACK))
			{
				Play_Animation(g_AnimEnt[id], 0, 1.0)
			}
		}
		
		static Float:Origin[3], Float:Angles[3]
		
		pev(g_MoveEnt[id], pev_origin, Origin)
		pev(g_MoveEnt[id], pev_angles, Angles)
		pev(g_MoveEnt[id], pev_velocity, Vel)
		
		set_pev(g_Controlled[id], pev_origin, Origin)
		set_pev(g_Controlled[id], pev_angles, Angles)
		set_pev(g_Controlled[id], pev_velocity, Vel)
	
		Origin[2] += 30.0
		
		set_pev(g_AnimEnt[id], pev_origin, Origin)
		set_pev(g_AnimEnt[id], pev_angles, Angles)
		set_pev(g_AnimEnt[id], pev_velocity, Vel)
		
		set_pev(id, pev_origin, Origin)
	}
}

public Create_Fire(Ent)
{
	static Float:Origin[3], Float:Origin2[3]
	
	Get_Position(Ent, -50.0, -8.0, 3.0, Origin)
	Get_Position(Ent, -50.0, 8.0, 3.0, Origin2)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Fire_SprID)
	write_byte(2)
	write_byte(60)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES)
	message_end()	
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin2[0])
	engfunc(EngFunc_WriteCoord, Origin2[1])
	engfunc(EngFunc_WriteCoord, Origin2[2])
	write_short(g_Fire_SprID)
	write_byte(2)
	write_byte(60)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES)
	message_end()	
}

public Vehicle_Move(id, Ent, Forward, Side)
{
	static Float:Origin[3], Float:Target[3], Float:Vel[3], Float:Angles[3]
	static Float:Speed, Float:CurVel[3]
	
	Speed = g_VehicleSpeed[id]

	if(Forward)
	{
		// Speed
		pev(Ent, pev_velocity, CurVel)
		pev(Ent, pev_origin, Origin)
		Get_Position(Ent, 48.0, 0.0, 0.0, Target)
		Get_SpeedVector(Origin, Target, Speed, Vel)
		
		if(!(pev(Ent, pev_flags) & FL_ONGROUND))
		{
			if(g_DroppingSpeed[id] < VEHICLE_MAXSPEED)
				g_DroppingSpeed[id] += 4.0
			
			Vel[2] = -g_DroppingSpeed[id]
		} else {
			g_DroppingSpeed[id] = 0.0
			Vel[2] = CurVel[2]
		}
		
		set_pev(Ent, pev_velocity, Vel)
		
		// Turn
		pev(Ent, pev_angles, Angles)
		static Float:Turn
		
		Turn = (Speed / 2.0) * VEHICLE_MAXSPEED
		if(Turn > 2.0) Turn = 2.0;
		else if(Turn < 0.5) Turn = 0.5;
		
		if(!(pev(Ent, pev_flags) & FL_ONGROUND))
		Turn = 0.25;
		
		if(Side == -1) // Left
		{
			if(Angles[2] > -5.0)
				Angles[2] -= 1.0;

			Angles[1] += Turn
			set_pev(Ent, pev_angles, Angles)
		} else if(Side == 1) { // Right
			if(Angles[2] < 5.0)
				Angles[2] += 1.0;
				
			Angles[1] -= Turn
			set_pev(Ent, pev_angles, Angles)
		} else {
			if(Angles[2] != 0.0)
			{
				if(Angles[2] > 0.0)
				{
					Angles[2] -= 1.0;
				} else if(Angles[2] < 0.0) {
					Angles[2] += 1.0;
				}
				set_pev(Ent, pev_angles, Angles)
			}
		}
	} else {
		// Vel
		pev(Ent, pev_origin, Origin)
		Get_Position(Ent, -48.0, 0.0, 0.0, Target)
		Get_SpeedVector(Origin, Target, Speed / 2.0, Vel)
		
		if(!(pev(Ent, pev_flags) & FL_ONGROUND))
		{
			if(g_DroppingSpeed[id] < VEHICLE_MAXSPEED)
				g_DroppingSpeed[id] += 4.0
			
			Vel[2] = -g_DroppingSpeed[id]
		} else {
			g_DroppingSpeed[id] = 0.0
			Vel[2] = CurVel[2]
		}
		
		set_pev(Ent, pev_velocity, Vel)
		
		// Turn
		pev(Ent, pev_angles, Angles)
		static Float:Turn
		
		Turn = (Speed / 1.0) * VEHICLE_MAXSPEED
		if(Turn > 1.0) Turn = 1.0;
		else if(Turn < 0.25) Turn = 0.25;
		
		if(!(pev(Ent, pev_flags) & FL_ONGROUND))
			Turn = 0.25;
		
		if(Side == -1) // Left
		{
			Angles[1] -= Turn
			set_pev(Ent, pev_angles, Angles)
		} else if(Side == 1) { // Right
			Angles[1] += Turn
			set_pev(Ent, pev_angles, Angles)
		}
	}
}

public Button_E(id)
{
	static Body, Target
	get_user_aiming(id, Target, Body, 64);
	
	if(pev_valid(g_Controlled[id]))
	{
		if(pev(g_Controlled[id], pev_iuser1))
			Vehicle_GetDown(id, g_Controlled[id])
	} else {
		if(pev_valid(Target))
		{
			static Classname[32]; pev(Target, pev_classname, Classname, 31)
			if(equal(Classname, VEHICLE_CLASSNAME))
				Vehicle_GetUp(id, Target)
		}
	}
}

public Vehicle_GetUp(id, Ent)
{
	if(!pev(Ent, pev_iuser1)) // No one is riding
	{
		g_Controlled[id] = Ent
		g_VehicleSpeed[id] = 0.0
		
		set_pev(id, pev_solid, SOLID_NOT)
		set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
		set_entity_visibility(id, 0)
		
		engclient_cmd(id, "weapon_knife")
		
		// Create
		Create_AnimationEnt(id)
		Create_AvatarEnt(id)
		
		// Go
		static Float:Origin[3], Float:Angles[3]
		pev(id, pev_origin, Origin)
		set_pev(g_AnimEnt[id], pev_origin, Origin)
		pev(Ent, pev_origin, Origin); Origin[2] += 30.0
		pev(Ent, pev_angles, Angles)
		set_pev(g_AnimEnt[id], pev_origin, Origin)
		set_pev(g_AnimEnt[id], pev_angles, Angles)
		
		set_pev(g_AvtEnt[id], pev_aiment, g_AnimEnt[id])
		
		Play_Animation(g_AnimEnt[id], 0, 1.0)
		set_entity_visibility(g_AvtEnt[id], 1)
		set_pev(Ent, pev_iuser1, id)
		
		View_Camera(id, 0)
		
		// Create Special Entity
		pev(Ent, pev_origin, Origin)
		pev(Ent, pev_angles, Angles)
		
		if(!pev_valid(g_MoveEnt[id]))
			g_MoveEnt[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
			
		set_pev(g_MoveEnt[id], pev_origin, Origin)
		set_pev(g_MoveEnt[id], pev_angles, Angles)
		
		set_pev(g_MoveEnt[id], pev_classname, "movement_ent")
		engfunc(EngFunc_SetModel, g_MoveEnt[id], MODEL_VEHICLE)
		set_pev(g_MoveEnt[id], pev_solid, SOLID_BBOX)
		
		set_pev(Ent, pev_solid, SOLID_NOT)
		set_entity_visibility(g_MoveEnt[id], 0)
	
		set_pev(g_MoveEnt[id], pev_movetype, MOVETYPE_PUSHSTEP)
		set_pev(g_MoveEnt[id], pev_gravity, 1.0)
		set_pev(g_MoveEnt[id], pev_gamestate, 1)
	
		static Float:Maxs[3], Float:Mins[3]
		Maxs[0] = 30.0; Maxs[1] = 30.0; Maxs[2] = 36.0
		Mins[0] = -30.0; Mins[1] = -30.0; Mins[2] = 0.0;
		entity_set_size(g_MoveEnt[id], Mins, Maxs)
	
		drop_to_floor(g_MoveEnt[id])
	}
}

public Vehicle_GetDown(id, Ent)
{
	g_Controlled[id] = 0
	
	set_pev(Ent, pev_iuser1, 0)
	set_pev(id, pev_solid, SOLID_SLIDEBOX)
	set_pev(id, pev_movetype, MOVETYPE_WALK)
	
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	Origin[2] += 100.0;
	set_pev(id, pev_origin, Origin)
	
	set_entity_visibility(id, 1)
	set_entity_visibility(g_AvtEnt[id], 0)
	
	set_pev(Ent, pev_solid, SOLID_BBOX)
	set_pev(g_MoveEnt[id], pev_solid, SOLID_NOT)	
	
	static Float:Vel[3]; set_pev(Ent, pev_velocity, Vel)
	
	View_Camera(id, 1)
}

public Vehicle_Reset(id)
{
	if(pev_valid(g_Controlled[id]))
	{
		static Ent; Ent = g_Controlled[id];
		
		g_Controlled[id] = 0;
		
		set_pev(Ent, pev_iuser1, 0)
		set_pev(Ent, pev_solid, SOLID_BBOX)
		set_pev(g_MoveEnt[id], pev_solid, SOLID_NOT)
	
		set_entity_visibility(g_AvtEnt[id], 0)
		View_Camera(id, 1)
	}
}
	
public Create_Camera(id)
{
	if(pev_valid(g_MyCamera[id]))
		return
	
	static Float:vAngle[3], Float:Angles[3]
	
	pev(id, pev_origin, g_CameraOrigin[id])
	pev(id, pev_v_angle, vAngle)
	pev(id, pev_angles, Angles)

	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return

	set_pev(Ent, pev_classname, CAMERA_CLASSNAME)

	set_pev(Ent, pev_solid, 0)
	set_pev(Ent, pev_movetype, MOVETYPE_NOCLIP)
	set_pev(Ent, pev_owner, id)
	
	engfunc(EngFunc_SetModel, Ent, CAMERA_MODEL)

	static Float:Mins[3], Float:Maxs[3]
	
	Mins[0] = -1.0
	Mins[1] = -1.0
	Mins[2] = -1.0
	Maxs[0] = 1.0
	Maxs[1] = 1.0
	Maxs[2] = 1.0

	entity_set_size(Ent, Mins, Maxs)

	set_pev(Ent, pev_origin, g_CameraOrigin[id])
	set_pev(Ent, pev_v_angle, vAngle)
	set_pev(Ent, pev_angles, Angles)

	fm_set_rendering(Ent, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
	g_MyCamera[id] = Ent;
}

public View_Camera(id, Reset)
{
	if(!is_valid_ent(g_MyCamera[id]))
		Create_Camera(id)
	
	if(!Reset) 
	{
		attach_view(id, g_MyCamera[id])
		Set_BitVar(g_ViewCamera, id)
	} else {
		attach_view(id, id)
		UnSet_BitVar(g_ViewCamera, id)
	}
}

public Vehicle_Create(Float:Origin[3], Float:Angles[3])
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_v_angle, Angles)
	
	set_pev(Ent, pev_classname, VEHICLE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, MODEL_VEHICLE)
	set_pev(Ent, pev_solid, SOLID_BBOX)

	set_pev(Ent, pev_movetype, MOVETYPE_NOCLIP)
	set_pev(Ent, pev_gravity, 1.0)
	set_pev(Ent, pev_gamestate, 1)
	set_pev(Ent, pev_iuser1, 0) // Rider
    
	static Float:Maxs[3], Float:Mins[3]
	Maxs[0] = 30.0; Maxs[1] = 30.0; Maxs[2] = 36.0
	Mins[0] = -30.0; Mins[1] = -30.0; Mins[2] = 0.0;
	entity_set_size(Ent, Mins, Maxs)
	set_pev(Ent, pev_mins, Mins)
	set_pev(Ent, pev_maxs, Maxs)
	
	drop_to_floor(Ent)
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 1.5)
}


public fw_Item_Deploy_Post(weapon_ent)
{
	new owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	if (!is_user_alive(owner))
		return;
	
	new CSWID; CSWID = cs_get_weapon_id(weapon_ent)
	if(pev_valid(g_Controlled[owner]))
	{
		if(CSWID != CSW_KNIFE)
			engclient_cmd(owner, "weapon_knife")
	}
}

public Create_AnimationEnt(id)
{
	if(!pev_valid(g_AnimEnt[id])) 
		g_AnimEnt[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

	set_pev(g_AnimEnt[id], pev_classname, "AnimeEnt")
	set_pev(g_AnimEnt[id], pev_owner, id)
	set_pev(g_AnimEnt[id], pev_movetype, MOVETYPE_NOCLIP)
	set_pev(g_AnimEnt[id], pev_gravity, 1.0)
	
	engfunc(EngFunc_SetModel, g_AnimEnt[id], MODEL_ANIMATION)
	engfunc(EngFunc_SetSize, g_AnimEnt[id], {-16.0, -16.0, 0.0}, {16.0, 16.0, 72.0})
	
	set_pev(g_AnimEnt[id], pev_solid, SOLID_NOT)
	set_pev(g_AnimEnt[id], pev_nextthink, get_gametime() + 0.1)
}

public Create_AvatarEnt(id)
{
	if(!pev_valid(g_AvtEnt[id])) 
		g_AvtEnt[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

	set_pev(g_AvtEnt[id], pev_classname, "AvatarEnt")
	set_pev(g_AvtEnt[id], pev_owner, id)
	set_pev(g_AvtEnt[id], pev_movetype, MOVETYPE_FOLLOW)
	set_pev(g_AvtEnt[id], pev_solid, SOLID_NOT)

	// Set Model
	static PlayerModel[64]
	cs_get_user_model(id, PlayerModel, sizeof(PlayerModel))
	
	format(PlayerModel, sizeof(PlayerModel), "models/player/%s/%s.mdl", PlayerModel, PlayerModel)
	engfunc(EngFunc_SetModel, g_AvtEnt[id], PlayerModel)	
	
	// Set Avatar
	set_pev(g_AvtEnt[id], pev_body, pev(id, pev_body))
	set_pev(g_AvtEnt[id], pev_skin, pev(id, pev_skin))
	
	set_pev(g_AvtEnt[id], pev_renderamt, pev(id, pev_renderamt))
	static Float:Color[3]; pev(id, pev_rendercolor, Color)
	set_pev(g_AvtEnt[id], pev_rendercolor, Color)
	set_pev(g_AvtEnt[id], pev_renderfx, pev(id, pev_renderfx))
	set_pev(g_AvtEnt[id], pev_rendermode, pev(id, pev_rendermode))
	
	set_entity_visibility(g_AvtEnt[id], 0)
}

stock Play_Animation(index, sequence, Float:framerate = 1.0)
{
	entity_set_float(index, EV_FL_animtime, get_gametime())
	entity_set_float(index, EV_FL_frame, 0.0)
	entity_set_float(index, EV_FL_framerate,  framerate)
	entity_set_int(index, EV_INT_sequence, sequence)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(ent) != PDATA_SAFE)
		return -1;
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);
}

stock Get_Position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	if(!pev_valid(ent))
		return
		
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_angles, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= (num * 2.0)
	new_velocity[1] *= (num * 2.0)
	new_velocity[2] *= (num / 2.0)
}  
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/

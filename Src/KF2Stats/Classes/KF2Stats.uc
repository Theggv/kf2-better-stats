class KF2Stats extends Info
	dependson (Stats_EventLogger)
    config(KF2Stats);

const LatestVersion = 3;

var public config int			Version;
var public config E_LogLevel	LogLevel;

var public Stats_Tracker 		Stats;
var public Stats_EventLogger 	EventLog;

var private OnlineSubsystem 	OS;
var private string				ServerAddress;
var private bool 				IsLevelChangeInProgress;

public simulated function bool SafeDestroy() {
	`Log_Trace();

	`log("[KF2Stats] SafeDestroy");

	return (bPendingDelete || bDeleteMe || Destroy());
}

event Tick(float dt) {
	if (WorldInfo.Game == None) return;

	if (!IsLevelChangeInProgress && WorldInfo.Game.bLevelChange) {
		IsLevelChangeInProgress = true;
		OnMapChange();
	}
}

private function OnMapChange() {
	local int SessionId;
	local array<byte> Payload;
	local API_SessionService service;

	SessionId = Stats.GameSession.SessionId;
	Payload = EventLog.Serialize(SessionId);

	service = class'API_SessionService'.static.GetInstance();
	service.UploadDemo(Payload);

	`Log("[KF2Stats] Uploading Demo");
}

public event PreBeginPlay() {
	`Log_Trace();

	if (WorldInfo.NetMode == NM_Client) {
		`Log_Fatal("Wrong NetMode:" @ WorldInfo.NetMode);
		SafeDestroy();
		return;
	}

	foreach WorldInfo.DynamicActors(class'Stats_EventLogger', EventLog) {
		break;
	}

	if (EventLog == None) {
		EventLog = Spawn(class'Stats_EventLogger');
	}

	foreach WorldInfo.DynamicActors(class'Stats_Tracker', Stats) {
		break;
	}

	if (Stats == None) {
		Stats = Spawn(class'Stats_Tracker');
	}

	Super.PreBeginPlay();

	PreInit();
}

private function PreInit() {
	if (Version == `NO_CONFIG) {
		LogLevel = LL_Info;
		SaveConfig();
	}

	class'BackendConfig'.static.InitConfig(Version, LatestVersion);

	if (LatestVersion != Version) {
		Version = LatestVersion;
		SaveConfig();
	}

	OS = class'GameEngine'.static.GetOnlineSubsystem();
}

public event PostBeginPlay() {
	`Log_Trace();

	if (bPendingDelete || bDeleteMe) return;

	Super.PostBeginPlay();

	PostInit();
}

function PostInit() {
	`Log_Trace();

	if (WorldInfo.Game == None || WorldInfo.GRI == None) {
		SetTimer(0.2, false, nameof(PostInit));
		return;
	}

	Spawn(class'API_ResolveIPService');
	Spawn(class'API_SessionService');
	Spawn(class'API_StatsService');
	Spawn(Class'Stats_EventLogger');
	
	GetServerAddress();
}

function NotifyLogin(Controller C) {
	local PlayerController PC;
	local PlayerReplicationInfo PRI;
	local Stats_EventLogger.DemoEventStruct DemoEvent;
	
	if (C == None || C.PlayerReplicationInfo == None) return;

	PRI = C.PlayerReplicationInfo;

	if (EventLog.Players.Find('Uid', PRI.UniqueId.Uid) == INDEX_NONE) {
		EventLog.Players.AddItem(PRI.UniqueId);
	}

	PC = PlayerController(C);

	if (PC == None) return;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_PLAYER_JOIN);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.ResolvePlayerIndex(PRI.UniqueId));

	if (!PC.bIsEosPlayer) {
		DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, 1);
		DemoEvent.Buffer = EventLog.WriteString(DemoEvent.Buffer, OS.UniqueNetIdToInt64(PRI.UniqueId));
	} else {
		DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, 2);
		DemoEvent.Buffer = EventLog.WriteString(DemoEvent.Buffer, OS.UniqueNetIdToString(PRI.UniqueId));
	}

	EventLog.AddEvent(DemoEvent);
}

function NotifyLogout(Controller C) {
	local PlayerReplicationInfo PRI;
	local Stats_EventLogger.DemoEventStruct DemoEvent;
	
	if (C == None || C.PlayerReplicationInfo == None) return;

	PRI = C.PlayerReplicationInfo;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_PLAYER_DISCONNECT);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.ResolvePlayerIndex(PRI.UniqueId));

	EventLog.AddEvent(DemoEvent);
}

function NetDamage(
	int OriginalDamage,
	out int Damage, 
	Pawn Injured, 
	Controller InstigatedBy, 
	vector HitLocation, 
	out vector Momentum, 
	class<DamageType> DamageType, 
	Actor DamageCauser
) {
	if (InstigatedBy == None) return;

	// Detect fleshpound rage from husk backback
	if (KFPlayerController(InstigatedBy) != None &&
		KFPawn_ZedFleshpound(Injured) != None &&
		DamageType == class'KFDT_Explosive_HuskSuicide'
	) {
		DetectFPRageFromHuskBP(Damage, KFPawn_ZedFleshpound(Injured), KFPlayerController(InstigatedBy));
	}

	// Detect husk backback kill
	if (KFPlayerController(InstigatedBy) != None &&
		KFPawn_ZedHusk(Injured) != None && Damage == 10000
	) {
		Stats.AddEvent(KFPlayerController(InstigatedBy), ET_HUSK_BACKPACK);
	}
}

// detection method from phanta's cd chokepoints
private function DetectFPRageFromHuskBP(
	int Damage, 
	KFPawn_ZedFleshpound Injured, 
	KFPlayerController InstigatedBy
) {
	local KFAIController_ZedFleshpound AI;
	local KFAIPluginRage_Fleshpound RagePlugin;
	local DamageModifierInfo DamageModifier;
	local float mp;

	AI = KFAIController_ZedFleshpound(Injured.Controller);
	if (AI == None) return;

	RagePlugin = AI.RagePlugin;

	if (RagePlugin == None) return;
	if (RagePlugin.bIsEnraged) return;

	mp = 1.0;
	foreach class'KFPawn_ZedFleshpound'.default.DamageTypeModifiers(DamageModifier) {
		if (DamageModifier.DamageType != class'KFDT_Explosive') continue;

		mp = DamageModifier.DamageScale[0];
	}

	if (float(RagePlugin.AccumulatedDOT) + float(Damage) * mp < RagePlugin.RageDamageThreshold) return;

	Stats.AddEvent(InstigatedBy, ET_RAGED_BY_BP);
}

function CreateSession() {
	local API_SessionService service;

	Stats.GameSession.GameDifficulty = GetGameDifficulty();
	Stats.GameSession.GameLength = GetGameLength();
	Stats.GameSession.GameMode = GetGameMode();

	service = class'API_SessionService'.static.GetInstance();
	service.OnCreateSessionCompleted = OnCreateSessionCompleted;
	service.OnCreateSessionFailed = OnCreateSessionFailed;

	service.CreateSession(
		GetServerName(), ServerAddress,
		Caps(WorldInfo.GetMapName(true)),
		Stats.GameSession.GameDifficulty, 
		Stats.GameSession.GameLength, 
		Stats.GameSession.GameMode
	);
}

private function string GetServerName() {
	return WorldInfo.Game.GameReplicationInfo.ServerName;
}

private function GetServerAddress() {
	local API_ResolveIPService service;

	service = class'API_ResolveIPService'.static.GetInstance();
	service.OnGetPublicIPCompleted = OnGetPublicIPCompleted;
	service.GetPublicIP();
}

private function OnGetPublicIPCompleted(string Address) {
	local string AddressUrl;
	local array<string> UrlParts;

	AddressUrl = WorldInfo.GetAddressURL();
	
	if (InStr(AddressUrl, ":") > INDEX_NONE) {
		UrlParts = SplitString(AddressUrl, ":", false);
	}

	UrlParts[0] = Address;

	if (UrlParts[1] == "") {
		UrlParts[1] = "7777";
	}

	ServerAddress = UrlParts[0] $ ":" $ UrlParts[1];

	CreateSession();
}

private function OnCreateSessionCompleted(int Id) {
	Stats.GameSession.SessionId = Id;
}

private function OnCreateSessionFailed() {
	Stats.GameSession.SessionCreationAttempt += 1;

	if (Stats.GameSession.SessionCreationAttempt <= 3) {
		SetTimer(2.0 * Stats.GameSession.SessionCreationAttempt, false, nameof(CreateSession));
	}
}

private function int GetGameDifficulty() {
	return int(WorldInfo.Game.GameDifficulty) + 1;
}

private function int GetGameLength() {
	return KFGameInfo(WorldInfo.Game).MyKFGRI.WaveMax - 1;
}

private function int GetGameMode() {
	local KFGameInfo KFGI;

	KFGI = KFGameInfo(WorldInfo.Game);

	if (KFGI == None) return 0;

	// CD Support
	if (KFGI.IsA('CD_Survival')) return 3;

	// Default modes
	if (KFGameInfo_Endless(KFGI) != None) return 2;
	if (KFGameInfo_WeeklySurvival(KFGI) != None) return 4;
	if (KFGameInfo_Objective(KFGI) != None) return 5;
	if (KFGameInfo_VersusSurvival(KFGI) != None) return 6;

	if (KFGameInfo_Survival(KFGI) != None) return 1;

	return 0;
}

defaultproperties {
}
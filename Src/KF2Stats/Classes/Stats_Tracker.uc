class Stats_Tracker extends Info
	dependson (API_StatsServiceBase, Stats_EventLogger);

enum EventType {
	ET_HUSK_BACKPACK,
	ET_RAGED_BY_BP
};

enum SessionStatus {
	SESSION_STATUS_LOBBY,
	SESSION_STATUS_INPROGRESS,
	SESSION_STATUS_WON,
	SESSION_STATUS_LOST,
};

struct SessionStruct {
	var int GameMode;
	var int GameLength;
	var int GameDifficulty;
	var SessionStatus GameStatus;

	var int SessionCreationAttempt;
	var int SessionId;

	var int Wave;
	var bool IsActive;
	var float WaveStartedAt;
	var int ZedsLeft;

	var float ZedTimeDuration;
	var int ZedTimeCount;

	structdefaultproperties {
		GameMode = 0
		GameLength = 0
		GameDifficulty = 0
		GameStatus = 0

		SessionCreationAttempt = 1
		SessionId = 0

		Wave = 1
		IsActive = false
		WaveStartedAt = 0
		ZedTimeDuration = 0
		ZedTimeCount = 0
		ZedsLeft = 0
	}
};

var array<API_StatsServiceBase.PlayerData> Players;
var SessionStruct GameSession;

var private array<string> RawStats;

var private WorldInfo WI;
var private KFGameInfo KFGI;
var private KFGameReplicationInfo KFGRI;
var private OnlineSubsystem OS;
var private MsgSpectator msgSpec;
var private Stats_EventLogger EventLog;

var private float	LastZedTimeEvent;
var private float	LastZedTimeEventRealtime;

static function Stats_Tracker GetInstance() {
	local Stats_Tracker Instance;

	foreach Class'WorldInfo'.static.GetWorldInfo().DynamicActors(Class'Stats_Tracker', Instance) {      
		return Instance;        
	}

	return Instance;
}

event Tick(float dt) {
	if (KFGRI == None || KFGI == None) return;

	DetectCurrentWave();

	if (!KFGI.IsWaveActive()) return;

	if (GameSession.ZedsLeft != KFGRI.AIRemaining) {
		GameSession.ZedsLeft = KFGRI.AIRemaining;

		EventLog.AddZedsLeftEvent(GameSession.ZedsLeft);
	}

	DetectZedtime();
}

private function DetectCurrentWave() {
	local int currentWave;
	local bool isWaveActive;

	if (KFGRI == None || KFGI == None) return;

	currentWave = KFGRI.WaveNum;
	isWaveActive = KFGI.IsWaveActive();

	if (isWaveActive != GameSession.IsActive) {
		if (isWaveActive) {
			if (currentWave != GameSession.Wave) {
				GameSession.Wave = currentWave;
			}

			OnWaveStarted();
		} else {
			SetTimer(0.5, false, 'OnWaveEnded');
		}

		GameSession.IsActive = isWaveActive;
	}
}

private function DetectZedtime() {
	if (LastZedTimeEvent != KFGI.LastZedTimeEvent && KFGI.ZedTimeRemaining > 0) {
		if (KFGI.LastZedTimeEvent - LastZedTimeEvent > 5.0) {
			LastZedTimeEvent = KFGI.LastZedTimeEvent;
			LastZedTimeEventRealtime = WorldInfo.RealTimeSeconds;
			GameSession.ZedTimeDuration += 3;
			GameSession.ZedTimeCount += 1;
		}

		GameSession.ZedTimeDuration += (WorldInfo.RealTimeSeconds - LastZedTimeEventRealtime);

		LastZedTimeEvent = KFGI.LastZedTimeEvent;
		LastZedTimeEventRealtime = WorldInfo.RealTimeSeconds;

		EventLog.AddZedTimeEvent();
	}
}

private function UpdatePlayerData() {
	local KFPlayerController C;
	local KFPawn_Human Pawn;
	local int I, MaxBuffs, PlayerIndex;

	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C) || !GetPlayerStatsIndex(C, I)) continue;

		// After player death C.Pawn is None for some reason
		if (!Players[I].IsDead && (C.Pawn == None || !C.Pawn.IsAliveAndWell())) {
			Players[I].IsDead = true;

			PlayerIndex = EventLog.ResolvePlayerIndex(C.PlayerReplicationInfo.UniqueId);
			AddPlayerKilledEvent(PlayerIndex);
		}

		if (C.Pawn == None || KFPawn_Human(C.Pawn) == None) continue;
		
		Pawn = KFPawn_Human(C.Pawn);
		MaxBuffs = Round((Pawn.GetHealingDamageBoostModifier() - 1) * 20);

		if (Players[I].NumBuffs != MaxBuffs) {
			Players[I].NumBuffs = MaxBuffs;

			PlayerIndex = EventLog.ResolvePlayerIndex(C.PlayerReplicationInfo.UniqueId);
			AddBuffsEvent(PlayerIndex, MaxBuffs);
		}

		if (Players[I].Health != Pawn.Health || Players[I].Armor != Pawn.Armor) {
			Players[I].Health = Pawn.Health;
			Players[I].Armor = Pawn.Armor;

			PlayerIndex = EventLog.ResolvePlayerIndex(C.PlayerReplicationInfo.UniqueId);
			AddChangeHpEvent(PlayerIndex, Pawn.Health, Pawn.Armor);
		}
	}
}

private function AddBuffsEvent(int PlayerIndex, int MaxBuffs) {
	local Stats_EventLogger.DemoEventStruct DemoEvent;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_EVENT_BUFFS);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, PlayerIndex);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, MaxBuffs);

	EventLog.AddEvent(DemoEvent);
}

private function AddChangeHpEvent(int PlayerIndex, int Health, byte Armor) {
	local Stats_EventLogger.DemoEventStruct DemoEvent;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_EVENT_HP_CHANGE);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, PlayerIndex);
	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, Health);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, Armor);

	EventLog.AddEvent(DemoEvent);
}

private function AddPlayerKilledEvent(int PlayerIndex) {
	local Stats_EventLogger.DemoEventStruct DemoEvent;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_PLAYER_DIED);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, PlayerIndex);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.ResolveKillReason());

	EventLog.AddEvent(DemoEvent);
}

function PostBeginPlay() {
	super.PostBeginPlay();

	if (Role != ROLE_Authority) return;

	PostInit();
}

private function PostInit() {
	WI = Class'WorldInfo'.static.GetWorldInfo();
	if (WI == None) {
		SetTimer(0.1, false, 'PostInit');
		return;
	}

	KFGI = KFGameInfo(WI.Game);
	if (KFGI == None) {
		SetTimer(0.1, false, 'PostInit');
		return;
	}

	KFGRI = KFGI.MyKFGRI;
	if (KFGRI == None) {
		SetTimer(0.1, false, 'PostInit');
		return;
	}

	OS = class'GameEngine'.static.GetOnlineSubsystem();
	if (OS == None) {
		SetTimer(0.1, false, 'PostInit');
		return;
	}

	msgSpec = Spawn(Class'MsgSpectator');
	EventLog = class'Stats_EventLogger'.static.GetInstance();

	SetTimer(0.1, true, 'UpdatePlayerData');
	SetTimer(15.0, true, 'UpdateGameData');
}

private function OnWaveStarted() {
    local KFPlayerController C;

	GameSession.WaveStartedAt = WI.RealTimeSeconds;
	GameSession.ZedTimeDuration = 0.0;
	GameSession.ZedTimeCount = 0;

	if (GameSession.SessionId == 0) return;

	if (GameSession.Wave == 1) {
		class'API_SessionService'.static.GetInstance().UpdateStatus(
			GameSession.SessionId,
			SESSION_STATUS_INPROGRESS
		);
	}

	EventLog.AddWaveStartEvent(GameSession.Wave, KFGRI.AIRemaining);

	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;
		
		ResetPlayerData(C);
	}
}

private function OnWaveEnded() {
	local KFPlayerController C;
	local int Alive;

	EventLog.AddWaveEndEvent();

	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;

		UpdateNonKillStats(C);
	}

	if (GameSession.SessionId == 0) return;
	
	UploadWaveStats();

	Alive = GetAliveCount();

	if (Alive == 0) {
		class'API_SessionService'.static.GetInstance().UpdateStatus(
			GameSession.SessionId,
			SESSION_STATUS_LOST
		);
	} else if (GameSession.Wave == KFGRI.WaveMax) {
		class'API_SessionService'.static.GetInstance().UpdateStatus(
			GameSession.SessionId,
			SESSION_STATUS_WON
		);
	}
}

private function UploadWaveStats() {
	local int i;
	local KFPlayerController C;
	local CreateWaveStatsBody Body;

	Body.SessionId = GameSession.SessionId;
	Body.Wave = GameSession.Wave;
	Body.Length = int(WI.RealTimeSeconds - GameSession.WaveStartedAt);

	if (GameSession.GameMode == 3) {
		Body.HasCDData = true;
		Body.CDData.SpawnCycle = class'CD_Utils'.static.GetSpawnCycle(WI);
		Body.CDData.MaxMonsters = class'CD_Utils'.static.GetMaxMonsters(WI);
		Body.CDData.WaveSizeFakes = class'CD_Utils'.static.GetWaveSizeFakes(WI);
		Body.CDData.ZedsType = class'CD_Utils'.static.GetZedsType(WI);
	}
	
	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;
		if (!GetPlayerStatsIndex(C, i)) continue;

		if (Players[i].Perk == 2) {
			Players[i].Stats.ZedTimeLength = GameSession.ZedTimeDuration;
			Players[i].Stats.ZedTimeCount = GameSession.ZedTimeCount;
		} else {
			Players[i].Stats.ZedTimeLength = 0.0;
			Players[i].Stats.ZedTimeCount = 0;
		}

		Body.Players.AddItem(Players[i]);
	}

	class'API_StatsService'.static.GetInstance().CreateWaveStats(Body);

	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;
		if (!GetPlayerStatsIndex(C, i)) continue;

		Players[i].Stats.RadioComms.RequestHealing = 0;
		Players[i].Stats.RadioComms.RequestDosh = 0;
		Players[i].Stats.RadioComms.RequestHelp = 0;
		Players[i].Stats.RadioComms.TauntZeds = 0;
		Players[i].Stats.RadioComms.FollowMe = 0;
		Players[i].Stats.RadioComms.GetToTheTrader = 0;
		Players[i].Stats.RadioComms.Affirmative = 0;
		Players[i].Stats.RadioComms.Negative = 0;
		Players[i].Stats.RadioComms.ThankYou = 0;
	}
}

function AddZedKill(KFPlayerController C, name ZedKey) {
	local int i, PlayerIndex;

	if (!GetPlayerStatsIndex(C, i)) return;

	if (C.PlayerReplicationInfo != None) {
		PlayerIndex = EventLog.ResolvePlayerIndex(C.PlayerReplicationInfo.UniqueId);
		EventLog.AddZedKillEvent(PlayerIndex, ZedKey);
	}

	switch (ZedKey) {
		case 'KFPawn_ZedClot_Cyst': 
			Players[i].Stats.Kills.Cyst++;
			return;
		case 'KFPawn_ZedClot_Alpha': 
			Players[i].Stats.Kills.AlphaClot++;
			return;
		case 'KFPawn_ZedClot_Slasher': 
			Players[i].Stats.Kills.Slasher++;
			return;
		case 'KFPawn_ZedCrawler': 
			Players[i].Stats.Kills.Crawler++;
			return;
		case 'KFPawn_ZedGorefast': 
			Players[i].Stats.Kills.Gorefast++;
			return;
		case 'KFPawn_ZedStalker': 
			Players[i].Stats.Kills.Stalker++;
			return;
		case 'KFPawn_ZedScrake': 
			Players[i].Stats.Kills.Scrake++;
			return;
		case 'KFPawn_ZedFleshpound': 
			Players[i].Stats.Kills.FP++;
			return;
		case 'KFPawn_ZedFleshpoundMini': 
			Players[i].Stats.Kills.QP++;
			return;
		case 'KFPawn_ZedBloat': 
			Players[i].Stats.Kills.Bloat++;
			return;
		case 'KFPawn_ZedSiren': 
			Players[i].Stats.Kills.Siren++;
			return;
		case 'KFPawn_ZedHusk': 
			Players[i].Stats.Kills.Husk++;
			return;
		case 'KFPawn_ZedClot_AlphaKing': 
			Players[i].Stats.Kills.Rioter++;
			return;
		case 'KFPawn_ZedCrawlerKing': 
			Players[i].Stats.Kills.EliteCrawler++;
			return;
		case 'KFPawn_ZedGorefastDualBlade': 
			Players[i].Stats.Kills.Gorefiend++;
			return;
		case 'KFPawn_ZedDAR_Emp': 
			Players[i].Stats.Kills.Edar++;
			return;
		case 'KFPawn_ZedDAR_Laser': 
			Players[i].Stats.Kills.Edar++;
			return;
		case 'KFPawn_ZedDAR_Rocket': 
			Players[i].Stats.Kills.Edar++;
			return;
		case 'KFPawn_ZedHans': 
			Players[i].Stats.Kills.Boss++;
			return;
		case 'KFPawn_ZedPatriarch': 
			Players[i].Stats.Kills.Boss++;
			return;
		case 'KFPawn_ZedFleshpoundKing': 
			Players[i].Stats.Kills.Boss++;
			return;
		case 'KFPawn_ZedBloatKing': 
			Players[i].Stats.Kills.Boss++;
			return;
		case 'KFPawn_ZedMatriarch': 
			Players[i].Stats.Kills.Boss++;
			return;
		default:
			Players[i].Stats.Kills.Custom++;
			return;
	}
}

function AddEvent(KFPlayerController C, EventType type) {
	local int i, PlayerIndex;

	if (!GetPlayerStatsIndex(C, i)) return;

	switch (type) {
		case ET_HUSK_BACKPACK:
			Players[i].Stats.HuskBackpackKills++;
			return;
		case ET_RAGED_BY_BP:
			Players[i].Stats.HuskRages++;

			if (C.PlayerReplicationInfo != None) {
				PlayerIndex = EventLog.ResolvePlayerIndex(C.PlayerReplicationInfo.UniqueId);
				EventLog.AddHuskRageEvent(PlayerIndex);
			}

			return;
		default:
			return;
	}
}

function AddRadioComms(PlayerReplicationInfo PRI, int Type) {
	local int i;

	if (!GetPlayerStatsByPRI(KFPlayerReplicationInfo(PRI), i)) return;

	switch (Type) {
		case 0:
			Players[i].Stats.RadioComms.RequestHealing++;
			return;
		case 1:
			Players[i].Stats.RadioComms.RequestDosh++;
			return;
		case 2:
			Players[i].Stats.RadioComms.RequestHelp++;
			return;
		case 3:
			Players[i].Stats.RadioComms.TauntZeds++;
			return;
		case 4:
			Players[i].Stats.RadioComms.FollowMe++;
			return;
		case 5:
			Players[i].Stats.RadioComms.GetToTheTrader++;
			return;
		case 6:
			Players[i].Stats.RadioComms.Affirmative++;
			return;
		case 7:
			Players[i].Stats.RadioComms.Negative++;
			return;
		case 9:
			Players[i].Stats.RadioComms.ThankYou++;
			return;
	}
}

function UpdateNonKillStats(KFPlayerController C) {
	local int i;

	if (!GetPlayerStatsIndex(C, i)) return;

	Players[i].Stats.ShotsFired += C.ShotsFired;
	Players[i].Stats.ShotsHit += C.ShotsHit;
	Players[i].Stats.ShotsHS += C.ShotsHitHeadshot;
	Players[i].Stats.DoshEarned = C.MatchStats.GetDoshEarnedInWave();
	Players[i].Stats.HealsGiven = C.MatchStats.GetHealGivenInWave();
	Players[i].Stats.HealsReceived = C.MatchStats.GetHealReceivedInWave();
	Players[i].Stats.DamageDealt = C.MatchStats.GetDamageDealtInWave();
	Players[i].Stats.DamageTaken = C.MatchStats.GetDamageTakenInWave();
}

function ResetPlayerData(KFPlayerController C) {
	local int i;
	local PlayerReplicationInfo PRI;
	local Stats_EventLogger.DemoEventStruct DemoEvent;

	if (!GetPlayerStatsIndex(C, i)) return;

	PRI = C.PlayerReplicationInfo;
	Players[i].UniqueId = OS.UniqueNetIdToString(PRI.UniqueId);

	Players[i].Perk = ConvertPerk(C.GetPerk().GetPerkClass());
	Players[i].Level = C.GetPerk().GetLevel();
	Players[i].Prestige = C.GetPerk().GetCurrentPrestigeLevel();
	Players[i].IsDead = false;

	Players[i].Stats.ShotsFired = -Players[i].Stats.ShotsFired;
	Players[i].Stats.ShotsHit = -Players[i].Stats.ShotsHit;
	Players[i].Stats.ShotsHS = -Players[i].Stats.ShotsHS;

	Players[i].Stats.DoshEarned = 0;

	Players[i].Stats.HealsGiven = 0;
	Players[i].Stats.HealsReceived = 0;

	Players[i].Stats.DamageDealt = 0;
	Players[i].Stats.DamageTaken = 0;

	Players[i].Stats.Kills.Cyst = 0;
	Players[i].Stats.Kills.AlphaClot = 0;
	Players[i].Stats.Kills.Slasher = 0;
	Players[i].Stats.Kills.Stalker = 0;
	Players[i].Stats.Kills.Crawler = 0;
	Players[i].Stats.Kills.Gorefast = 0;
	Players[i].Stats.Kills.Rioter = 0;
	Players[i].Stats.Kills.EliteCrawler = 0;
	Players[i].Stats.Kills.Gorefiend = 0;
	Players[i].Stats.Kills.Siren = 0;
	Players[i].Stats.Kills.Bloat = 0;
	Players[i].Stats.Kills.Edar = 0;
	Players[i].Stats.Kills.Husk = 0;
	Players[i].Stats.Kills.Scrake = 0;
	Players[i].Stats.Kills.FP = 0;
	Players[i].Stats.Kills.QP = 0;
	Players[i].Stats.Kills.Boss = 0;
	Players[i].Stats.Kills.Custom = 0;
	Players[i].Stats.HuskBackpackKills = 0;
	Players[i].Stats.HuskRages = 0;

	DemoEvent.Buffer = EventLog.WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.DEMO_EVENT_TYPE_PLAYER_PERK);
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, EventLog.ResolvePlayerIndex(PRI.UniqueId));
	DemoEvent.Buffer = EventLog.WriteByte(DemoEvent.Buffer, Players[i].Perk);

	EventLog.AddEvent(DemoEvent);
}

private function UpdateGameData() {
	local KFPlayerController C;
	local API_SessionServiceBase.UpdateGameDataRequest Body;
	local API_SessionServiceBase.PlayerLiveData PLiveData;

	if (GameSession.SessionId <= 0) return;

	Body.SessionId = GameSession.SessionId;

	Body.GameData.Wave = GameSession.Wave;
	Body.GameData.IsTraderTime = !GameSession.IsActive;
	Body.GameData.ZedsLeft = KFGRI.AIRemaining;
	Body.GameData.PlayersAlive = GetAliveCount();
	Body.GameData.PlayersOnline = GetConnectedCount();
	Body.GameData.MaxPlayers = WI.Game.MaxPlayersAllowed;

	if (GameSession.GameMode == 3) {
		Body.HasCDData = true;
		Body.CDData.SpawnCycle = class'CD_Utils'.static.GetSpawnCycle(WI);
		Body.CDData.MaxMonsters = class'CD_Utils'.static.GetMaxMonsters(WI);
		Body.CDData.WaveSizeFakes = class'CD_Utils'.static.GetWaveSizeFakes(WI);
		Body.CDData.ZedsType = class'CD_Utils'.static.GetZedsType(WI);
	}

	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!GetPlayerLiveData(C, PLiveData)) continue;

		Body.Players.AddItem(PLiveData);
	}

	class'API_SessionService'.static.GetInstance().UpdateGameData(Body);
}

private function bool GetPlayerLiveData(
	KFPlayerController C,
	out API_SessionServiceBase.PlayerLiveData OutData
) {
	local string UniqueId, PlayerName;
	local KFPlayerReplicationInfo PRI;
	local API_SessionServiceBase.PlayerLiveData Data;

	if (C == None) return false;

	PRI = KFPlayerReplicationInfo(C.PlayerReplicationInfo);
	if (PRI == None) return false;

	UniqueId = OS.UniqueNetIdToString(PRI.UniqueId);
	PlayerName = KFPlayerReplicationInfo(C.PlayerReplicationInfo).PlayerName;

	Data.PlayerName = PlayerName;

	if (!C.bIsEosPlayer) {
		Data.AuthId = OS.UniqueNetIdToInt64(PRI.UniqueId);
		Data.AuthType = AT_STEAM;
	} else {
		Data.AuthId = UniqueId;
		Data.AuthType = AT_EGS;
	}
	
	if (PRI.bOnlySpectator || PRI.bDemoOwner) {
		Data.IsSpectator = true;
	}

	Data.Perk = ConvertPerk(C.GetPerk().GetPerkClass());
	Data.Level = C.GetPerk().GetLevel();
	Data.Prestige = C.GetPerk().GetCurrentPrestigeLevel();

	if (C.Pawn != None && KFPawn_Human(C.Pawn) != None) {
		Data.Health = KFPawn_Human(C.Pawn).Health;
		Data.Armor = KFPawn_Human(C.Pawn).Armor;
	}

	OutData = Data;

	return true;
}

private function int ConvertPerk(Class<KFPerk> PerkClass) {
	if (PerkClass == class'KFPerk_Berserker')		return 1;
	if (PerkClass == class'KFPerk_Commando')		return 2;
	if (PerkClass == class'KFPerk_FieldMedic')		return 3;
	if (PerkClass == class'KFPerk_Sharpshooter')	return 4;
	if (PerkClass == class'KFPerk_Gunslinger')		return 5;
	if (PerkClass == class'KFPerk_Support')			return 6;
	if (PerkClass == class'KFPerk_Swat')			return 7;
	if (PerkClass == class'KFPerk_Demolitionist')	return 8;
	if (PerkClass == class'KFPerk_Firebug')			return 9;
	if (PerkClass == class'KFPerk_Survivalist')		return 10;

	return 0;
}

private function bool IsValidPlayer(KFPlayerController C) {
	return (
		C != None &&
		C.PlayerReplicationInfo != None &&
		!C.PlayerReplicationInfo.bOnlySpectator &&
		!C.PlayerReplicationInfo.bDemoOwner
	);
}

private function bool GetPlayerStatsByPRI(
	KFPlayerReplicationInfo PRI,
	optional out int Index
) {
	local string UniqueId, PlayerName;
	local API_StatsServiceBase.PlayerData Iter;

	if (PRI == None) return false;

	UniqueId = OS.UniqueNetIdToString(PRI.UniqueId);
	PlayerName = PRI.PlayerName;
	Index = 0;

	foreach Players(Iter) {
		if (UniqueId == Iter.UniqueId) {
			return true;
		}

		Index++;
	}

	Iter.UniqueId = UniqueId;
	Iter.PlayerName = PlayerName;

	if (!PRI.KFPlayerOwner.bIsEosPlayer) {
		Iter.AuthId = OS.UniqueNetIdToInt64(PRI.UniqueId);
		Iter.AuthType = AT_STEAM;
	} else {
		Iter.AuthId = Iter.UniqueId;
		Iter.AuthType = AT_EGS;
	}

	Players.AddItem(Iter);
	Index = Players.Length - 1;

	return true;
}

private function bool GetPlayerStatsIndex(
	KFPlayerController C, 
	optional out int Index
) {
	if (C == None) return false;

	return GetPlayerStatsByPRI(KFPlayerReplicationInfo(C.PlayerReplicationInfo), Index);
}

private function int GetAliveCount() {
	local int Count;
	local KFPlayerController C;

	Count = 0;
	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;

		if (C.Pawn != None && C.Pawn.IsAliveAndWell()) {
			Count++;
		}
	}

	return Count;
}

private function int GetConnectedCount() {
	local int Count;
	local KFPlayerController C;

	Count = 0;
	foreach WI.AllControllers(Class'KFPlayerController', C) {
		if (!IsValidPlayer(C)) continue;

		Count++;
	}

	return Count;
}


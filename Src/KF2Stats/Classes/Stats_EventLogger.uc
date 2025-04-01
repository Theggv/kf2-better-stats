class Stats_EventLogger extends Info;

struct DemoEventStruct {
	var array<byte> Buffer;
};

const DEMO_EVENT_TYPE_PLAYER_JOIN = 1;
const DEMO_EVENT_TYPE_PLAYER_DISCONNECT = 2;
const DEMO_EVENT_TYPE_PLAYER_PERK = 3;
const DEMO_EVENT_TYPE_PLAYER_DIED = 4;

const DEMO_EVENT_TYPE_GLOBAL_WAVE_START = 17;
const DEMO_EVENT_TYPE_GLOBAL_WAVE_END = 18;
const DEMO_EVENT_TYPE_GLOBAL_ZED_TIME = 19;
const DEMO_EVENT_TYPE_GLOBAL_ZEDS_LEFT = 20;

const DEMO_EVENT_TYPE_EVENT_KILL = 33;
const DEMO_EVENT_TYPE_EVENT_BUFFS = 34;
const DEMO_EVENT_TYPE_EVENT_HP_CHANGE = 35;
const DEMO_EVENT_TYPE_EVENT_HUSK_RAGE = 36;

var private array<DemoEventStruct> Events;
var array<UniqueNetId> Players;

static function Stats_EventLogger GetInstance() {
	local Stats_EventLogger Instance;

	foreach Class'WorldInfo'.static.GetWorldInfo().DynamicActors(Class'Stats_EventLogger', Instance) {      
		return Instance;        
	}

	return Instance;
}

function int ResolvePlayerIndex(UniqueNetId UniqueId) {
	return Players.Find('Uid', UniqueId.Uid) + 1;
}

function int ResolveZedIndex(name ZedKey) {
	switch (ZedKey) {
		case 'KFPawn_ZedClot_Cyst': 
			return 1;
		case 'KFPawn_ZedClot_Alpha': 
			return 2;
		case 'KFPawn_ZedClot_Slasher': 
			return 3;
		case 'KFPawn_ZedCrawler': 
			return 4;
		case 'KFPawn_ZedGorefast': 
			return 5;
		case 'KFPawn_ZedStalker': 
			return 6;
		case 'KFPawn_ZedScrake': 
			return 7;
		case 'KFPawn_ZedFleshpound': 
			return 8;
		case 'KFPawn_ZedFleshpoundMini': 
			return 9;
		case 'KFPawn_ZedBloat': 
			return 10;
		case 'KFPawn_ZedSiren': 
			return 11;
		case 'KFPawn_ZedHusk': 
			return 12;
		case 'KFPawn_ZedClot_AlphaKing': 
			return 13;
		case 'KFPawn_ZedCrawlerKing': 
			return 14;
		case 'KFPawn_ZedGorefastDualBlade': 
			return 15;
		case 'KFPawn_ZedDAR_Emp': 
			return 16;
		case 'KFPawn_ZedDAR_Laser': 
			return 17;
		case 'KFPawn_ZedDAR_Rocket': 
			return 18;
		case 'KFPawn_ZedHans': 
			return 19;
		case 'KFPawn_ZedPatriarch': 
			return 20;
		case 'KFPawn_ZedFleshpoundKing': 
			return 21;
		case 'KFPawn_ZedBloatKing': 
			return 22;
		case 'KFPawn_ZedMatriarch': 
			return 23;
		default:
			return 0;
	}
}

function int ResolveKillReason() {
	return 0;
}

function array<byte> WriteByte(array<byte> Buffer, byte Data) {
	Buffer.AddItem(Data);

	return Buffer;
}

function array<byte> WriteInt(array<byte> Buffer, int Data) {
	Buffer.AddItem(byte(Data >> 24));
	Buffer.AddItem(byte(Data >> 16));
	Buffer.AddItem(byte(Data >> 8));
	Buffer.AddItem(byte(Data));

	return Buffer;
}

function array<byte> WriteString(array<byte> Buffer, string Data) {
	local int Ch;

	while (Len(Data) > 0) {
		Ch = Asc(Left(Data, 1));
		Buffer.AddItem(Ch);
		Data = Mid(Data, 1);
	};

	return Buffer;
}

function AddEvent(DemoEventStruct Item) {
	Events.AddItem(Item);
}

function Clear() {
	Events.Remove(0, Events.Length);
}

function array<byte> Serialize(int SessionId) {
	local DemoEventStruct Item;
	local array<byte> Payload;
	local byte PayloadByte;

	// Header 
	Payload = WriteString(Payload, "kf2rec"); // Title
	Payload = WriteByte(Payload, 1); // Version
	Payload = WriteInt(Payload, SessionId); // SessionId
	Payload = WriteByte(Payload, 0); // Null Terminator

	foreach Events(Item) {
		foreach Item.Buffer(PayloadByte) {
			Payload = WriteByte(Payload, PayloadByte);
		}
		
		Payload = WriteByte(Payload, 0); // Null Terminator
	}

	return Payload;
}

function AddZedsLeftEvent(int ZedsLeft) {
	local DemoEventStruct DemoEvent;
	
	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_GLOBAL_ZEDS_LEFT);
	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, ZedsLeft);

	AddEvent(DemoEvent);
}

function AddZedTimeEvent() {
	local DemoEventStruct DemoEvent;
	
	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_GLOBAL_ZED_TIME);

	AddEvent(DemoEvent);
}

function AddWaveStartEvent(int Wave, int ZedsLeft) {
	local DemoEventStruct DemoEvent;

	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_GLOBAL_WAVE_START);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, Wave);
	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, ZedsLeft);

	AddEvent(DemoEvent);
}

function AddWaveEndEvent() {
	local DemoEventStruct DemoEvent;

	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_GLOBAL_WAVE_END);

	AddEvent(DemoEvent);
}

function AddZedKillEvent(int PlayerIndex, name ZedKey) {
	local DemoEventStruct DemoEvent;
	
	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_EVENT_KILL);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, PlayerIndex);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, ResolveZedIndex(ZedKey));

	AddEvent(DemoEvent);
}

function AddHuskRageEvent(int PlayerIndex) {
	local DemoEventStruct DemoEvent;

	DemoEvent.Buffer = WriteInt(DemoEvent.Buffer, WorldInfo.RealTimeSeconds * 100);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, DEMO_EVENT_TYPE_EVENT_HUSK_RAGE);
	DemoEvent.Buffer = WriteByte(DemoEvent.Buffer, PlayerIndex);

	AddEvent(DemoEvent);
}

defaultproperties {
}
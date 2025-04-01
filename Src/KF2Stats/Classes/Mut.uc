class Mut extends KFMutator;

var private KF2Stats KF2Stats;

public function AddMutator(Mutator Mut) {
	if (Mut == Self) return;

	if (Mut.Class == Class) {
		Mut(Mut).SafeDestroy();
	} else {
		Super.AddMutator(Mut);
	}
}

public event PreBeginPlay() {
	Super.PreBeginPlay();

	if (WorldInfo.NetMode == NM_Client) return;

	foreach WorldInfo.DynamicActors(class'KF2Stats', KF2Stats) {
		break;
	}

	if (KF2Stats == None) {
		KF2Stats = WorldInfo.Spawn(class'KF2Stats');
	}

	if (KF2Stats == None) {
		`Log_Base("FATAL: Can't Spawn 'KF2Stats'");
		SafeDestroy();
	}
}

public simulated function bool SafeDestroy() {
	return (bPendingDelete || bDeleteMe || Destroy());
}

public function ScoreKill(Controller Killer, Controller Other) {
	local KFPlayerController C;
	local name Zedkey;

	C = KFPlayerController(Killer);

	if (Killer == None || Killer.PlayerReplicationInfo == None || 
		Killer == Other || Other == None || Other.Pawn == None) {
		return;
	} 

	if (Other.Pawn.IsA('KFPawn_Monster')) {
		Zedkey = KFPawn_Monster(Other.Pawn).LocalizationKey;
		KF2Stats.Stats.AddZedKill(C, Zedkey);
	}
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
	super.NetDamage(OriginalDamage, Damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType, DamageCauser);
	
	KF2Stats.NetDamage(OriginalDamage, Damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType, DamageCauser);
}

public function NotifyLogin(Controller C) {
	KF2Stats.NotifyLogin(C);

	Super.NotifyLogin(C);
}

public function NotifyLogout(Controller C) {
	KF2Stats.NotifyLogout(C);

	Super.NotifyLogout(C);
}

defaultproperties {
}
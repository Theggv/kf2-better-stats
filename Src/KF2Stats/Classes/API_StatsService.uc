class API_StatsService extends API_StatsServiceBase;

static function API_StatsService GetInstance() {
	local API_StatsService Instance;

	foreach Class'WorldInfo'.static.GetWorldInfo().DynamicActors(Class'API_StatsService', Instance) {      
		return Instance;        
	}

	return Instance;
}

public function CreateWaveStats(CreateWaveStatsBody Body) {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL(class'BackendConfig'.default.BaseUrl $ "/api/stats/wave")
		.SetVerb("POST")
		.SetHeader("Authorization", "Bearer" @ class'BackendConfig'.default.SecretToken)
		.SetHeader("Content-Type", "application/json")
		.SetContentAsString(PrepareWaveStatsBody(Body))
		.ProcessRequest()
		) {
		`log("[CreateWaveStats] request sent");
	} else {
		`log("[CreateWaveStats] failed to send request");
	}
}

defaultproperties {
}
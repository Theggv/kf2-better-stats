class API_SessionService extends API_SessionServiceBase;

static function API_SessionService GetInstance() {
	local API_SessionService Instance;

	foreach Class'WorldInfo'.static.GetWorldInfo().DynamicActors(Class'API_SessionService', Instance) {      
		return Instance;        
	}

	return Instance;
}

public function CreateSession(
	string ServerName, string ServerAddress,
	string MapName,
	int Difficulty, int Length, int Mode
) {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL(class'BackendConfig'.default.BaseUrl $ "/api/sessions/")
		.SetVerb("POST")
		.SetHeader("Authorization", "Bearer" @ class'BackendConfig'.default.SecretToken)
		.SetHeader("Content-Type", "application/json")
		.SetContentAsString(PrepareCreateSessionBody(
			ServerName, ServerAddress, MapName, Difficulty, Length, Mode)
		)
		.SetProcessRequestCompleteDelegate(OnCreateSessionRequestComplete)
		.ProcessRequest()
		) {
		`log("[CreateSession] request sent");
	} else {
		`log("[CreateSession] failed to send request");
	}
}

private function OnCreateSessionRequestComplete(
	HttpRequestInterface Request, 
	HttpResponseInterface Response, 
	bool bWasSuccessful
) {
	local int code, sessionId;
	local string content;
	local JsonObject parsedJson;

	code = 500;
	
	if (Response != None) {
		code = Response.GetResponseCode();
		content = Response.GetContentAsString();
	}

	if (code != 201) {
		`log("[CreateSession] failed with code:" @ code $ "." @ content);
		OnCreateSessionFailed();
		return;
	}

	parsedJson = class'JsonObject'.static.DecodeJson(content);
	sessionId = ParsedJson.GetIntValue("id");

	OnCreateSessionCompleted(sessionId);
}

public function UpdateStatus(int SessionId, int StatusId) {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL(class'BackendConfig'.default.BaseUrl $ "/api/sessions/status")
		.SetVerb("PUT")
		.SetHeader("Authorization", "Bearer" @ class'BackendConfig'.default.SecretToken)
		.SetHeader("Content-Type", "application/json")
		.SetContentAsString(PrepareUpdateStatusBody(SessionId, StatusId))
		.ProcessRequest()
		) {
		`log("[UpdateStatus] request sent");
	} else {
		`log("[UpdateStatus] failed to send request");
	}
}

function UpdateGameData(UpdateGameDataRequest body) {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL(class'BackendConfig'.default.BaseUrl $ "/api/sessions/game-data")
		.SetVerb("PUT")
		.SetHeader("Authorization", "Bearer" @ class'BackendConfig'.default.SecretToken)
		.SetHeader("Content-Type", "application/json")
		.SetContentAsString(PrepareUpdateGameDataBody(body))
		.ProcessRequest()
		) {
		`log("[UpdateGameData] request sent");
	} else {
		`log("[UpdateGameData] failed to send request");
	}
}

function UploadDemo(array<byte> Payload) {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL(class'BackendConfig'.default.BaseUrl $ "/api/sessions/demo")
		.SetVerb("POST")
		.SetHeader("Authorization", "Bearer" @ class'BackendConfig'.default.SecretToken)
		.SetHeader("Content-Type", "application/octet-stream")
		.SetContent(Payload)
		.ProcessRequest()
		) {
		`log("[UploadDemo] request sent");
	} else {
		`log("[UploadDemo] failed to send request");
	}
}


defaultproperties {
}
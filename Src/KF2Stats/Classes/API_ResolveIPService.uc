class API_ResolveIPService extends Info;

delegate OnGetPublicIPCompleted(string Address);

static function API_ResolveIPService GetInstance() {
	local API_ResolveIPService Instance;

	foreach Class'WorldInfo'.static.GetWorldInfo().DynamicActors(Class'API_ResolveIPService', Instance) {      
		return Instance;        
	}

	return Instance;
}

public function GetPublicIP() {
	if (class'HttpFactory'.static.CreateRequest()
		.SetURL("http://api.ipify.org/?format=json")
		.SetVerb("GET")
		.SetProcessRequestCompleteDelegate(OnGetPublicIPRequestComplete)
		.ProcessRequest()
		) {
		`log("[GetPublicIP] request sent");
	} else {
		`log("[GetPublicIP] failed to send request");
	}
}

private function OnGetPublicIPRequestComplete(
	HttpRequestInterface Request, 
	HttpResponseInterface Response, 
	bool bWasSuccessful
) {
	local int code;
	local string content, address;
	local JsonObject parsedJson;

	`log("[OnGetPublicIPRequestComplete] pre");

	code = 500;

	if (Response != None) {
		code = Response.GetResponseCode();
		`log("[OnGetPublicIPRequestComplete] code" @ code);

		content = Response.GetContentAsString();
		`log("[OnGetPublicIPRequestComplete] content" @ content);
	}

	if (code != 200) {
		`log("[GetPublicIP] failed, code:" @ code $ "." @ content);
		return;
	}

	parsedJson = class'JsonObject'.static.DecodeJson(content);
	address = ParsedJson.GetStringValue("ip");

	OnGetPublicIPCompleted(address);

	`log("[OnGetPublicIPRequestComplete] post");
}

defaultproperties {
}
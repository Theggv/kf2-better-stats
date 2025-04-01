class CD_Utils extends Info;

public static function int GetMaxMonsters(WorldInfo WI) {
    local string Output;

    Output = WI.ConsoleCommand("GetAll CD_Survival MaxMonstersInt", false);
    Output = Split(Output, "= ", true);

    if (Output == "") return 0;

    return int(Output);
}

public static function int GetWaveSizeFakes(WorldInfo WI) {
    local string Output;

    Output = WI.ConsoleCommand("GetAll CD_Survival WaveSizeFakesInt", false);
    Output = Split(Output, "= ", true);

    if (Output == "") return 0;

    return int(Output);
}

public static function string GetSpawnCycle(WorldInfo WI) {
    local string Output;

    Output = WI.ConsoleCommand("GetAll CD_Survival SpawnCycle", false);
    Output = Split(Output, "= ", true);

    return Output;
}

public static function string GetZedsType(WorldInfo WI) {
    local string Output;

    Output = WI.ConsoleCommand("GetAll CD_Survival ZedsType", false);
    Output = Split(Output, "= ", true);

    return Output;
}

public static function bool IsSPBGSSurvival(KFGameInfo KFGI) {
    return KFGI.IsA('SPBGS_Survival');
}

public static function string GetSPBGSStats(WorldInfo WI) {
    local string Output;

    Output = WI.ConsoleCommand("GetAll SPBGS_StatsSystem PlayerStats", false);
    Output = Split(Output, "= ", true);

    `log("[GetSPBGSStats]" @ Output);

    return Output;
}

public static function array<string> SplitRawStats(string CmdOutput) {
    local int I, StartIndex;
    local string Text;
    local array<string> Parts;
    local bool IsInsideValue;

    Text = Split(CmdOutput, "= ", true);

    for (I = 0; I < Len(Text); I++) {
        if (Mid(Text, I, 1) == "\"") {
            IsInsideValue = !IsInsideValue;
            continue;
        }

        if (IsInsideValue) {
            continue;
        }

        if (Mid(Text, I, 1) == "(") {
            StartIndex = I;
            continue;
        } else if (Mid(Text, I, 1) == ")") {
            Parts.AddItem(Mid(Text, StartIndex + 1, I - StartIndex - 1));
        }
    }

    return Parts;
}

public static function array<string> SplitStructIntoKeyValues(string Str) {
    local int I, StartIndex;
    local bool IsInsideValue;
    local array<string> Parts;

    StartIndex = 0;

    for (I = 0; I < Len(Str); I++) {
        if (Mid(Str, I, 1) == "\"") {
            IsInsideValue = !IsInsideValue;
            continue;
        }

        if (IsInsideValue) {
            continue;
        }

        if (Mid(Str, I, 1) == ",") {
            Parts.AddItem(Mid(Str, StartIndex, I - StartIndex));
            StartIndex = I + 1;
        }
    }

    return Parts;
}

public static function string FindValueByKey(array<string> Parts, string Needle) {
    local int I, DelimiterIndex;
    local string KeyValue, Key;

    for (I = 0; I < Parts.Length; I++) {
        KeyValue = Parts[I];

        DelimiterIndex = InStr(KeyValue, "=");
        Key = Left(KeyValue, DelimiterIndex);

        if (Key == Needle) {
            return Mid(KeyValue, DelimiterIndex + 1);
        }
    }

    return "";
}
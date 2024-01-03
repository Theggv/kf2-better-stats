## KF2 Better Stats

Server-side mutator to collect player stats.
Requires [backend](https://github.com/Theggv/kf2-stats-backend) in order to process data.

Sends data to the backend after wave completion.
Updates server info every 15 seconds.

Supports every vanilla game mode except versus. Partial CD support (chokepoints edition).

### Usage

```
?Mutator=KF2Stats.Mut
```

### Setup

Config file `Config/KFKF2Stats.ini` will be generated after first launch.
You have to set `BaseUrl` and `SecretToken` in order to access backend endpoints.

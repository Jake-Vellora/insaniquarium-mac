#ifndef __STEAMPRESENCE_H__
#define __STEAMPRESENCE_H__

namespace Sexy
{
	// Best-effort Steamworks registration as appid 3320; no-ops when the
	// dylib is missing or Steam isn't running.
	void InitSteamPresence();
	void ShutdownSteamPresence();
}

#endif

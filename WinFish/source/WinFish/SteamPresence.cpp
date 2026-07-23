// Steamworks presence: register this session as the real Insaniquarium!
// Deluxe (appid 3320) so Steam attributes playtime/friends status to the
// game Jake owns, regardless of being launched via a non-Steam shortcut.
//
// Loaded via dlopen so the build has no SDK dependency: if
// Contents/Frameworks/libsteam_api.dylib is absent (SDK not installed yet)
// or Steam isn't running, the game simply runs without presence.
#include "SteamPresence.h"

#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>

namespace
{
	void* gSteamLib = nullptr;
	bool (*gSteamShutdown)() = nullptr;
}

void Sexy::InitSteamPresence()
{
	// The real game's appid. Steam validates ownership against the logged-in
	// account at init. Overwrite whatever the shortcut launch set.
	setenv("SteamAppId", "3320", 1);
	setenv("SteamGameId", "3320", 1);

	gSteamLib = dlopen("@executable_path/../Frameworks/libsteam_api.dylib", RTLD_NOW);
	if (gSteamLib == nullptr)
		return; // dylib not bundled (Steamworks SDK step pending) — run without

	// SDK 1.59+: SteamAPI_Init is a header inline; the dylib exports
	// SteamAPI_InitFlat (returns 0 on success + an error message) and the
	// legacy SteamAPI_InitSafe (bool). Try both.
	typedef int (*InitFlatFn)(char (*)[1024]);
	typedef bool (*InitSafeFn)();
	InitFlatFn anInitFlat = (InitFlatFn)dlsym(gSteamLib, "SteamAPI_InitFlat");
	InitSafeFn anInitSafe = (InitSafeFn)dlsym(gSteamLib, "SteamAPI_InitSafe");

	bool aSucceeded = false;
	char anErrMsg[1024] = "";
	if (anInitFlat != nullptr)
		aSucceeded = anInitFlat(&anErrMsg) == 0;
	else if (anInitSafe != nullptr)
		aSucceeded = anInitSafe();

	if (!aSucceeded)
	{
		fprintf(stderr, "SteamPresence: init failed: %s\n",
			anErrMsg[0] != '\0' ? anErrMsg : "(no init export succeeded; Steam not running?)");
		dlclose(gSteamLib);
		gSteamLib = nullptr;
		return;
	}
	gSteamShutdown = (bool (*)())dlsym(gSteamLib, "SteamAPI_Shutdown");
	fprintf(stderr, "SteamPresence: active as appid 3320\n");
}

void Sexy::ShutdownSteamPresence()
{
	if (gSteamShutdown != nullptr)
		gSteamShutdown();
	gSteamShutdown = nullptr;
	gSteamLib = nullptr;
}

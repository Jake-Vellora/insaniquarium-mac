#include "WinFishApp.h"
#include "SaverBridge.h"
#include "SteamPresence.h"
#include <SDL2/SDL_main.h>
#include <SexyAppFramework/SexyAppBase.h>

using namespace Sexy;

int main(int argc, char *argv[])
{
	Sexy::InitSteamPresence();

	WinFishApp* aTheApp = new WinFishApp();
	aTheApp->SetArgs(argc, argv);

	// Resource dir: INSANIQ_RESDIR overrides for dev builds; the default from
	// SexyAppBase is SDL_GetBasePath() (= Contents/Resources inside a bundle).
	const char* aResDir = std::getenv("INSANIQ_RESDIR");
	if (aResDir != nullptr)
		aTheApp->mResourceDir = aResDir;
	// Fishsong enumeration and some legacy loads use cwd-relative paths.
	Sexy::ChDir(aTheApp->mResourceDir);

	// Saves and settings: ~/Library/Application Support/PopCap/Insaniquarium/
	char* aPrefPath = SDL_GetPrefPath("PopCap", "Insaniquarium");
	if (aPrefPath != nullptr)
	{
		aTheApp->mCustomSaveDir = aPrefPath;
		SDL_free(aPrefPath);
	}
	// SexyAppBase parses these inside Init(), which is too late for the
	// screensaver bridge below - it would read and write the default folder.
	bool isScreenSaver = false;
	for (int i = 1; i < argc; i++)
	{
		const std::string anArg = argv[i];
		if (anArg.compare(0, 9, "-savedir=") == 0)
			aTheApp->mCustomSaveDir = anArg.substr(9);
		else if (anArg == "-screensaver")
			isScreenSaver = true;
	}

	// Before profiles load: pull in the shells the screensaver earned and the
	// tank it left behind, then push everything back out - the launch-time push
	// also covers sessions that ended in a crash and never ran the exit one.
	// Skipped under -screensaver, where the save dir already is the container.
	if (!isScreenSaver)
	{
		ImportScreenSaverEarnings(aTheApp->mCustomSaveDir);
		ImportSaverTank(aTheApp->mCustomSaveDir);
		PushSavesToSaverContainer(aTheApp->mCustomSaveDir);
	}

	aTheApp->Init();
	aTheApp->Start();
#if !defined(SDL_PLATFORM_EMSCRIPTEN)
	aTheApp->Shutdown();
	if (!isScreenSaver)
		PushSavesToSaverContainer(aTheApp->mCustomSaveDir);
	delete aTheApp;
#endif
	Sexy::ShutdownSteamPresence();
	return 0;
}

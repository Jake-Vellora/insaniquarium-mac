#include "WinFishApp.h"
#include "SteamPresence.h"
#include <SDL2/SDL_main.h>
#include <SexyAppFramework/SexyAppBase.h>
#include <cstdlib>
#include <filesystem>

// The Insaniquarium screensaver runs sandboxed inside legacyScreenSaver and
// can only touch its own container, so the game bridges saves both ways
// (the macOS equivalent of the junction-point fix the Windows Steam release
// needed): tank data flows out at exit, and shells the screensaver earned
// (userdata/scr<N>.dat, nonce-validated against the profile) flow back in
// at launch so the game can credit them.
static std::filesystem::path SaverContainerSaveDir()
{
	const char* aHome = std::getenv("HOME");
	if (aHome == nullptr)
		return {};
	return std::filesystem::path(aHome) /
		"Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver"
		"/Data/Library/Application Support/PopCap/Insaniquarium";
}

static void SyncSavesToSaverContainer(const std::string& theSaveDir)
{
	std::filesystem::path aDest = SaverContainerSaveDir();
	if (aDest.empty())
		return;
	std::error_code anErr;
	std::filesystem::create_directories(aDest, anErr);
	if (anErr)
		return;
	const auto aOpts = std::filesystem::copy_options::overwrite_existing |
		std::filesystem::copy_options::recursive;
	std::filesystem::copy(std::filesystem::path(theSaveDir) / "userdata",
		aDest / "userdata", aOpts, anErr);
	std::filesystem::copy(std::filesystem::path(theSaveDir) / "registry.regemu",
		aDest / "registry.regemu",
		std::filesystem::copy_options::overwrite_existing, anErr);
}

static void ImportScreenSaverEarnings(const std::string& theSaveDir)
{
	std::filesystem::path aSrc = SaverContainerSaveDir() / "userdata";
	std::error_code anErr;
	if (aSrc.empty() || !std::filesystem::is_directory(aSrc, anErr))
		return;
	std::filesystem::path aDestDir = std::filesystem::path(theSaveDir) / "userdata";
	std::filesystem::create_directories(aDestDir, anErr);
	for (const auto& anEntry : std::filesystem::directory_iterator(aSrc, anErr))
	{
		const std::string aName = anEntry.path().filename().string();
		if (aName.compare(0, 3, "scr") != 0 ||
			anEntry.path().extension() != ".dat")
			continue;
		std::filesystem::path aDest = aDestDir / aName;
		// Keep a local file the game hasn't consumed yet unless the saver's
		// copy is newer; the nonce check rejects stale files either way.
		if (std::filesystem::exists(aDest, anErr) &&
			std::filesystem::last_write_time(aDest, anErr) >=
				std::filesystem::last_write_time(anEntry.path(), anErr))
			continue;
		std::filesystem::copy_file(anEntry.path(), aDest,
			std::filesystem::copy_options::overwrite_existing, anErr);
		if (!anErr)
			std::filesystem::remove(anEntry.path(), anErr);
	}
}

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

	// Pull in shells the screensaver earned before profiles load, then push
	// the current tank state out — launch-time sync covers sessions that
	// ended in a crash and never ran the exit sync.
	ImportScreenSaverEarnings(aTheApp->mCustomSaveDir);
	SyncSavesToSaverContainer(aTheApp->mCustomSaveDir);

	aTheApp->Init();
	aTheApp->Start();
#if !defined(SDL_PLATFORM_EMSCRIPTEN)
	aTheApp->Shutdown();
	SyncSavesToSaverContainer(aTheApp->mCustomSaveDir);
	delete aTheApp;
#endif
	Sexy::ShutdownSteamPresence();
	return 0;
}

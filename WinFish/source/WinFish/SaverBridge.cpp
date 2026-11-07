#include "SaverBridge.h"

#include <chrono>
#include <crt_externs.h>
#include <cstdlib>
#include <cstdio>
#include <filesystem>
#include <spawn.h>

namespace fs = std::filesystem;

static bool gPushFailed = false;

static fs::path SaverContainerSaveDir()
{
	const char* aHome = std::getenv("HOME");
	if (aHome == nullptr)
		return {};
	return fs::path(aHome) /
		"Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver"
		"/Data/Library/Application Support/PopCap/Insaniquarium";
}

// std::filesystem::copy stamps the destination with the time of the copy, which
// would make every push look newer than the screensaver's own writes.
static bool CopyFileKeepingTime(const fs::path& theSrc, const fs::path& theDest)
{
	std::error_code anErr;
	fs::copy_file(theSrc, theDest, fs::copy_options::overwrite_existing, anErr);
	if (anErr)
		return false;
	fs::file_time_type aTime = fs::last_write_time(theSrc, anErr);
	if (!anErr)
		fs::last_write_time(theDest, aTime, anErr);
	return !anErr;
}

static bool IsEarningsFile(const std::string& theName)
{
	return theName.compare(0, 3, "scr") == 0 &&
		fs::path(theName).extension() == ".dat";
}

// Records that we have just pushed. The file is empty - its own modification
// time is the whole point, and rewriting it is what sets that time to now. It
// lives beside userdata/ rather than in it so the prune loop leaves it alone.
static bool StampPush(const fs::path& theContainer)
{
	FILE* aFile = fopen((theContainer / ".lastpush").c_str(), "wb");
	if (aFile == nullptr)
		return false;
	fclose(aFile);
	return true;
}

bool Sexy::PushSavesToSaverContainer(const std::string& theSaveDir, bool theThrottle)
{
	// The per-save call sites fire on every level change; the payload is a
	// handful of small files, but there is no point rewriting it every few
	// frames either.
	static std::chrono::steady_clock::time_point sLastPush;
	static bool sHavePushed = false;
	std::chrono::steady_clock::time_point aNow = std::chrono::steady_clock::now();
	if (theThrottle && sHavePushed && aNow - sLastPush < std::chrono::seconds(2))
		return !gPushFailed;
	sLastPush = aNow;
	sHavePushed = true;

	fs::path aDest = SaverContainerSaveDir();
	if (aDest.empty())
		return !gPushFailed;

	std::error_code anErr;
	fs::create_directories(aDest / "userdata", anErr);
	if (anErr)
	{
		if (!gPushFailed)
			fprintf(stderr, "saver bridge: cannot reach the screensaver's folder "
				"(%s) - it will keep showing an old tank\n", anErr.message().c_str());
		gPushFailed = true;
		return false;
	}

	bool anAllCopied = true;
	fs::path aSrcUserData = fs::path(theSaveDir) / "userdata";
	if (fs::is_directory(aSrcUserData, anErr))
	{
		for (const auto& anEntry : fs::directory_iterator(aSrcUserData, anErr))
		{
			if (!anEntry.is_regular_file())
				continue;
			const std::string aName = anEntry.path().filename().string();
			// scr<N>.dat only ever travels inbound. Pushing our imported copy
			// back would re-seed the container with earnings we just spent.
			if (IsEarningsFile(aName))
				continue;
			if (!CopyFileKeepingTime(anEntry.path(), aDest / "userdata" / aName))
			{
				// Quiet after the first miss: the push repeats on every save.
				if (!gPushFailed && anAllCopied)
					fprintf(stderr, "saver bridge: cannot write %s to the "
						"screensaver's folder\n", aName.c_str());
				anAllCopied = false;
			}
		}

		// Merging without pruning used to leave deleted profiles behind in the
		// container, which the tank import would then resurrect.
		for (const auto& anEntry : fs::directory_iterator(aDest / "userdata", anErr))
		{
			if (!anEntry.is_regular_file())
				continue;
			const std::string aName = anEntry.path().filename().string();
			if (IsEarningsFile(aName))
				continue;
			if (!fs::exists(aSrcUserData / aName, anErr))
				fs::remove(anEntry.path(), anErr);
		}
	}

	fs::path aSrcRegistry = fs::path(theSaveDir) / "registry.regemu";
	if (fs::exists(aSrcRegistry, anErr) &&
		!CopyFileKeepingTime(aSrcRegistry, aDest / "registry.regemu"))
	{
		if (!gPushFailed && anAllCopied)
			fprintf(stderr, "saver bridge: cannot write registry.regemu to the "
				"screensaver's folder\n");
		anAllCopied = false;
	}

	// Stamped last, so the stamp is never older than anything it vouches for.
	if (!StampPush(aDest))
	{
		if (!gPushFailed && anAllCopied)
			fprintf(stderr, "saver bridge: cannot write .lastpush to the "
				"screensaver's folder\n");
		anAllCopied = false;
	}

	gPushFailed = !anAllCopied;
	return anAllCopied;
}

void Sexy::ImportSaverTank(const std::string& theSaveDir)
{
	fs::path aContainer = SaverContainerSaveDir();
	if (aContainer.empty())
		return;

	std::error_code anErr;
	// With no record of our own last push we cannot tell the screensaver's tank
	// from an echo of ours, so leave the game's alone. That is the first launch
	// after this shipped: at worst one screensaver session does not carry over,
	// where guessing the other way can eat a tank years in the making.
	fs::file_time_type aPushTime =
		fs::last_write_time(aContainer / ".lastpush", anErr);
	if (anErr)
		return;

	fs::path aSrcDir = aContainer / "userdata";
	if (!fs::is_directory(aSrcDir, anErr))
		return;

	fs::path aDestDir = fs::path(theSaveDir) / "userdata";
	fs::create_directories(aDestDir, anErr);
	for (const auto& anEntry : fs::directory_iterator(aSrcDir, anErr))
	{
		const std::string aName = anEntry.path().filename().string();
		if (aName.compare(0, 3, "sim") != 0 ||
			anEntry.path().extension() != ".dat")
			continue;
		// Everything we push keeps the game file's own timestamp, which is
		// necessarily older than the push that copied it - so an entry no newer
		// than the stamp is one of our echoes, whatever date it happens to
		// carry. Comparing the two tanks instead would read a save the player
		// brought from another machine (Finder, a USB stick and cp -p all keep
		// its original, old, modification time) as the stale one and overwrite
		// it. Only the screensaver writes here, at wall-clock time, while we
		// are away.
		fs::file_time_type aTime = fs::last_write_time(anEntry.path(), anErr);
		if (anErr || aTime <= aPushTime)
			continue;
		CopyFileKeepingTime(anEntry.path(), aDestDir / aName);
	}
}

void Sexy::ImportScreenSaverEarnings(const std::string& theSaveDir)
{
	fs::path aSrc = SaverContainerSaveDir();
	if (aSrc.empty())
		return;
	aSrc /= "userdata";

	std::error_code anErr;
	if (!fs::is_directory(aSrc, anErr))
		return;
	fs::path aDestDir = fs::path(theSaveDir) / "userdata";
	fs::create_directories(aDestDir, anErr);
	for (const auto& anEntry : fs::directory_iterator(aSrc, anErr))
	{
		const std::string aName = anEntry.path().filename().string();
		if (!IsEarningsFile(aName))
			continue;
		fs::path aDest = aDestDir / aName;
		// Keep a local file the game hasn't consumed yet unless the saver's
		// copy is newer; the nonce check rejects stale files either way.
		if (fs::exists(aDest, anErr) &&
			fs::last_write_time(aDest, anErr) >=
				fs::last_write_time(anEntry.path(), anErr))
			continue;
		fs::copy_file(anEntry.path(), aDest,
			fs::copy_options::overwrite_existing, anErr);
		if (!anErr)
			fs::remove(anEntry.path(), anErr);
	}
}

bool Sexy::SaverBridgePushFailed()
{
	return gPushFailed;
}

void Sexy::OpenFullDiskAccessSettings()
{
	const char* aURL =
		"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles";
	char* anArgv[] = { (char*)"open", (char*)aURL, nullptr };
	pid_t aChild = 0;
	posix_spawn(&aChild, "/usr/bin/open", nullptr, nullptr, anArgv,
		*_NSGetEnviron());
}

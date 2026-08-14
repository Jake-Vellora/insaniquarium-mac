#ifndef __SAVERBRIDGE_H__
#define __SAVERBRIDGE_H__

#include <string>

namespace Sexy
{
	// The Insaniquarium screensaver runs sandboxed inside legacyScreenSaver and
	// can only touch its own container, so the game bridges saves both ways
	// (the macOS equivalent of the junction-point fix the Windows Steam release
	// needed). The Windows original had the screensaver and the game share one
	// save directory outright, so screensaver play simply continued the same
	// tank; copying in both directions is how we get that back here.

	// Copies the game's userdata/ and registry.regemu into the screensaver's
	// container, preserving modification times so ImportSaverTank can tell the
	// screensaver's own writes apart from ours, and removing container files the
	// game no longer has (never scr<N>.dat - those are unspent earnings).
	// Returns false if anything could not be written; theThrottle skips the work
	// when the last push was moments ago, for the per-save call sites.
	bool	PushSavesToSaverContainer(const std::string& theSaveDir, bool theThrottle = false);

	// Brings the screensaver's tank (userdata/sim<N>.dat) back, but only when its
	// copy is newer than ours, so a screensaver session continues in the game.
	// Deliberately limited to the tank: user<N>.dat holds progress and unlocks,
	// and shells have their own nonce-validated path below.
	void	ImportSaverTank(const std::string& theSaveDir);

	// Moves the shells the screensaver earned (userdata/scr<N>.dat) back so the
	// game can credit them.
	void	ImportScreenSaverEarnings(const std::string& theSaveDir);

	// True when the last push failed, i.e. the screensaver is stuck showing an
	// old tank. Almost always missing Full Disk Access after an update re-signed
	// the app.
	bool	SaverBridgePushFailed();

	// Opens System Settings on the pane where that grant is given.
	void	OpenFullDiskAccessSettings();
}

#endif

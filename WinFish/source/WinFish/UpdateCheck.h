#ifndef __UPDATECHECK_H__
#define __UPDATECHECK_H__

#include <string>
#include <sys/types.h> // pid_t

namespace Sexy {

// Minimal update-check facade. The implementation (UpdateCheck.mm) uses
// NSURLSession to query the GitHub Releases API asynchronously; the game polls
// Poll() from its frame loop. No Objective-C types leak through this header, so
// it is safe to #include from plain C++ (.cpp) translation units.
class UpdateCheck
{
public:
	enum State { IDLE, PENDING, OK, FAILED };

	// Kick off an async GET of the latest-release info. No-op if already PENDING.
	static void        Start();
	// Thread-safe snapshot of the current state; call every frame.
	static State       Poll();
	// Latest release tag (e.g. "r2026-07-22"); valid when Poll()==OK. Empty if
	// the repo has no published release yet (treated as "up to date").
	static std::string LatestTag();
	// Human-readable error string (logging only); valid when Poll()==FAILED.
	static std::string Error();
	// Cancel any in-flight request and reset to IDLE. Safe to call anytime; a
	// late completion handler from the cancelled request becomes a no-op.
	static void        Cancel();

	// The release tag currently installed on this machine, read from
	// $PORTHOME/RELEASE. Empty if the marker is missing (dev/source build).
	static std::string InstalledTag();
	// True only for a real installed port: both $PORTHOME/RELEASE and
	// $PORTHOME/in-app-update.sh exist. Gates the whole feature so dev/source
	// builds never offer an update or spawn a doomed handoff.
	static bool        IsUpdatableInstall();

	// Spawn the detached updater ($PORTHOME/in-app-update.sh <gamePid>) fully
	// detached so it survives this process exiting. Returns false if the helper
	// is missing or the spawn failed (caller must then NOT quit the game).
	static bool        SpawnUpdater(pid_t gamePid);
};

} // namespace Sexy

#endif // __UPDATECHECK_H__

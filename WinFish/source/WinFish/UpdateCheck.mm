// Objective-C++ implementation of the in-app update check. Uses NSURLSession
// (HTTPS, runs on GCD background queues — no NSRunLoop pumping required, which
// is why the game polls Poll() from its frame loop) to hit the GitHub Releases
// API, and posix_spawn to hand off to the detached shell updater.
#import <Foundation/Foundation.h>

#include <cstdlib>
#include <fcntl.h>
#include <fstream>
#include <mutex>
#include <sstream>
#include <spawn.h>
#include <string>
#include <unistd.h>
#include <crt_externs.h> // _NSGetEnviron (the bundle-safe way to get environ)

#include "UpdateCheck.h"

namespace {

struct Shared {
	std::mutex               mtx;
	Sexy::UpdateCheck::State  state = Sexy::UpdateCheck::IDLE;
	std::string              tag;
	std::string              error;
	unsigned long            generation = 0; // bumped on Start()/Cancel() to drop stale completions
};

// Immortal singleton: never destroyed, so a late NSURLSession completion handler
// that outlives any game dialog can always safely lock and write into it.
Shared &G() { static Shared *s = new Shared(); return *s; }

std::string PortHome() {
	const char *home = getenv("HOME");
	std::string h = home ? home : "";
	return h + "/Library/Application Support/Insaniquarium-port";
}

std::string Trim(const std::string &s) {
	size_t a = s.find_first_not_of(" \t\r\n");
	if (a == std::string::npos) return "";
	size_t b = s.find_last_not_of(" \t\r\n");
	return s.substr(a, b - a + 1);
}

std::string ReadFileTrimmed(const std::string &path) {
	std::ifstream f(path.c_str());
	if (!f) return "";
	std::stringstream ss;
	ss << f.rdbuf();
	return Trim(ss.str());
}

NSString *ApiURL() {
	const char *ovr = getenv("INSANIQ_UPDATE_API"); // test override
	if (ovr && *ovr) return [NSString stringWithUTF8String:ovr];
	return @"https://api.github.com/repos/Jake-Vellora/insaniquarium-mac/releases/latest";
}

} // namespace

namespace Sexy {

void UpdateCheck::Start() {
	unsigned long myGen;
	{
		std::lock_guard<std::mutex> lk(G().mtx);
		if (G().state == PENDING) return;
		G().state = PENDING;
		G().tag.clear();
		G().error.clear();
		myGen = ++G().generation;
	}

	NSMutableURLRequest *req =
		[NSMutableURLRequest requestWithURL:[NSURL URLWithString:ApiURL()]];
	// GitHub returns 403 to requests without a User-Agent.
	[req setValue:@"insaniquarium-mac-updater" forHTTPHeaderField:@"User-Agent"];
	[req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
	req.timeoutInterval = 15.0;

	NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
		completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			State newState = FAILED;
			std::string tag, err;
			long code = 0;
			if ([response isKindOfClass:[NSHTTPURLResponse class]])
				code = (long)[(NSHTTPURLResponse *)response statusCode];

			if (error) {
				const char *d = error.localizedDescription.UTF8String;
				err = d ? d : "network error";
			} else if (code == 404) {
				// No release published yet -> up to date (empty tag).
				newState = OK;
				tag = "";
			} else if (code == 200 && data) {
				NSError *jerr = nil;
				id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jerr];
				if ([json isKindOfClass:[NSDictionary class]]) {
					id tn = ((NSDictionary *)json)[@"tag_name"];
					if ([tn isKindOfClass:[NSString class]]) {
						newState = OK;
						tag = [(NSString *)tn UTF8String];
					} else {
						err = "release JSON missing tag_name";
					}
				} else {
					err = "could not parse release JSON";
				}
			} else {
				std::ostringstream os;
				os << "HTTP " << code;
				err = os.str();
			}

			std::lock_guard<std::mutex> lk(G().mtx);
			if (myGen != G().generation) return; // superseded or cancelled
			G().state = newState;
			G().tag   = tag;
			G().error = err;
		}];
	[task resume];
}

UpdateCheck::State UpdateCheck::Poll() {
	std::lock_guard<std::mutex> lk(G().mtx);
	return G().state;
}

std::string UpdateCheck::LatestTag() {
	std::lock_guard<std::mutex> lk(G().mtx);
	return G().tag;
}

std::string UpdateCheck::Error() {
	std::lock_guard<std::mutex> lk(G().mtx);
	return G().error;
}

void UpdateCheck::Cancel() {
	std::lock_guard<std::mutex> lk(G().mtx);
	++G().generation; // any in-flight completion now no-ops
	G().state = IDLE;
	G().tag.clear();
	G().error.clear();
}

std::string UpdateCheck::InstalledTag() {
	return ReadFileTrimmed(PortHome() + "/RELEASE");
}

bool UpdateCheck::IsUpdatableInstall() {
	std::string ph = PortHome();
	return access((ph + "/RELEASE").c_str(), R_OK) == 0 &&
	       access((ph + "/in-app-update.sh").c_str(), X_OK) == 0;
}

bool UpdateCheck::SpawnUpdater(pid_t gamePid) {
	std::string ph     = PortHome();
	std::string script = ph + "/in-app-update.sh";
	if (access(script.c_str(), X_OK) != 0) return false;

	std::string log    = ph + "/in-app-update.log";
	std::string pidStr = std::to_string((long)gamePid);

	posix_spawn_file_actions_t fa;
	posix_spawn_file_actions_init(&fa);
	posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0);
	posix_spawn_file_actions_addopen(&fa, 1, log.c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
	posix_spawn_file_actions_adddup2(&fa, 1, 2);

	posix_spawnattr_t attr;
	posix_spawnattr_init(&attr);
	// New session id: the child is detached from our process group and survives
	// the game exiting moments later.
	posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSID);

	char *argv[] = {
		(char *)"bash",
		(char *)script.c_str(),
		(char *)pidStr.c_str(),
		NULL
	};

	pid_t child = 0;
	int rc = posix_spawn(&child, "/bin/bash", &fa, &attr, argv, *_NSGetEnviron());

	posix_spawn_file_actions_destroy(&fa);
	posix_spawnattr_destroy(&attr);
	return rc == 0;
}

} // namespace Sexy

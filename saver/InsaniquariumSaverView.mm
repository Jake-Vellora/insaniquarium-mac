// Insaniquarium Virtual Tank screensaver.
//
// Hosts the ported SexyAppFramework game in-process: this view owns a legacy
// GL 2.1 NSOpenGLContext, the game's GLInterface renders through it (glad
// resolves entry points from OpenGL.framework via the INSANIQ_SAVER path),
// and SDL runs headless (dummy video/audio drivers) for timers only.
//
// Defensive choices per the modern legacyScreenSaver bugs (Sonoma..Tahoe):
// own NSTimer instead of animateOneFrame, only ONE view instance runs the
// game (others draw black), and com.apple.screensaver.willstop => exit(0).

#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>

#include <cstdlib>
#include <string>

#include "WinFishApp.h"
#include <SexyAppFramework/SexyAppBase.h>
#include <SexyAppFramework/GLInterface.h>
#include <SexyAppFramework/WidgetManager.h>

static Sexy::WinFishApp* gSaverApp = nullptr;
static NSOpenGLContext* gSaverGLContext = nil;
static bool gGameOwnerClaimed = false;

static void SaverSwapHook()
{
	[gSaverGLContext flushBuffer];
}

@interface InsaniquariumSaverView : ScreenSaverView
{
	BOOL mOwnsGame;
	BOOL mGameStarted;
	NSTimer* mFrameTimer;
}
@end

@implementation InsaniquariumSaverView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
	self = [super initWithFrame:frame isPreview:isPreview];
	if (self)
	{
		mOwnsGame = NO;
		mGameStarted = NO;
		mFrameTimer = nil;
		[[NSDistributedNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(willStop:)
			name:@"com.apple.screensaver.willstop"
			object:nil];
	}
	return self;
}

- (void)willStop:(NSNotification*)note
{
	// legacyScreenSaver on Sonoma+ never tears instances down; exit cleanly
	// so piled-up instances can't leak the GL context or GPU memory.
	[mFrameTimer invalidate];
	if (mOwnsGame && gSaverApp != nullptr)
	{
		gSaverApp->Shutdown();
		gSaverApp = nullptr;
	}
	exit(0);
}

- (void)startAnimation
{
	[super startAnimation];

	if (!gGameOwnerClaimed)
	{
		gGameOwnerClaimed = true;
		mOwnsGame = YES;
	}
	if (!mOwnsGame)
		return;

	// 36 updates/sec is the game's native logic rate; 30fps present is plenty.
	mFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
		target:self selector:@selector(pumpFrame) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:mFrameTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation
{
	[super stopAnimation];
	[mFrameTimer invalidate];
	mFrameTimer = nil;
}

- (BOOL)setUpGame
{
	NSBundle* aBundle = [NSBundle bundleForClass:[self class]];
	NSString* aResources = [aBundle resourcePath];

	setenv("INSANIQ_SAVER", "1", 1);
	setenv("SDL_VIDEODRIVER", "dummy", 1);
	setenv("SDL_AUDIODRIVER", "dummy", 1);

	NSOpenGLPixelFormatAttribute attrs[] = {
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		0
	};
	NSOpenGLPixelFormat* aFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (aFormat == nil)
		return NO;
	gSaverGLContext = [[NSOpenGLContext alloc] initWithFormat:aFormat shareContext:nil];
	if (gSaverGLContext == nil)
		return NO;

	[gSaverGLContext setView:self];
	[gSaverGLContext makeCurrentContext];

	NSSize aBacking = [self convertSizeToBacking:self.bounds.size];
	Sexy::gGLHostDrawableWidth = (int)aBacking.width;
	Sexy::gGLHostDrawableHeight = (int)aBacking.height;
	Sexy::gGLSwapHook = SaverSwapHook;

	static const char* kArgs[] = { "insaniquarium", "-screensaver" };

	gSaverApp = new Sexy::WinFishApp();
	gSaverApp->SetArgs(2, (char**)kArgs);
	gSaverApp->mResourceDir = std::string([aResources fileSystemRepresentation]) + "/";
	Sexy::ChDir(gSaverApp->mResourceDir);

	// Read the player's real tank data; sandbox redirects any writes into the
	// legacyScreenSaver container, which is fine for a display-only saver.
	NSString* aSaveDir = [@"~/Library/Application Support/PopCap/Insaniquarium/"
		stringByExpandingTildeInPath];
	gSaverApp->mCustomSaveDir = std::string([aSaveDir fileSystemRepresentation]) + "/";

	gSaverApp->Init();

	// Mirror SexyAppBase::Start()'s loop preamble; frames come from our timer.
	gSaverApp->StartLoadingThread();
	gSaverApp->mRunning = true;
	uint32_t aNow = SDL_GetTicks();
	gSaverApp->mLastTime = aNow;
	gSaverApp->mLastUserInputTick = aNow;
	gSaverApp->mLastTimerTime = aNow;
	return YES;
}

- (void)pumpFrame
{
	if (!mGameStarted)
	{
		mGameStarted = YES;
		if (![self setUpGame])
			return;
	}
	if (gSaverApp == nullptr || gSaverGLContext == nil)
		return;

	if ([gSaverGLContext view] != self)
		[gSaverGLContext setView:self];
	[gSaverGLContext makeCurrentContext];

	NSSize aBacking = [self convertSizeToBacking:self.bounds.size];
	if ((int)aBacking.width != Sexy::gGLHostDrawableWidth ||
		(int)aBacking.height != Sexy::gGLHostDrawableHeight)
	{
		Sexy::gGLHostDrawableWidth = (int)aBacking.width;
		Sexy::gGLHostDrawableHeight = (int)aBacking.height;
		[gSaverGLContext update];
		if (gSaverApp->mGLInterface != nullptr)
		{
			gSaverApp->mGLInterface->UpdateViewport();
			gSaverApp->mWidgetManager->Resize(gSaverApp->mScreenBounds,
				gSaverApp->mGLInterface->mPresentationRect);
		}
	}

	gSaverApp->UpdateApp();
}

- (void)drawRect:(NSRect)rect
{
	if (!mOwnsGame)
	{
		[[NSColor blackColor] setFill];
		NSRectFill(rect);
	}
}

- (BOOL)hasConfigureSheet { return NO; }
- (NSWindow*)configureSheet { return nil; }

@end

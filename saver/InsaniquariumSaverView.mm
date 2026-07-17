// Insaniquarium Virtual Tank screensaver.
//
// Hosts the ported SexyAppFramework game in-process. Rendering goes through
// an NSOpenGLLayer (GL 2.1 legacy profile) because the legacyScreenSaver /
// WallpaperAgent host uses layer-backed views, where the classic
// [NSOpenGLContext setView:] path silently draws nothing. glad resolves GL
// entry points from OpenGL.framework (INSANIQ_SAVER path) and SDL runs
// headless (dummy video/audio drivers) for timers only.
//
// Defensive choices for the modern (Sonoma..Tahoe) saver-host bugs:
// - own NSTimer -> setNeedsDisplay, never animateOneFrame
// - the game binds to the MOST RECENT view to startAnimation (the Settings
//   preview may instantiate first; the real fullscreen instance then takes
//   over) — stale instances draw black
// - com.apple.screensaver.willstop => exit(0) so piled-up instances can't
//   leak the GL context
#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

#include <cstdlib>
#include <string>

#include "WinFishApp.h"
#include <SexyAppFramework/SexyAppBase.h>
#include <SexyAppFramework/GLInterface.h>
#include <SexyAppFramework/WidgetManager.h>

#define SAVER_LOG(fmt, ...) NSLog(@"InsaniqSaver: " fmt, ##__VA_ARGS__)

@class InsaniquariumSaverView;

static Sexy::WinFishApp* gSaverApp = nullptr;
static NSOpenGLContext* gMasterContext = nil;
static InsaniquariumSaverView* gOwnerView = nil;
static bool gGameInitTried = false;
static bool gGameInitOK = false;

static void SaverSwapHook()
{
	// The NSOpenGLLayer presents when drawInOpenGLContext returns; the game's
	// per-frame "swap" only needs to push the command stream.
	glFlush();
}

@interface InsaniquariumSaverView : ScreenSaverView
{
	NSTimer* mFrameTimer;
}
- (BOOL)setUpGameWithContextCurrent;
@end

@interface InsaniqGLLayer : NSOpenGLLayer
@property(nonatomic, assign) InsaniquariumSaverView* hostView;
@end

@implementation InsaniqGLLayer

- (NSOpenGLPixelFormat*)openGLPixelFormatForDisplayMask:(uint32_t)mask
{
	NSOpenGLPixelFormatAttribute attrs[] = {
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAScreenMask, mask,
		0
	};
	NSOpenGLPixelFormat* aFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (aFormat == nil)
	{
		SAVER_LOG(@"pixel format with screen mask failed; retrying generic");
		NSOpenGLPixelFormatAttribute aFallback[] = {
			NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
			NSOpenGLPFAColorSize, 24,
			NSOpenGLPFAAlphaSize, 8,
			0
		};
		aFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:aFallback];
	}
	return aFormat;
}

- (NSOpenGLContext*)openGLContextForPixelFormat:(NSOpenGLPixelFormat*)thePixelFormat
{
	// Share every layer context with one master share group so the game's
	// textures stay valid whichever view currently owns rendering.
	NSOpenGLContext* aContext =
		[[NSOpenGLContext alloc] initWithFormat:thePixelFormat shareContext:gMasterContext];
	if (gMasterContext == nil)
		gMasterContext = aContext;
	SAVER_LOG(@"created layer GL context (shared=%d)", gMasterContext != aContext);
	return aContext;
}

- (BOOL)canDrawInOpenGLContext:(NSOpenGLContext*)ctx
	pixelFormat:(NSOpenGLPixelFormat*)pf
	forLayerTime:(CFTimeInterval)t
	displayTime:(const CVTimeStamp*)ts
{
	return YES;
}

- (void)drawInOpenGLContext:(NSOpenGLContext*)theContext
	pixelFormat:(NSOpenGLPixelFormat*)thePixelFormat
	forLayerTime:(CFTimeInterval)theTime
	displayTime:(const CVTimeStamp*)theDisplayTime
{
	[theContext makeCurrentContext];

	if (self.hostView != gOwnerView)
	{
		glClearColor(0.f, 0.f, 0.f, 1.f);
		glClear(GL_COLOR_BUFFER_BIT);
		return;
	}

	if (!gGameInitTried)
	{
		gGameInitTried = true;
		gGameInitOK = [self.hostView setUpGameWithContextCurrent];
		SAVER_LOG(@"game init %@", gGameInitOK ? @"OK" : @"FAILED");
	}
	if (!gGameInitOK || gSaverApp == nullptr)
	{
		glClearColor(0.f, 0.f, 0.f, 1.f);
		glClear(GL_COLOR_BUFFER_BIT);
		return;
	}

	// Track this layer's backing size (per display / preview scaling)
	CGSize aSize = self.bounds.size;
	CGFloat aScale = self.contentsScale;
	int aWidth = (int)(aSize.width * aScale);
	int aHeight = (int)(aSize.height * aScale);
	if (aWidth > 0 && aHeight > 0 &&
		(aWidth != Sexy::gGLHostDrawableWidth || aHeight != Sexy::gGLHostDrawableHeight))
	{
		Sexy::gGLHostDrawableWidth = aWidth;
		Sexy::gGLHostDrawableHeight = aHeight;
		if (gSaverApp->mGLInterface != nullptr)
		{
			gSaverApp->mGLInterface->UpdateViewport();
			gSaverApp->mWidgetManager->Resize(gSaverApp->mScreenBounds,
				gSaverApp->mGLInterface->mPresentationRect);
		}
	}

	glClearColor(0.f, 0.f, 0.f, 1.f);
	glClear(GL_COLOR_BUFFER_BIT);

	// The layer surface is recycled between frames; force a full redraw.
	if (gSaverApp->mWidgetManager != nullptr)
		gSaverApp->mWidgetManager->MarkAllDirty();
	gSaverApp->UpdateApp();

	[super drawInOpenGLContext:theContext pixelFormat:thePixelFormat
		forLayerTime:theTime displayTime:theDisplayTime];
}

@end

@implementation InsaniquariumSaverView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
	self = [super initWithFrame:frame isPreview:isPreview];
	if (self)
	{
		SAVER_LOG(@"init frame=%.0fx%.0f preview=%d", frame.size.width, frame.size.height, (int)isPreview);
		self.wantsLayer = YES;
		[[NSDistributedNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(willStop:)
			name:@"com.apple.screensaver.willstop"
			object:nil];
	}
	return self;
}

- (CALayer*)makeBackingLayer
{
	InsaniqGLLayer* aLayer = [InsaniqGLLayer layer];
	aLayer.hostView = self;
	aLayer.asynchronous = NO;
	aLayer.needsDisplayOnBoundsChange = YES;
	aLayer.contentsScale = self.window != nil ? self.window.backingScaleFactor : 2.0;
	return aLayer;
}

- (void)viewDidChangeBackingProperties
{
	[super viewDidChangeBackingProperties];
	if (self.layer != nil && self.window != nil)
		self.layer.contentsScale = self.window.backingScaleFactor;
}

- (void)willStop:(NSNotification*)note
{
	SAVER_LOG(@"willstop -> exit(0)");
	[mFrameTimer invalidate];
	if (gOwnerView == self && gSaverApp != nullptr)
	{
		gSaverApp->Shutdown();
		gSaverApp = nullptr;
	}
	exit(0);
}

- (void)startAnimation
{
	[super startAnimation];
	// Most recent instance wins: the Settings preview may have claimed the
	// game first; the real fullscreen instance takes over here.
	gOwnerView = self;
	SAVER_LOG(@"startAnimation, owner now %p", self);

	if (mFrameTimer == nil)
	{
		mFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
			target:self selector:@selector(tick) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:mFrameTimer forMode:NSRunLoopCommonModes];
	}
}

- (void)tick
{
	[self.layer setNeedsDisplay];
}

- (void)stopAnimation
{
	[super stopAnimation];
	SAVER_LOG(@"stopAnimation %p", self);
	[mFrameTimer invalidate];
	mFrameTimer = nil;
}

- (BOOL)setUpGameWithContextCurrent
{
	NSBundle* aBundle = [NSBundle bundleForClass:[self class]];
	NSString* aResources = [aBundle resourcePath];
	SAVER_LOG(@"resources at %@", aResources);

	setenv("INSANIQ_SAVER", "1", 1);
	setenv("SDL_VIDEODRIVER", "dummy", 1);
	setenv("SDL_AUDIODRIVER", "dummy", 1);

	CGSize aSize = self.bounds.size;
	CGFloat aScale = self.layer != nil ? self.layer.contentsScale : 2.0;
	Sexy::gGLHostDrawableWidth = (int)(aSize.width * aScale);
	Sexy::gGLHostDrawableHeight = (int)(aSize.height * aScale);
	Sexy::gGLSwapHook = SaverSwapHook;

	static const char* kArgs[] = { "insaniquarium", "-screensaver" };

	gSaverApp = new Sexy::WinFishApp();
	gSaverApp->SetArgs(2, (char**)kArgs);
	gSaverApp->mResourceDir = std::string([aResources fileSystemRepresentation]) + "/";
	Sexy::ChDir(gSaverApp->mResourceDir);

	// Read the player's real tank data when the sandbox allows; writes are
	// container-redirected, which is fine for a display-only saver.
	NSString* aSaveDir = [@"~/Library/Application Support/PopCap/Insaniquarium/"
		stringByExpandingTildeInPath];
	gSaverApp->mCustomSaveDir = std::string([aSaveDir fileSystemRepresentation]) + "/";

	gSaverApp->Init();
	if (gSaverApp->mGLInterface == nullptr)
	{
		SAVER_LOG(@"Init produced no GLInterface (GL setup failed)");
		return NO;
	}

	// Mirror SexyAppBase::Start()'s preamble; frames come from the layer.
	gSaverApp->StartLoadingThread();
	gSaverApp->mRunning = true;
	uint32_t aNow = SDL_GetTicks();
	gSaverApp->mLastTime = aNow;
	gSaverApp->mLastUserInputTick = aNow;
	gSaverApp->mLastTimerTime = aNow;
	return YES;
}

- (BOOL)hasConfigureSheet { return NO; }
- (NSWindow*)configureSheet { return nil; }

@end

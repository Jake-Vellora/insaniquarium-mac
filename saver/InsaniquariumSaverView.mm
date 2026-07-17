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
#include <SexyAppFramework/GLImage.h>
#include <SexyAppFramework/WidgetManager.h>

// App extensions get sanitized environments and their NSLog output is often
// invisible, so diagnostics also go to a file in Application Support (which
// the sandbox transparently redirects into the legacyScreenSaver container).
static NSString* SaverAppSupportDir(void)
{
	static NSString* aDir = nil;
	if (aDir == nil)
	{
		NSArray* aPaths = NSSearchPathForDirectoriesInDomains(
			NSApplicationSupportDirectory, NSUserDomainMask, YES);
		aDir = aPaths.count > 0 ? aPaths[0] : @"/tmp";
	}
	return aDir;
}

static void SaverFileLog(NSString* theMessage)
{
	NSLog(@"InsaniqSaver: %@", theMessage);
	NSString* aPath = [SaverAppSupportDir() stringByAppendingPathComponent:@"InsaniqSaver.log"];
	// Start the log over past 512KB so it can't grow unbounded.
	NSDictionary* anAttrs = [[NSFileManager defaultManager]
		attributesOfItemAtPath:aPath error:nil];
	const char* aMode = (anAttrs != nil &&
		[anAttrs fileSize] > 512 * 1024) ? "w" : "a";
	NSString* aLine = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], theMessage];
	FILE* aFile = fopen(aPath.fileSystemRepresentation, aMode);
	if (aFile != nullptr)
	{
		fputs(aLine.UTF8String, aFile);
		fclose(aFile);
	}
}

#define SAVER_LOG(fmt, ...) SaverFileLog([NSString stringWithFormat:fmt, ##__VA_ARGS__])

@class InsaniquariumSaverView;

static Sexy::WinFishApp* gSaverApp = nullptr;
static NSOpenGLContext* gMasterContext = nil;
static InsaniquariumSaverView* gOwnerView = nil;
static bool gGameInitTried = false;
static bool gGameInitOK = false;

// The owner instance copies each finished frame here (contexts share one
// group), and every other instance mirrors it — so the Settings preview,
// grid thumbnail, and all displays show the tank at once. Double-buffered:
// mirrors run on other CA threads and must never sample a mid-copy texture.
static GLuint gFrameTex[2] = { 0, 0 };
static volatile int gPublishedTex = -1;
static volatile int gSharedFrameW = 0;
static volatile int gSharedFrameH = 0;

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
- (void)drawMirroredFrame;
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

	static NSMutableSet* aDrawLogged = nil;
	if (aDrawLogged == nil)
		aDrawLogged = [NSMutableSet set];
	NSValue* aKey = [NSValue valueWithPointer:(__bridge void*)self];
	if (![aDrawLogged containsObject:aKey])
	{
		[aDrawLogged addObject:aKey];
		SAVER_LOG(@"first draw for view %p (owner %p) %ldx%ld",
			self.hostView, gOwnerView,
			(long)(self.bounds.size.width * self.contentsScale),
			(long)(self.bounds.size.height * self.contentsScale));
	}

	// A drawing instance may claim the game if nobody owns it yet — the host
	// sometimes never starts animation on the instance that actually draws.
	// A substantially larger surface also takes over, so the game never
	// renders at grid-thumbnail resolution while fullscreen mirrors it.
	int aMyW = (int)(self.bounds.size.width * self.contentsScale);
	int aMyH = (int)(self.bounds.size.height * self.contentsScale);
	if (gOwnerView == nil ||
		(aMyW * aMyH > gSharedFrameW * gSharedFrameH * 3 / 2 && gSharedFrameW > 0))
		gOwnerView = self.hostView;

	if (self.hostView != gOwnerView)
	{
		[self drawMirroredFrame];
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

	// Shader programs are not shared across the context group: if ownership
	// moved to an instance with a different GL context (e.g. the user
	// switched savers and back, creating a fresh view), rebuild them there.
	static NSOpenGLContext* gGameContext = nil;
	if (gGameContext != theContext)
	{
		if (gGameContext != nil)
		{
			SAVER_LOG(@"game moving to new GL context; rebuilding shaders");
			Sexy::gGLForceContextReinit = true;
			gSaverApp->mGLInterface->Init(false);
			if (gSaverApp->mWidgetManager != nullptr)
			{
				gSaverApp->mWidgetManager->mImage = gSaverApp->mGLInterface->GetScreenImage();
				gSaverApp->mWidgetManager->MarkAllDirty();
			}
			// Force viewport/remap refresh for the new surface.
			Sexy::gGLHostDrawableWidth = 0;
			Sexy::gGLHostDrawableHeight = 0;
		}
		gGameContext = theContext;
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

	// Advance game logic, then force the draw: UpdateApp returns right after
	// an update succeeds, so Process()'s own draw branch (taken only on
	// no-update-due iterations) would never run under host-driven pumping.
	gSaverApp->UpdateApp();
	if (gSaverApp->mWidgetManager != nullptr)
		gSaverApp->mWidgetManager->MarkAllDirty();
	gSaverApp->DrawDirtyStuff();

	// Publish the finished frame (just the game's 4:3 presentation rect, not
	// this surface's letterbox bars) for mirror instances.
	if (gFrameTex[0] == 0)
		glGenTextures(2, gFrameTex);
	int aBack = (gPublishedTex + 1) & 1;
	Sexy::GLInterface* aGL = gSaverApp->mGLInterface;
	int aCopyX = 0, aCopyY = 0, aCopyW = aWidth, aCopyH = aHeight;
	if (aGL != nullptr && aGL->mPresentationRect.mWidth > 0)
	{
		aCopyX = aGL->mPresentationRect.mX;
		aCopyY = aGL->mPresentationRect.mY;
		aCopyW = aGL->mPresentationRect.mWidth;
		aCopyH = aGL->mPresentationRect.mHeight;
	}
	glBindTexture(GL_TEXTURE_2D, gFrameTex[aBack]);
	glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, aCopyX, aCopyY, aCopyW, aCopyH, 0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glBindTexture(GL_TEXTURE_2D, 0);
	glFlush();
	gSharedFrameW = aCopyW;
	gSharedFrameH = aCopyH;
	gPublishedTex = aBack;

	static long aPumpCount = 0;
	if ((++aPumpCount % 120) == 1)
		SAVER_LOG(@"pump %ld flushes %ld (view %p)", aPumpCount, Sexy::gGLFlushCount, self.hostView);

	[super drawInOpenGLContext:theContext pixelFormat:thePixelFormat
		forLayerTime:theTime displayTime:theDisplayTime];
}

// Draw the owner's published frame letterboxed into this layer (legacy
// fixed-function GL — these contexts never run the game's shader state).
- (void)drawMirroredFrame
{
	glClearColor(0.f, 0.f, 0.f, 1.f);
	glClear(GL_COLOR_BUFFER_BIT);
	int aTexIndex = gPublishedTex;
	if (aTexIndex < 0 || gSharedFrameW <= 0 || gSharedFrameH <= 0)
		return;

	int aMyW = (int)(self.bounds.size.width * self.contentsScale);
	int aMyH = (int)(self.bounds.size.height * self.contentsScale);
	if (aMyW <= 0 || aMyH <= 0)
		return;
	glViewport(0, 0, aMyW, aMyH);

	// Letterbox the source aspect into this surface, in NDC.
	float aScaleX = 1.f;
	float aScaleY = 1.f;
	float aSrcAspect = (float)gSharedFrameW / (float)gSharedFrameH;
	float aDstAspect = (float)aMyW / (float)aMyH;
	if (aDstAspect > aSrcAspect)
		aScaleX = aSrcAspect / aDstAspect;
	else
		aScaleY = aDstAspect / aSrcAspect;

	glUseProgram(0);
	glDisable(GL_BLEND);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, gFrameTex[aTexIndex]);
	glColor4f(1.f, 1.f, 1.f, 1.f);
	glBegin(GL_QUADS);
	glTexCoord2f(0.f, 0.f); glVertex2f(-aScaleX, -aScaleY);
	glTexCoord2f(1.f, 0.f); glVertex2f(aScaleX, -aScaleY);
	glTexCoord2f(1.f, 1.f); glVertex2f(aScaleX, aScaleY);
	glTexCoord2f(0.f, 1.f); glVertex2f(-aScaleX, aScaleY);
	glEnd();
	glBindTexture(GL_TEXTURE_2D, 0);
	glDisable(GL_TEXTURE_2D);
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
	// CoreAnimation drives the draw loop; the modern saver host calls
	// startAnimation off-main with no runloop, so timers are unreliable.
	aLayer.asynchronous = YES;
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

	// Belt-and-braces alongside the asynchronous layer; scheduled on the main
	// runloop because the host may call startAnimation from a threadpool.
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self->mFrameTimer == nil)
		{
			self->mFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
				target:self selector:@selector(tick) userInfo:nil repeats:YES];
			[[NSRunLoop mainRunLoop] addTimer:self->mFrameTimer forMode:NSRunLoopCommonModes];
		}
	});
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

	// Verification hook: a control file beside the installed bundle (readable
	// in-sandbox) carrying a frame number arms the frame-dump; the PNG lands
	// in (container-redirected) Application Support.
	NSString* aControl = [[[aBundle bundlePath] stringByDeletingLastPathComponent]
		stringByAppendingPathComponent:@"insaniq-autoshot.control"];
	NSString* aFrame = [NSString stringWithContentsOfFile:aControl
		encoding:NSUTF8StringEncoding error:nil];
	aFrame = [aFrame stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (aFrame.length > 0)
	{
		NSString* aShot = [NSString stringWithFormat:@"%@/insaniq-saver-proof.png:%@",
			SaverAppSupportDir(), aFrame];
		setenv("INSANIQ_AUTOSHOT", aShot.UTF8String, 1);
		SAVER_LOG(@"autoshot armed: %@", aShot);
	}

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

	// Tank data lives under Application Support/PopCap/Insaniquarium. Resolved
	// via NSSearchPath so the sandbox maps it into the legacyScreenSaver
	// container — the game app syncs its saves there so the saver can see
	// them (the sandbox cannot read the real per-user save dir).
	NSString* aSaveDir = [SaverAppSupportDir()
		stringByAppendingPathComponent:@"PopCap/Insaniquarium"];
	gSaverApp->mCustomSaveDir = std::string([aSaveDir fileSystemRepresentation]) + "/";
	SAVER_LOG(@"save dir %@", aSaveDir);

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

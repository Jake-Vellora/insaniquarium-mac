// Minimal host app for testing Insaniquarium.saver outside legacyScreenSaver:
// loads the bundle, instantiates its ScreenSaverView, runs it in a window.
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

int main(int argc, char* argv[])
{
	@autoreleasepool
	{
		if (argc < 2)
		{
			fprintf(stderr, "usage: SaverHost <path-to.saver>\n");
			return 2;
		}
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

		NSBundle* aBundle = [NSBundle bundleWithPath:@(argv[1])];
		if (aBundle == nil || ![aBundle load])
		{
			fprintf(stderr, "SaverHost: failed to load bundle %s\n", argv[1]);
			return 1;
		}
		Class aClass = [aBundle principalClass];
		if (aClass == nil)
		{
			fprintf(stderr, "SaverHost: no principal class\n");
			return 1;
		}

		NSRect aFrame = NSMakeRect(0, 0, 960, 720);
		NSWindow* aWindow = [[NSWindow alloc]
			initWithContentRect:aFrame
			styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
			backing:NSBackingStoreBuffered
			defer:NO];
		[aWindow setTitle:@"Insaniquarium Saver Host"];

		ScreenSaverView* aView = [[aClass alloc] initWithFrame:aFrame isPreview:NO];
		if (aView == nil)
		{
			fprintf(stderr, "SaverHost: view init failed\n");
			return 1;
		}
		[aWindow setContentView:aView];
		[aWindow makeKeyAndOrderFront:nil];
		[aWindow center];
		[NSApp activateIgnoringOtherApps:YES];

		[aView startAnimation];
		fprintf(stderr, "SaverHost: saver started\n");
		[NSApp run];
	}
	return 0;
}

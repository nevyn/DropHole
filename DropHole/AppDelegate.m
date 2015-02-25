#import "AppDelegate.h"
#import "DropHoleServer.h"

@interface AppDelegate () <DropHoleServerDelegate>
{
	NSSavePanel *_savePanel;
	NSMutableArray *_transfers;
}

@property (weak) IBOutlet NSWindow *window;
@property DropHoleServer *server;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	_server = [[DropHoleServer alloc] initWithDelegate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (void)server:(DropHoleServer*)server destinationForTransferRequest:(DropHoleFileTransferRequest*)request callback:(DropHoleURLProvider)callback
{
	_savePanel = [NSSavePanel savePanel];
	_savePanel.nameFieldStringValue = request.filename;
	NSInteger answer = [_savePanel runModal];
	if(answer == NSFileHandlingPanelCancelButton) {
		callback(nil);
	} else {
		DropHoleFileTransferStatus *status = callback(_savePanel.URL);
		if(status) {
			[[self mutableArrayValueForKey:@"transfers"] addObject:status];
		}
	}
	_savePanel = nil;
}

@end

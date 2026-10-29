// Exercise the actual adapter command handler using synthetic PID and transport.
#define MRMediaRemoteGetNowPlayingApplicationPID SelaTestGetPID
#define MRMediaRemoteGetNowPlayingInfo SelaTestGetInfo
#define MRMediaRemoteGetNowPlayingApplicationIsPlaying SelaTestGetPlaying
#import "../Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/MediaRemoteAdapter.m"
#include <assert.h>

static int testPID = 42;
static int sends = 0;
static BOOL changeDuringRead = NO;
void SelaTestGetPID(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationPIDCompletion completion) {
    if (changeDuringRead) { ++sGeneration; changeDuringRead = NO; }
    completion(testPID);
}
void SelaTestGetInfo(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingInfoCompletion completion) { completion(NULL); }
void SelaTestGetPlaying(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationIsPlayingCompletion completion) { completion(false); }
static Boolean captureSend(int command, CFDictionaryRef options, CFTypeRef origin, CFStringRef bundle,
                           unsigned int flags, dispatch_queue_t queue, void (^reply)(unsigned int, CFArrayRef)) {
    assert(CFEqual(bundle, CFSTR("test.synthetic.player")));
    assert(command == 4 || command == 2);
    sends++;
    return true;
}
static void resetSnapshot(void) {
    sToken = @"synthetic-token";
    sBundle = @"test.synthetic.player";
    sPID = 42;
    testPID = 42;
    sEnabled = [NSSet setWithArray:@[@2, @4]];
}
int main(void) {
    @autoreleasepool {
        _queue = dispatch_get_main_queue();
        sSendToApp = captureSend;
        resetSnapshot();
        executeInlineCommand(@"guarded synthetic-token 5"); // Previous not supported
        executeInlineCommand(@"guarded old-token 4");
        executeInlineCommand(@"next_track"); // legacy global command forbidden
        assert(sends == 0);
        executeInlineCommand(@"guarded synthetic-token 4");
        assert(sends == 1);
        executeInlineCommand(@"guarded synthetic-token 4"); // consumed token
        assert(sends == 1);
        resetSnapshot();
        testPID = 0; // active source disappears before command
        executeInlineCommand(@"guarded synthetic-token 2");
        assert(sends == 1);
        resetSnapshot();
        changeDuringRead = YES; // notification invalidates snapshot during PID check
        executeInlineCommand(@"guarded synthetic-token 2");
        assert(sends == 1);
        resetSnapshot();
        sSendToApp = NULL; // adapter limitation
        executeInlineCommand(@"guarded synthetic-token 4");
        assert(sends == 1);
        puts("Music transport guard tests passed (synthetic APIs)");
    }
}

//
//  AppDelegate.m
//  Spotify Now Playing
//
//  Created by Abel John on 5/14/19.
//  Copyright © 2019 Abel John. All rights reserved.
//

#import "AppDelegate.h"
#import "PFMoveApplication.h"
#import "SNPMenuBarTitleFormatter.h"

static NSString * const SNPNotificationStatePreferenceKey = @"SNPNotificationState";
static NSString * const SNPMenubarFormatPreferenceKey = @"SNPMenubarFormat";
static NSString * const SNPStartAtLoginPreferenceKey = @"SNPStartAtLogin";
static NSString * const SNPStartupInformationPreferenceKey = @"SNPStartupInformation";
static NSString * const SNPFirstLoginKey = @"SNPFirstLogin";

@interface AppDelegate ()

@property (nonatomic, strong) NSImage *currentAlbumArt;
@property (nonatomic, strong) NSImage *menubarImage;
@property (nonatomic, strong) NSString *currentSongName;
@property (nonatomic, strong) NSString *trackID;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenuItem *artworkMenuItem;
@property (nonatomic, strong) NSMenuItem *songMenuItem;
@property (nonatomic, strong) NSMenuItem *artistMenuItem;
@property (nonatomic, strong) NSMenuItem *albumMenuItem;
@property (nonatomic, strong) NSMenuItem *notificationStateMenuItem;
@property (nonatomic, strong) NSMenuItem *startAtLoginMenuItem;
@property (nonatomic, strong) NSTimer *titleRefreshTimer;
@property (nonatomic, strong) NSDate *playbackPositionReferenceDate;
@property (nonatomic) NSTimeInterval currentTrackDuration;
@property (nonatomic) NSTimeInterval currentPlaybackPosition;
@property (nonatomic) float panX;
@property (nonatomic) BOOL playing;


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    PFMoveToApplicationsFolderIfNecessary();
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{SNPMenubarFormatPreferenceKey: SNPDefaultMenubarFormat}];
    
    // show welcome screen
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPStartupInformationPreferenceKey]) {
        [self helpDialog];
    }
    
    // enable notifications by default on first startup
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPFirstLoginKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPFirstLoginKey];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPNotificationStatePreferenceKey];
    }
    
    // load menubar image
    self.menubarImage = [NSImage imageNamed:@"StatusBarIcon"];
    [self.menubarImage setTemplate:YES];
    
    // get app version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *appBuild = [infoDict objectForKey:@"CFBundleVersion"];
    
    // initialize status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // initialize gesture recognizer
    NSPressGestureRecognizer *press = [[NSPressGestureRecognizer alloc] init];
    press.minimumPressDuration = .75;
    press.target = self;
    press.delaysPrimaryMouseButtonEvents = true;
    press.allowableMovement = 50;
    press.action = @selector(longPressHandler:);
    NSPanGestureRecognizer *pan = [[NSPanGestureRecognizer alloc] init];
    pan.action = @selector(panHandler:);
    pan.target = self;
    [self.statusItem.button addGestureRecognizer:press];
    [self.statusItem.button addGestureRecognizer:pan];
    
    // initialize menu containers
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Spotify Now Playing"];
    NSMenu *optionsSubmenu = [[NSMenu alloc] initWithTitle:@"Options"];
    NSMenuItem *optionsMenu = [[NSMenuItem alloc] initWithTitle:@"Options" action:nil keyEquivalent:@""];
    
    // initialize main menu items
    self.artworkMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.songMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.artistMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.albumMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    
    // initialize options menu items
    NSMenuItem *menubarFormatMenuItem = [[NSMenuItem alloc] initWithTitle:@"Menubar format..." action:@selector(editMenubarFormat) keyEquivalent:@""];
    menubarFormatMenuItem.toolTip = @"Customize the menu bar title with track and playback time placeholders";
    self.notificationStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Song notifications" action:@selector(toggleNotifications) keyEquivalent:@""];
    self.notificationStateMenuItem.toolTip = @"Get a notification when a new song comes on";
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey];
    self.startAtLoginMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start at login" action:@selector(toggleStartAtLogin) keyEquivalent:@""];
    self.startAtLoginMenuItem.toolTip = @"Automatically launch SNP when starting up your computer";
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey];
    
    // set up menus
    [mainMenu addItem:self.artworkMenuItem];
    [mainMenu addItem:self.songMenuItem];
    [mainMenu addItem:self.artistMenuItem];
    [mainMenu addItem:self.albumMenuItem];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [optionsMenu setSubmenu:optionsSubmenu];
    [optionsSubmenu addItem:menubarFormatMenuItem];
    [optionsSubmenu addItem:self.notificationStateMenuItem];
    [optionsSubmenu addItem:self.startAtLoginMenuItem];
    [mainMenu addItem:optionsMenu];
    [mainMenu addItemWithTitle:@"Help" action:@selector(helpDialog) keyEquivalent:@""];
    [mainMenu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@"q"];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [mainMenu addItemWithTitle:@"Spotify Now Playing" action:nil keyEquivalent:@""];
    NSMenuItem *versionMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"v%@ by Abel John", appVersion] action:nil keyEquivalent:@""];
    versionMenuItem.toolTip = [NSString stringWithFormat:@"Build %@", appBuild];
    [mainMenu addItem:versionMenuItem];
    [self.statusItem setMenu:mainMenu];
    // initialize song
    @try {
        self.trackID = [[NSString alloc] initWithString:[[self executeAppleScript:@"get id of current track"] stringValue]];
        self.playing = [[[self executeAppleScript:@"get player state"] stringValue] isEqualToString:@"kPSP"];
        self.currentSongName = [[NSString alloc] initWithString:[[self executeAppleScript:@"get name of current track"] stringValue]];
        self.songMenuItem.title = self.currentSongName;
        self.artistMenuItem.title = [[self executeAppleScript:@"get artist of current track"] stringValue];
        self.albumMenuItem.title =[[self executeAppleScript:@"get album of current track"] stringValue];
        self.currentTrackDuration = [self trackDurationFromSpotify];
        [self refreshPlaybackPositionFromSpotify];
        [self updateTitle];
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
        [self setImage];
        [self showNotification];
        
    }
    @catch (NSException *e) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.currentTrackDuration = 0;
        self.currentPlaybackPosition = 0;
        self.playbackPositionReferenceDate = nil;
        self.statusItem.button.toolTip = @"Spotify Now Playing";
        [self updateTitleRefreshTimer];
    }
    
    // set up notification center
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:@"com.spotify.client.PlaybackStateChanged" object:nil];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self quit];
}

#pragma mark - helper functions

- (void)helpDialog
{
    NSAlert *alert = [[NSAlert alloc] init];
    {
        [alert setMessageText:@"Welcome to Spotify Now Playing!"];
        [alert setInformativeText:@"Spotify Now Playing gives you easy access to see what song is playing in Spotify!\n\nHelp:\nClick on SNP up in the menu bar to see information about the song that's currently playing.\nClick and hold to play/pause, and click and drag right/left to skip/go back.\n\nOptions:\nMenubar format: customize the menu bar title with {playbackSymbol}, {artist}, {title}, {album}, {position}, {duration}, and {remaining}.\nSong notifications: get a notification when a new song comes on.\nStart at login: automatically launch SNP when starting up your computer.\n\nEnjoy!\n-Abel John"];
        [alert addButtonWithTitle:@"Okay!"];
        [alert setShowsSuppressionButton:YES];
        NSCell *cell = [[alert suppressionButton] cell];
        [cell setControlSize:NSControlSizeSmall];
        [cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [cell setState:[[NSUserDefaults standardUserDefaults] boolForKey:SNPStartupInformationPreferenceKey]];
        [alert runModal];
        if ([[alert suppressionButton] state] == NSControlStateValueOn) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPStartupInformationPreferenceKey];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SNPStartupInformationPreferenceKey];
        }
    }
}

- (void)playbackStateChanged:(NSNotification *)aNotification
{
    if ([[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Stopped"]) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.currentTrackDuration = 0;
        self.currentPlaybackPosition = 0;
        self.playbackPositionReferenceDate = nil;
        self.statusItem.button.toolTip = @"Spotify Now Playing";
        [self updateTitleRefreshTimer];
    } else {
        self.playing = [[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"];
        if (![[[aNotification userInfo] objectForKey:@"Track ID"] isEqualToString:self.trackID]
            || ![[[aNotification userInfo] objectForKey:@"Name"] isEqualToString:self.currentSongName]) {
            self.trackID = [[aNotification userInfo] objectForKey:@"Track ID"];
            [self setImage];
            self.currentSongName = [[aNotification userInfo] objectForKey:@"Name"];
            self.songMenuItem.title = self.currentSongName;
            self.artistMenuItem.title = [[aNotification userInfo] objectForKey:@"Artist"];
            self.albumMenuItem.title = [[aNotification userInfo] objectForKey:@"Album"];
            self.currentTrackDuration = [self trackDurationFromSpotify];
            [self refreshPlaybackPositionFromSpotify];
            [self updateTitle];
            self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
            [self showNotification];
        } else {
            [self refreshPlaybackPositionFromSpotify];
            [self updateTitle];
        }
    }
}

- (void)toggleNotifications
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey] forKey:SNPNotificationStatePreferenceKey];
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey];
}

- (void)editMenubarFormat
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Menubar Format"];
    [alert setInformativeText:@"Use {playbackSymbol}, {artist}, {title}, {album}, {position}, {duration}, and {remaining}. Text inside [...] appears only when all placeholders in it have values."];
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Restore Defaults"];

    NSTextField *formatField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 420, 24)];
    formatField.stringValue = [self menubarFormat];
    formatField.placeholderString = SNPDefaultMenubarFormat;
    [alert setAccessoryView:formatField];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSUserDefaults standardUserDefaults] setObject:formatField.stringValue forKey:SNPMenubarFormatPreferenceKey];
        [self updateTitle];
    } else if (response == NSAlertThirdButtonReturn) {
        [[NSUserDefaults standardUserDefaults] setObject:SNPDefaultMenubarFormat forKey:SNPMenubarFormatPreferenceKey];
        [self updateTitle];
    } else {
        [self updateTitleRefreshTimer];
    }
}

- (void)toggleStartAtLogin
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey] forKey:SNPStartAtLoginPreferenceKey];
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey];
    [self setLoginItem];
}

- (void) setLoginItem
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey]) {
        [self enableLoginItem];
    } else {
        [self disableLoginItem];
    }
}

- (NSAppleEventDescriptor *)enableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"System Events\" to make login item at end with properties {path:\"%@\", hidden:false}", [[NSBundle mainBundle] bundlePath]]];
    return [script executeAndReturnError:NULL];
}

- (NSAppleEventDescriptor *)disableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to delete login item \"Spotify Now Playing\""];
    return [script executeAndReturnError:NULL];
}

- (void)showNotification
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey]) {
        return;
    }
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    if ([self.currentSongName length] == 0) {
        // don't fire notification if we don't know the song name yet
        return;
    }
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    
    notification.title = self.currentSongName;
    notification.subtitle = self.artistMenuItem.title;
    notification.informativeText = self.albumMenuItem.title;
    notification.soundName = nil;
    
    [notification setValue:@YES forKey:@"_showsButtons"];
    [notification setValue:@YES forKey:@"_ignoresDoNotDisturb"];
    
    notification.hasActionButton = true;
    notification.actionButtonTitle = @"Skip";
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    center = nil;
    notification = nil;
    return true;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    center = nil;

    NSUserNotificationActivationType num = notification.activationType;
    
    
    if (num == NSUserNotificationActivationTypeActionButtonClicked) {
        [self executeAppleScript:@"next track"];
    } else if (num == NSUserNotificationActivationTypeContentsClicked) {
        [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
    }
    
}

- (void)launchSpotify
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
}

- (void)longPressHandler:(NSGestureRecognizer*)sender
{
    if (sender.state == NSGestureRecognizerStateBegan) {
        [self executeAppleScript:@"playpause"];
    }
}

- (void)panHandler:(NSPanGestureRecognizer*)sender
{
    if (sender.state == NSGestureRecognizerStateBegan) {
        self.panX = 0.0;
    }
    self.panX += [sender velocityInView:sender.view].x;
    if (sender.state == NSGestureRecognizerStateEnded) {
        if (self.panX > 3000) {
            [self executeAppleScript:@"next track"];
        } else if (self.panX < -3000) {
            [self executeAppleScript:@"previous track"];
        }
    }
}

- (void)setImage
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://embed.spotify.com/oembed/?url=%@", self.trackID]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            //NSLog(@"Error,%@", [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                self.artworkMenuItem.image = nil;
                self.artworkMenuItem.title = @"Could not load album artwork";
                self.artworkMenuItem.action = @selector(setImage);
                self.artworkMenuItem.toolTip = @"Click to try again";
            });
        } else {
            //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
            NSMutableDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            NSURL *imageUrl = [NSURL URLWithString:parsedData[@"thumbnail_url"]];
            NSURLRequest *imageUrlRequest = [NSURLRequest requestWithURL:imageUrl];
            NSURLSession *imageSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionDataTask *imageTask = [imageSession dataTaskWithRequest:imageUrlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    //NSLog(@"Error,%@", [error localizedDescription]);
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        self.artworkMenuItem.image = nil;
                        self.artworkMenuItem.title = @"Could not load album artwork";
                        self.artworkMenuItem.action = @selector(setImage);
                        self.artworkMenuItem.toolTip = @"Click to try again";
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        self.currentAlbumArt = [[NSImage alloc] initWithData:data];
                        self.currentAlbumArt.size = CGSizeMake(200, 200);
                        self.artworkMenuItem.image = self.currentAlbumArt;
                        self.artworkMenuItem.title = @"";
                        self.artworkMenuItem.action = @selector(launchSpotify);
                        self.artworkMenuItem.toolTip = nil;
                    });
                }
            }];
            [imageTask resume];
            // if title was unavailable when song changed, add it now
            if ([self.currentSongName length] == 0) {
                NSString *parsedTitle = parsedData[@"title"];
                // make UI changes in main thread
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    self.currentSongName = parsedTitle;
                    [self updateTitle];
                    self.songMenuItem.title = self.currentSongName;
                    self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
                    [self showNotification];
                });
            }
        }
    }];
    [task resume];
}

- (void)updateTitle
{
    if ([self.currentSongName length] == 0) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        [self updateTitleRefreshTimer];
        return;
    }

    NSString *format = [self menubarFormat];
    NSString *position = @"";
    NSString *duration = @"";
    NSString *remaining = @"";
    if ([SNPMenuBarTitleFormatter formatUsesPlaybackTime:format]) {
        NSTimeInterval playbackPosition = [self estimatedPlaybackPosition];
        position = [self stringFromPlaybackTime:playbackPosition];
        if (self.currentTrackDuration > 0) {
            duration = [self stringFromPlaybackTime:self.currentTrackDuration];
            remaining = [NSString stringWithFormat:@"-%@", [self stringFromPlaybackTime:MAX(self.currentTrackDuration - playbackPosition, 0)]];
        }
    }

    self.statusItem.button.title = [SNPMenuBarTitleFormatter titleWithFormat:format
                                                                    songTitle:self.currentSongName
                                                                       artist:self.artistMenuItem.title
                                                                        album:self.albumMenuItem.title
                                                                     position:position
                                                                     duration:duration
                                                                    remaining:remaining
                                                                      playing:self.playing];
    [self preventBlankTitle];
    [self updateTitleRefreshTimer];
}

- (NSString *)menubarFormat
{
    NSString *format = [[NSUserDefaults standardUserDefaults] stringForKey:SNPMenubarFormatPreferenceKey];
    return format ?: SNPDefaultMenubarFormat;
}

- (void)updateTitleRefreshTimer
{
    if (self.playing && [self.currentSongName length] != 0 && [SNPMenuBarTitleFormatter formatUsesPlaybackTime:[self menubarFormat]]) {
        if (!self.titleRefreshTimer) {
            self.titleRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(titleRefreshTimerFired:) userInfo:nil repeats:YES];
        }
    } else {
        [self.titleRefreshTimer invalidate];
        self.titleRefreshTimer = nil;
    }
}

- (void)titleRefreshTimerFired:(NSTimer *)timer
{
    timer = nil;
    [self updateTitle];
}

- (void)refreshPlaybackPositionFromSpotify
{
    self.currentPlaybackPosition = [self playbackPositionFromSpotify];
    self.playbackPositionReferenceDate = [NSDate date];
}

- (NSTimeInterval)estimatedPlaybackPosition
{
    NSTimeInterval playbackPosition = self.currentPlaybackPosition;
    if (self.playing && self.playbackPositionReferenceDate) {
        playbackPosition += [[NSDate date] timeIntervalSinceDate:self.playbackPositionReferenceDate];
    }
    playbackPosition = MAX(playbackPosition, 0);
    if (self.currentTrackDuration > 0) {
        playbackPosition = MIN(playbackPosition, self.currentTrackDuration);
    }
    return playbackPosition;
}

- (NSTimeInterval)playbackPositionFromSpotify
{
    NSString *position = [[self executeAppleScript:@"get player position"] stringValue];
    return [position doubleValue];
}

- (NSTimeInterval)trackDurationFromSpotify
{
    NSString *duration = [[self executeAppleScript:@"get duration of current track"] stringValue];
    return [duration doubleValue] / 1000.0;
}

- (NSString *)stringFromPlaybackTime:(NSTimeInterval)time
{
    NSInteger totalSeconds = (NSInteger)time;
    if (totalSeconds < 0) {
        totalSeconds = 0;
    }

    NSInteger hours = totalSeconds / 3600;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger seconds = totalSeconds % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", hours, minutes, seconds];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", minutes, seconds];
}

- (void)preventBlankTitle
{
    if ([self.statusItem.button.title length] != 0) {
        self.statusItem.button.image = nil;
    } else {
        // if the menubar has no text then display the icon so the user can see where the app is
        self.statusItem.button.image = self.menubarImage;
    }
}

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"if application \"Spotify\" is running then tell application \"Spotify\" to %@", command]];
    return [script executeAndReturnError:NULL];
}

- (void)quit
{
    [self.titleRefreshTimer invalidate];
    self.titleRefreshTimer = nil;
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    [[NSApplication sharedApplication] terminate:self];
}
@end

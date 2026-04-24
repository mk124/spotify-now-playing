//
//  Spotify_Now_PlayingTests.m
//  Spotify Now PlayingTests
//
//  Created by Abel John on 5/14/19.
//  Copyright © 2019 Abel John. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "../Spotify Now Playing/SNPMenuBarTitleFormatter.h"

@interface Spotify_Now_PlayingTests : XCTestCase

@end

@implementation Spotify_Now_PlayingTests

- (void)testDefaultFormatUsesPlaybackSymbolArtistAndTitle {
    NSString *title = [SNPMenuBarTitleFormatter titleWithFormat:SNPDefaultMenubarFormat
                                                      songTitle:@"Sweet Disposition"
                                                         artist:@"The Temper Trap"
                                                          album:@"Conditions"
                                                        playing:YES];

    XCTAssertEqualObjects(title, @"▶ The Temper Trap - Sweet Disposition");
}

- (void)testOptionalSegmentIsHiddenWhenPlaceholderIsEmpty {
    NSString *title = [SNPMenuBarTitleFormatter titleWithFormat:SNPDefaultMenubarFormat
                                                      songTitle:@"Sweet Disposition"
                                                         artist:@""
                                                          album:@"Conditions"
                                                        playing:YES];

    XCTAssertEqualObjects(title, @"▶ Sweet Disposition");
}

- (void)testPausedPlaybackSymbol {
    NSString *title = [SNPMenuBarTitleFormatter titleWithFormat:@"{playbackSymbol} {title}"
                                                      songTitle:@"Sweet Disposition"
                                                         artist:@"The Temper Trap"
                                                          album:@"Conditions"
                                                        playing:NO];

    XCTAssertEqualObjects(title, @"⏸ Sweet Disposition");
}

- (void)testAlbumOptionalSegment {
    NSString *withAlbum = [SNPMenuBarTitleFormatter titleWithFormat:@"{title}[ ({album})]"
                                                          songTitle:@"Sweet Disposition"
                                                             artist:@"The Temper Trap"
                                                              album:@"Conditions"
                                                            playing:YES];
    NSString *withoutAlbum = [SNPMenuBarTitleFormatter titleWithFormat:@"{title}[ ({album})]"
                                                             songTitle:@"Sweet Disposition"
                                                                artist:@"The Temper Trap"
                                                                 album:@""
                                                               playing:YES];

    XCTAssertEqualObjects(withAlbum, @"Sweet Disposition (Conditions)");
    XCTAssertEqualObjects(withoutAlbum, @"Sweet Disposition");
}

- (void)testPlaybackTimePlaceholders {
    NSString *title = [SNPMenuBarTitleFormatter titleWithFormat:@"{position}/{duration} {remaining} {title}"
                                                      songTitle:@"Sweet Disposition"
                                                         artist:@"The Temper Trap"
                                                          album:@"Conditions"
                                                       position:@"1:23"
                                                       duration:@"3:45"
                                                      remaining:@"-2:22"
                                                        playing:YES];

    XCTAssertEqualObjects(title, @"1:23/3:45 -2:22 Sweet Disposition");
}

- (void)testPlaybackTimePlaceholderDetection {
    XCTAssertFalse([SNPMenuBarTitleFormatter formatUsesPlaybackTime:SNPDefaultMenubarFormat]);
    XCTAssertTrue([SNPMenuBarTitleFormatter formatUsesPlaybackTime:@"{position} {title}"]);
    XCTAssertTrue([SNPMenuBarTitleFormatter formatUsesPlaybackTime:@"{duration} {title}"]);
    XCTAssertTrue([SNPMenuBarTitleFormatter formatUsesPlaybackTime:@"{remaining} {title}"]);
}

@end

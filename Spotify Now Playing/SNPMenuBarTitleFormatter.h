#import <Foundation/Foundation.h>

extern NSString * const SNPDefaultMenubarFormat;

@interface SNPMenuBarTitleFormatter : NSObject

+ (NSString *)titleWithFormat:(NSString *)format
                    songTitle:(NSString *)songTitle
                       artist:(NSString *)artist
                        album:(NSString *)album
                      playing:(BOOL)playing;

+ (NSString *)titleWithFormat:(NSString *)format
                    songTitle:(NSString *)songTitle
                       artist:(NSString *)artist
                        album:(NSString *)album
                     position:(NSString *)position
                     duration:(NSString *)duration
                    remaining:(NSString *)remaining
                      playing:(BOOL)playing;

+ (BOOL)formatUsesPlaybackTime:(NSString *)format;

@end

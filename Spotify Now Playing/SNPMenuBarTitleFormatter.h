#import <Foundation/Foundation.h>

extern NSString * const SNPDefaultMenubarFormat;

@interface SNPMenuBarTitleFormatter : NSObject

+ (NSString *)titleWithFormat:(NSString *)format
                    songTitle:(NSString *)songTitle
                       artist:(NSString *)artist
                        album:(NSString *)album
                      playing:(BOOL)playing;

@end

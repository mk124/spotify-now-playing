#import "SNPMenuBarTitleFormatter.h"

NSString * const SNPDefaultMenubarFormat = @"{playbackSymbol} [{artist} - ]{title}";

@implementation SNPMenuBarTitleFormatter

+ (NSString *)titleWithFormat:(NSString *)format
                    songTitle:(NSString *)songTitle
                       artist:(NSString *)artist
                        album:(NSString *)album
                      playing:(BOOL)playing
{
    NSDictionary<NSString *, NSString *> *values = @{
        @"title": songTitle ?: @"",
        @"artist": artist ?: @"",
        @"album": album ?: @"",
        @"playbackSymbol": playing ? @"▶" : @"⏸"
    };
    NSString *formatString = format ?: SNPDefaultMenubarFormat;
    NSString *optionalText = [self stringByRenderingOptionalSegmentsInString:formatString values:values];
    NSString *title = [self stringByReplacingPlaceholdersInString:optionalText values:values];
    return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)stringByRenderingOptionalSegmentsInString:(NSString *)string values:(NSDictionary<NSString *, NSString *> *)values
{
    NSMutableString *result = [NSMutableString string];
    NSUInteger index = 0;

    while (index < string.length) {
        NSRange searchRange = NSMakeRange(index, string.length - index);
        NSRange openRange = [string rangeOfString:@"[" options:0 range:searchRange];
        if (openRange.location == NSNotFound) {
            [result appendString:[string substringFromIndex:index]];
            break;
        }

        [result appendString:[string substringWithRange:NSMakeRange(index, openRange.location - index)]];

        NSRange closeSearchRange = NSMakeRange(openRange.location + 1, string.length - openRange.location - 1);
        NSRange closeRange = [string rangeOfString:@"]" options:0 range:closeSearchRange];
        if (closeRange.location == NSNotFound) {
            [result appendString:[string substringFromIndex:openRange.location]];
            break;
        }

        NSString *segment = [string substringWithRange:NSMakeRange(openRange.location + 1, closeRange.location - openRange.location - 1)];
        if ([self optionalSegmentHasValues:segment values:values]) {
            [result appendString:segment];
        }
        index = closeRange.location + 1;
    }

    return result;
}

+ (BOOL)optionalSegmentHasValues:(NSString *)segment values:(NSDictionary<NSString *, NSString *> *)values
{
    NSArray<NSTextCheckingResult *> *matches = [self placeholderMatchesInString:segment];
    for (NSTextCheckingResult *match in matches) {
        NSString *key = [segment substringWithRange:[match rangeAtIndex:1]];
        NSString *value = values[key] ?: @"";
        if ([[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
            return NO;
        }
    }
    return YES;
}

+ (NSString *)stringByReplacingPlaceholdersInString:(NSString *)string values:(NSDictionary<NSString *, NSString *> *)values
{
    NSMutableString *result = [string mutableCopy];
    NSArray<NSTextCheckingResult *> *matches = [self placeholderMatchesInString:string];

    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSString *key = [string substringWithRange:[match rangeAtIndex:1]];
        NSString *value = values[key] ?: @"";
        [result replaceCharactersInRange:match.range withString:value];
    }

    return result;
}

+ (NSArray<NSTextCheckingResult *> *)placeholderMatchesInString:(NSString *)string
{
    static NSRegularExpression *placeholderExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        placeholderExpression = [NSRegularExpression regularExpressionWithPattern:@"\\{([^{}]+)\\}" options:0 error:nil];
    });

    return [placeholderExpression matchesInString:string options:0 range:NSMakeRange(0, string.length)];
}

@end

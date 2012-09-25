//
//  MRRegularExpressionMatch.h
//  MRRegularExpressions
//

#import <Foundation/Foundation.h>
#import <oniguruma.h>


@class MRRegularExpression;


/**
 * Class to query the result of a regular expression match. Capture indexes are called "tags" to avoid confusion between capture indexes and character indexes.
 */
@interface MRRegularExpressionMatch : NSObject
{
	NSString *string;
	NSRange matchRange;
	OnigUChar *searchCharacters;
	OnigUChar *matchCharacters;
	OnigRegion *regions;
	NSDictionary *captureNameMap;
}

// Initializes an object that behaves like a match for the given string.
- (id)initWithMatchedString:(NSString *)pseudoMatchedString;

- (NSRange)range;

- (NSUInteger)numberOfSubstrings; // Does NOT include the match itself; substrings were not necessarily captured.

- (NSUInteger)tagOfFirstCapturedSubstring;
- (NSString *)nameOfFirstCapturedSubstring;
- (NSString *)firstCapturedSubstring;

- (NSUInteger)tagOfLastCapturedSubstring;
- (NSString *)nameOfLastCapturedSubstring;
- (NSString *)lastCapturedSubstring;

- (NSString *)stringBeforeMatch;
- (NSString *)stringAfterMatch;
- (NSString *)stringAfterPreviousMatch; // Only includes the string between matches

- (NSRange)rangeOfSubstringWithTag:(NSUInteger)index;
- (NSRange)rangeOfSubstringWithName:(NSString *)name;

- (NSString *)substringWithTag:(NSUInteger)index;
- (NSString *)substringWithName:(NSString *)name;

@end


@interface NSString (MRRegularExpressionMatching)

- (NSArray *)matchesForExpression:(MRRegularExpression *)searchExpression containedInRange:(NSRange)theSearchRange locatedInRange:(NSRange)theLocationRange limitCount:(NSUInteger)maxCount searchBackwards:(BOOL)searchBackwards;

@end

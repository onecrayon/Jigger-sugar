//
//  MRReplaceExpression.h
//  MRRegularExpressions
//

#import "MRRegularExpressionIncludes.h"
#import "MRRegularExpressionMatch.h"


#define RXReplaceDefaultOptions RXReplaceAllowDollarBackreferences

extern const RXUInteger RXReplaceNoOption;
extern const RXUInteger RXReplaceAllowDollarBackreferences;


@interface MRReplaceExpression : NSObject
{
	NSMutableArray *pieces;
	NSMutableArray *pieceTypes;
	NSMutableArray *_nameArray;
	BOOL hasConditionals;
}

- (id)initWithString:(NSString *)string;
- (id)initWithString:(NSString *)string options:(RXUInteger)options;
//- (id)initWithString:(NSString *)replaceString escapeCharacter:(unichar)escapeCharacter;

+ (id)expressionWithString:(NSString *)string;

- (NSString *)replacementStringForMatch:(MRRegularExpressionMatch *)match;
- (NSString *)replacementStringForString:(NSString *)matchedString; // Assumes a match for the full string, at range location 0

@end

//
//  MRRegularExpression.h
//  MRRegularExpressions
//

#import "MRRegularExpressionIncludes.h"


extern const RXUInteger RXDefaultCompileOptions;
extern const RXUInteger RXNoOption;

// Options for compiling the expression
extern const RXUInteger RXSingleLine; // '^' -> '\A', '$' -> '\z', '\Z' -> '\z'
extern const RXUInteger RXDisableSingleLine; // disable single line mode, which is enabled by default in some syntaxes
extern const RXUInteger RXMultiLine; // . matches newlines
extern const RXUInteger RXCaseInsensitive; // case insensitive matching
extern const RXUInteger RXFindLongestMatch; // find the longest possible match
extern const RXUInteger RXIgnoreEmptyMatch; // ignore empty matches
extern const RXUInteger RXCaptureNamedGroupsOnly; // capture named groups only (/.../g)
extern const RXUInteger RXCaptureAllGroups; // capture named and unnamed groups (/.../G)

// Syntax options
extern const RXUInteger RXEnableCaptureHistory;

// Match context
typedef enum {
	MRRegularExpressionSearchContext, // Only needs the characters in the search range
	MRRegularExpressionLineContext, // Needs all characters on the line
	MRRegularExpressionDocumentContext // Needs all characters in the entire document
} MRRegularExpressionContext;


@interface MRRegularExpression : NSObject <NSCopying>
{
	NSString *expressionString;
	RXUInteger options;
	MRRegularExpressionContext requiredMatchContext;
	regex_t *internalRegex;
}

- (id)initWithString:(NSString *)string;
- (id)initWithString:(NSString *)string options:(RXUInteger)options;
- (id)initWithString:(NSString *)string options:(RXUInteger)options error:(NSError **)outError;

+ (id)expressionWithString:(NSString *)string;
+ (id)expressionWithString:(NSString *)string options:(RXUInteger)options;

// Return a string suitable for embedding inside a regular expression, where it's treated literally.
// For example: you can pass @".*" and get a properly escaped string.
+ (NSString *)expressionStringForString:(NSString *)literalString;

- (NSString *)stringValue;
- (RXUInteger)options;

- (MRRegularExpressionContext)requiredContext; // The minimal context needed to reliably match this expression

- (regex_t *)_regex;

@end

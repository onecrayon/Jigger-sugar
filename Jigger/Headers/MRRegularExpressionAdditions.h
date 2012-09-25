//
//  MRRegularExpressionAdditions.h
//  MRRegularExpressions
//

#import <Foundation/Foundation.h>
#import "MRRegularExpression.h"
#import "MRReplaceExpression.h"


@interface NSString (MRRegularExpressionStringAdditions)

- (NSArray *)matchesForExpression:(MRRegularExpression *)searchExpression;
- (NSArray *)matchesForExpression:(MRRegularExpression *)searchExpression inRange:(NSRange)searchRange;
- (NSArray *)matchesForExpression:(MRRegularExpression *)searchExpression inRange:(NSRange)searchRange limitCount:(NSUInteger)maxCount;
- (NSArray *)matchesForExpression:(MRRegularExpression *)searchExpression inRange:(NSRange)searchRange limitCount:(NSUInteger)maxCount searchBackwards:(BOOL)searchBackwards;

- (MRRegularExpressionMatch *)firstMatchForExpression:(MRRegularExpression *)searchExpression inRange:(NSRange)searchRange;

@end

@interface NSMutableString (MRRegularExpressionStringAdditions)

- (void)replaceOccurrencesOfExpression:(MRRegularExpression *)s withExpression:(MRReplaceExpression *)r;
- (void)replaceOccurrencesOfExpression:(MRRegularExpression *)s withExpression:(MRReplaceExpression *)r options:(unsigned)options;
- (void)replaceOccurrencesOfExpression:(MRRegularExpression *)s withExpression:(MRReplaceExpression *)r options:(unsigned)options range:(NSRange)searchRange;
- (void)replaceOccurrencesOfExpression:(MRRegularExpression *)s withExpression:(MRReplaceExpression *)r options:(unsigned)options range:(NSRange)searchRange numberOfReplacements:(NSUInteger *)numberOfReplacements;

@end

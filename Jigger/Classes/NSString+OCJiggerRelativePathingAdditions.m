//
//  NSString+OCJiggerRelativePathingAdditions.m
//  Jigger.sugar
//
//  Created by Ian Beck on 1/31/14.
//
//

#import "NSString+OCJiggerRelativePathingAdditions.h"

@implementation NSString (OCJiggerRelativePathingAdditions)

- (NSString*)stringWithPathRelativeTo:(NSString*)anchorPath
{
	NSArray *pathComponents = [self pathComponents];
	NSArray *anchorComponents = [anchorPath pathComponents];
	
	NSInteger componentsInCommon = MIN([pathComponents count], [anchorComponents count]);
	for (NSInteger i = 0, n = componentsInCommon; i < n; i++) {
		if (![[pathComponents objectAtIndex:(NSUInteger) i] isEqualToString:[anchorComponents objectAtIndex:(NSUInteger) i]]) {
			componentsInCommon = i;
			break;
		}
	}
	
	NSUInteger numberOfParentComponents = [anchorComponents count] - componentsInCommon;
	NSUInteger numberOfPathComponents = [pathComponents count] - componentsInCommon;
	
	NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity:
										  numberOfParentComponents + numberOfPathComponents];
	for (NSInteger i = 0; i < numberOfParentComponents; i++) {
		[relativeComponents addObject:@".."];
	}
	[relativeComponents addObjectsFromArray:
	 [pathComponents subarrayWithRange:NSMakeRange((NSUInteger) componentsInCommon, numberOfPathComponents)]];
	return [NSString pathWithComponents:relativeComponents];
}

@end

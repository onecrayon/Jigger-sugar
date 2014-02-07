//
//  NSString+OCJiggerRelativePathingAdditions.h
//  Jigger.sugar
//
//  Created by Ian Beck on 1/31/14.
//
//

#import <Foundation/Foundation.h>

@interface NSString (OCJiggerRelativePathingAdditions)

// Modifies the string to a relative path with a root of anchorPath
// This code thanks to Hilton Campbell:
// http://stackoverflow.com/questions/6539273/objective-c-code-to-generate-a-relative-path-given-a-file-and-a-directory
- (NSString*)stringWithPathRelativeTo:(NSString*)anchorPath;

@end

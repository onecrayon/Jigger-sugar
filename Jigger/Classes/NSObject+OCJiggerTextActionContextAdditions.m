//
//  NSObject+OCJiggerTextActionContextAdditions.m
//  Jigger.sugar
//
//  Created by Ian Beck on 12/14/10.
//  Copyright 2010 One Crayon. MIT license.
//

#import "NSObject+OCJiggerTextActionContextAdditions.h"
#import <EspressoTextActions.h>


@implementation NSObject (OCJiggerTextActionContextAdditions)

// Get the word in the current context around the given index; the range is returned by reference
// 
// Defines a word as an alphanumeric character, or _
//
// Usage:
//   NSRange range;
//   [self getWordAtCursor:index range:&range];
- (NSString *)getWordAtCursor:(NSUInteger)cursor range:(NSRange *)range {
	return [self getWordAtCursor:cursor allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"_"] range:range];
}

// The extended version of getWordAtCursor:range:
// Allows you to pass a specific characterset to choose which non-alphanumeric characters are legal

- (NSString *)getWordAtCursor:(NSUInteger)cursor allowExtraCharacters:(NSCharacterSet *)extraChars range:(NSRange *)range {
	// Init memory-managed variables
	NSMutableString *word = [[NSMutableString alloc] initWithString:@""];
	NSMutableCharacterSet *legalChars = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	if (extraChars != nil) {
		[legalChars formUnionWithCharacterSet:extraChars];
	}
	NSString *lineText;
	
	// Init non-pointer variables
	NSUInteger maxindex = [[self string] length] - 1;
	unichar character;
	BOOL inword;
	NSInteger index = (NSInteger)cursor;
	NSUInteger firstindex, lastindex;
	// Vars for checking if the line ends with an HTML tag
	NSUInteger linestart;
	BOOL lineEndsWithTag;

	if (index < maxindex) {
		inword = TRUE;
		// Parse forward until we hit the end of the word or document
		while (inword) {
			character = [[self string] characterAtIndex:(NSUInteger) index];
			// If word character, append and advance
			if ([legalChars characterIsMember:character]) {
				[word appendFormat:@"%C", character];
			} else {
				inword = NO;
			}
			index = index + 1;
			// End it if we're at the document end
			if (index == maxindex) {
				inword = NO;
			}
		}
	}
	// Set the last index of the word
	if (index <= maxindex) {
		lastindex = (NSUInteger) (index - 1);
	} else {
		lastindex = (NSUInteger) index;
	}
	// Ready to go backward, so reset index to one less than cursor location
	index = cursor - 1;
	// Only walk backwards if we aren't at the beginning of the document
	if (index >= 0) {
		inword = YES;
		while (inword) {
			character = [[self string] characterAtIndex:(NSUInteger) index];
			
			// Impossible for the line to the index to be an HTML tag if the character isn't a caret
			if (character != '>') {
				lineEndsWithTag = NO;
			} else {
				linestart = [[self lineStorage] lineStartIndexLessThanIndex:(NSUInteger) index];
				lineText = [[self string] substringWithRange:NSMakeRange(linestart, (NSUInteger) (index - linestart + 1))];
				// Not much point in loading up matches, so here's a regex approximation using NSPredicate
				// NSPredicate regex test courtesy of: http://www.stiefels.net/2007/01/24/regular-expressions-for-nsstring/
				// Using double backslashes to escape them
				NSString *regex = @".*(<\\/?[\\w:-]+[^>]*|\\s*(/|\\?|%|-{2,3}))>";
				NSPredicate *regextest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
				// Test it!
				lineEndsWithTag = [regextest evaluateWithObject:lineText];
			}
			
			if ([legalChars characterIsMember:character] && !lineEndsWithTag) {
				[word insertString:[NSString stringWithFormat:@"%C", character] atIndex:0];
				index = index - 1;
			} else {
				inword = NO;
			}
			if (index < 0) {
				inword = NO;
			}
		}
	}
	// Since index is left-aligned and we've overcompensated, need to increment +1
	firstindex = (NSUInteger) (index + 1);
	// Switch last index to length for use in range
    lastindex = lastindex - firstindex;
	
	// Cleanup
	[legalChars release];
	
	// Return our values!
	*range = NSMakeRange(firstindex, lastindex);
	return [word autorelease];
}

@end

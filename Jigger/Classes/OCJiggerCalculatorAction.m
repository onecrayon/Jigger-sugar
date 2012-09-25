//
//  OCJiggerCalculatorAction.m
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import "OCJiggerCalculatorAction.h"
#import "NSObject+OCJiggerTextActionContextAdditions.h"
#import "DDMathParser.h"
#import <EspressoTextActions.h>


@implementation OCJiggerCalculatorAction

@synthesize customSheet;
@synthesize calcField;

- (id)init {
	self = [super init];
	if (self) {
		NSString *numberRE = @"-?\\$?(?:\\.\\d+|\\d[\\d.]*)(?:[a-zA-Z]*|%?)";
		singleNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"^%@$", numberRE]];
		selNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", numberRE]];
		targetRanges = [[NSMutableArray alloc] init];
	}

	return self;
}


- (void)dealloc {
	MRRelease(singleNumberRE);
	MRRelease(selNumberRE);
	MRRelease(targetRanges);
	MRRelease(myContext);
	MRRelease(customSheet);
	MRRelease(calcField);
	[super dealloc];
}

- (BOOL)canPerformActionWithContext:(id)context {
	return YES;
}

- (NSString *)titleWithContext:(id)context {
	NSRange firstRange = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	if (firstRange.length == 0) {
		NSRange range;
		NSString *number = [context getWordAtCursor:firstRange.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%"] range:&range];
		if ([[number matchesForExpression:singleNumberRE] count] > 0) {
			return @"@number-single";
		}
	} else {
		return @"@number-selection";
	}
	return nil;
}

- (BOOL)performActionWithContext:(id)context error:(NSError **)outError {
	// Grab our range and figure out what we are working with
	NSRange range = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	NSString *startValue = @"";
	[targetRanges removeAllObjects];
	if (range.length == 0) {
		// No selection, so grab the number near the cursor if it exists
		NSRange numberRange;
		NSString *number = [context getWordAtCursor:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%"] range:&numberRange];
		if ([[number matchesForExpression:singleNumberRE] count] > 0) {
			startValue = number;
			[targetRanges addObject:[NSValue valueWithRange:numberRange]];
		} else {
			[targetRanges addObject:[NSValue valueWithRange:range]];
		}
	} else {
		// Find our target ranges
		NSArray *matches;
		for (NSValue *value in [context selectedRanges]) {
			range = [value rangeValue];
			matches = [[context string] matchesForExpression:selNumberRE inRange:range];
			for (MRRegularExpressionMatch *match in matches) {
				[targetRanges addObject:[NSValue valueWithRange:[match range]]];
			}
		}

		// Set our placeholder text
		if ([targetRanges count] == 1) {
			startValue = [[context string] substringWithRange:[[targetRanges objectAtIndex:0] rangeValue]];
		} else if ([targetRanges count] > 1) {
			startValue = @"##";
		} else {
			// No numbers in this selection; exit with a beep
			return NO;
		}
	}

	// Load in our GUI if it hasn't been loaded already
	if (!customSheet) {
		[NSBundle loadNibNamed:@"OCJiggerCalculatorSheet" owner:self];
		[calcField setDelegate:self];
		// Set our tokenizing character to something they are unlikely to ever use
		[calcField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
	}
	// Stick in the placeholder number or tag
	[calcField setStringValue:startValue];
	// Display the sheet
	[NSApp beginSheet:customSheet
	   modalForWindow:[context windowForSheet]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil
	];
	// Set the selection so that our cursor is at the end of the field
	NSText *fieldEditor = [customSheet fieldEditor:YES forObject:calcField];
	[fieldEditor setSelectedRange:NSMakeRange([[fieldEditor string] length], 0)];
	// Save our context for later
	myContext = [context retain];
	// Exit the action now that control has been passed to the sheet
	return YES;
}

- (IBAction) doSubmitSheet:(id)sender {
	[NSApp endSheet:customSheet returnCode:1];
}

- (IBAction) cancel:(id)sender {
	[NSApp endSheet:customSheet returnCode:0];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == 1) {
		// Grab our shared calculation string
		NSString *rootCalculation = [[calcField objectValue] componentsJoinedByString:@""];
		// Prep our recipe
		CETextRecipe *recipe = [CETextRecipe textRecipe];
		// Loop over our ranges and perform the calculations
		NSRange range;
		NSMutableString *calculation;
		NSNumber *total;
		NSString *totalStr;
		MRRegularExpression *moneyRE = [MRRegularExpression expressionWithString:@"\\$(\\d[\\d,]*(?:\\.\\d{0,2}))"];
		MRRegularExpression *suffixRE = [MRRegularExpression expressionWithString:@"(\\d+)([a-zA-Z]+)"];
		NSArray *matches;
		BOOL dollarOutput;
		NSString *suffix;
		// Configure currency output
		NSNumberFormatter *currencyFormatter = [[NSNumberFormatter alloc] init];
		[currencyFormatter setPositiveFormat:@"¤#0.00"];
		[currencyFormatter setNegativeFormat:@"-¤#0.00"];
		[currencyFormatter setCurrencySymbol:@"$"];
		for (NSValue *value in targetRanges) {
			// Grab our range, and determine our calculation
			range = [value rangeValue];
			calculation = [[rootCalculation stringByReplacingOccurrencesOfString:@"##" withString:[[myContext string] substringWithRange:range]] mutableCopy];
			// Clean up dollars and suffixes from our calculation
			// Check to see if we have any monetary values (output a dollar value if so)
			dollarOutput = NO;
			if ([[calculation matchesForExpression:moneyRE] count] > 0) {
				dollarOutput = YES;
				// Remove dollar signs for monetary values (since dollar is used as variable by DDMathParser)
				[calculation replaceOccurrencesOfExpression:moneyRE withExpression:[MRReplaceExpression expressionWithString:@"$1"]];
			}
			// Check to see if we have any suffixes
			suffix = @"";
			matches = [calculation matchesForExpression:suffixRE];
			if ([matches count] > 0) {
				// Grab the last suffix for appending after we calculate everything out
				suffix = [[matches objectAtIndex:([matches count] - 1)] substringWithTag:2];
				// Remove all suffixes to prevent screwing up DDMathParser
				[calculation replaceOccurrencesOfExpression:suffixRE withExpression:[MRReplaceExpression expressionWithString:@"$1"]];
			}
			// Calculate using DDMathParser
			total = [calculation numberByEvaluatingString];
			// If we are working with dollars, convert to dollars
			if (dollarOutput) {
				totalStr = [currencyFormatter stringFromNumber:total];
			} else if ([suffix length] > 0) {
				totalStr = [NSString stringWithFormat:@"%@%@", [total stringValue], suffix];
			} else {
				totalStr = [total stringValue];
			}
			if ([totalStr length] > 0) {
				[recipe replaceRange:range withString:totalStr];
			}
			// Release mutable copied calculation string
			[calculation release];
		}
		// Apply our text recipe
		[myContext applyTextRecipe:recipe];
		// Release variables
		[currencyFormatter release];
	}
	// Get rid of our sheet
	[sheet orderOut:self];
}

#pragma mark NSTokenFieldDelegate methods

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
	// Only display the "numbers" token as an actual token
	if ([representedObject isEqualToString:@"##"]) {
		return NSRoundedTokenStyle;
	} else {
		return NSPlainTextTokenStyle;
	}
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
	if ([representedObject isEqualToString:@"##"]) {
		return @"number";
	} else {
		return representedObject;
	}
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject {
	// Only allow editing of things other than the "numbers" token
	if ([representedObject isEqualToString:@"##"]) {
		return nil;
	} else {
		return representedObject;
	}
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	// Display a list of the represented numbers for the "numbers" token
	if ([representedObject isEqualToString:@"##"]) {
		return YES;
	} else {
		return NO;
	}
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
	// Builds out the actual list for the "numbers" token
	if (![representedObject isEqualToString:@"##"]) {
		return nil;
	}

	// Grab our numbers
	NSRange range;
	NSMutableArray *numbers = [NSMutableArray array];
	for (NSValue *value in targetRanges) {
		range = [value rangeValue];
		[numbers addObject:[[myContext string] substringWithRange:range]];
	}
	// Create our menu
	NSMenu *tokenMenu = [[[NSMenu alloc] init] autorelease];
	// Loop through our numbers and add them to the menu
	NSMenuItem *menuItem;
	for (NSString *number in numbers) {
		menuItem = [[NSMenuItem alloc] init];
		[menuItem setTitle:number];
		[tokenMenu addItem:menuItem];
		[menuItem release];
	}
	// Return our menu
	return tokenMenu;
}

// Custom handling for the enter key (always submit the sheet instead of tokenizing)
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
	if (command == @selector(insertNewline:)) {
		[self doSubmitSheet:self];
		return YES;
	}
	return NO;
}





// TODO: remove this if I can't find any use for the logic
- (void)selectCalculationAtIndex:(NSUInteger)index forContext:(id)context {
	// Setup our character sets for identifying the characters in the string
	NSMutableCharacterSet *startChars = [[NSCharacterSet decimalDigitCharacterSet] mutableCopy];
	[startChars addCharactersInString:@"."];
	NSCharacterSet *prefixChars = [NSCharacterSet characterSetWithCharactersInString:@"-$("];
	NSCharacterSet *endChars = [NSCharacterSet alphanumericCharacterSet];
	NSCharacterSet *suffixChars = [NSCharacterSet characterSetWithCharactersInString:@".%)"];
	NSCharacterSet *punctuationChars = [NSCharacterSet characterSetWithCharactersInString:@"^*/+-()"];
	NSCharacterSet *whitespaceChars = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *spaceChars = [NSCharacterSet whitespaceCharacterSet];
	// Setup our all-encompassing set
	NSMutableCharacterSet *legalChars = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	[legalChars addCharactersInString:@"($,.^*/+-%)"];
	[legalChars formUnionWithCharacterSet:spaceChars];

	// Parse backward from our index
	NSUInteger curIndex = index;
	NSUInteger lastStartCharIndex = curIndex;
	unichar character;
	unichar nextchar;
	NSMutableString	*word = [NSMutableString string];
	while (curIndex > 0) {
		// Grab the previous index
		curIndex--;
		character = [[context string] characterAtIndex:curIndex];
		if ([legalChars characterIsMember:character]) {
			// Are we working with a potential start character?
			if ([startChars characterIsMember:character]) {
				// Grab our previous character if we can
				if (curIndex > 0) {
					nextchar = [[context string] characterAtIndex:curIndex - 1];
				}
				// Set our lastStarCharIndex if the previous character means this could be a start character
				if (curIndex == 0 || [whitespaceChars characterIsMember:nextchar] || [punctuationChars characterIsMember:nextchar]) {
					lastStartCharIndex = curIndex;
					// If the previous character is a prefix, switch to using it instead
					if (curIndex > 0 && [prefixChars characterIsMember:nextchar]) {
						lastStartCharIndex--;
					}
				}
			}
		} else {
			// Not a legal character, so break out of our loop
			break;
		}
	}

	// Get setup for parsing to the right
	NSUInteger lastEndCharIndex = index;
	NSUInteger maxindex = [[context string] length] - 1;
	curIndex = index;
	BOOL prevCharWasBoundary = NO;
	if (lastStartCharIndex == index) {
		// There was nothing prior to the index that might have been a number, so we are at a boundary
		prevCharWasBoundary = YES;
	}
	while (curIndex <= maxindex) {
		character = [[context string] characterAtIndex:curIndex];
		if ([legalChars characterIsMember:character]) {
			if ([spaceChars characterIsMember:character] || [punctuationChars characterIsMember:character]) {
				// We track boundaries so that we can ensure that we have a start character when we run into it
				prevCharWasBoundary = YES;
			} else if (prevCharWasBoundary && ![startChars characterIsMember:character]) {
				// We are moving from a boundary character to a non-legal start character; break out of our loop
				break;
			} else if (prevCharWasBoundary && [startChars characterIsMember:character]) {
				// Moving into a legal number, so reset our character boundary watcher
				prevCharWasBoundary = NO;
			} else if ([endChars characterIsMember:character]) {
				// Grab our next character if we can
				if (curIndex < maxindex) {
					nextchar = [[context string] characterAtIndex:curIndex + 1];
				}
				// Set our lastEndCharIndex if the next character means this could be an end character
				if (curIndex == maxindex || [whitespaceChars characterIsMember:nextchar] || [punctuationChars characterIsMember:nextchar]) {
					lastEndCharIndex = curIndex;
					// If the next character is a suffix, switch to using it instead
					if (curIndex < maxindex && [suffixChars characterIsMember:nextchar]) {
						lastEndCharIndex++;
					}
				}
			}
		} else {
			// Not a legal character, so break out
			break;
		}
		// Increment our index
		curIndex++;
	}

	// If we have a range between our lastStartChar and lastEndChar, construct the selection
	if (lastStartCharIndex < lastEndCharIndex) {
		[context setSelectedRanges:[NSArray arrayWithObjects:[NSValue valueWithRange:NSMakeRange(lastStartCharIndex, lastEndCharIndex - lastStartCharIndex)], nil]];
	}

	// Release our mutable copied character sets
	[legalChars release];
	[startChars release];
}

@end

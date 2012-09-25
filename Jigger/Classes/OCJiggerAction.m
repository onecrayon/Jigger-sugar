//
//  OCJiggerAction.m
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import "OCJiggerAction.h"
#import "NSObject+OCJiggerTextActionContextAdditions.h"
#import "DDMathParser.h"
#import <EspressoTextActions.h>
#import <NSString+MRFoundation.h>


@implementation OCJiggerAction

@synthesize customSheet;
@synthesize calcField;
@synthesize tabView;

- (id)init {
	self = [super init];
	if (self) {
		NSString *numberRE = @"-?\\$?(?:\\.\\d+|\\d[\\d.]*)(?:[a-zA-Z]*|%?)";
		singleNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"^%@$", numberRE]];
		selNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", numberRE]];
		NSString *colorRE = @"#\\h{3,6}";
		singleColorRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"^%@$", colorRE]];
		selColorRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", colorRE]];
		numberRanges = [[NSMutableArray alloc] init];
		colorRanges = [[NSMutableArray alloc] init];
	}

	return self;
}


- (void)dealloc {
	MRRelease(singleNumberRE);
	MRRelease(selNumberRE);
	MRRelease(singleColorRE);
	MRRelease(selColorRE);
	MRRelease(numberRanges);
	MRRelease(colorRanges);
	MRRelease(startValue);
	MRRelease(myContext);
	MRRelease(customSheet);
	MRRelease(colorPanel);
	MRRelease(calcField);
	MRRelease(tabView);
	[super dealloc];
}

- (BOOL)canPerformActionWithContext:(id)context {
	return YES;
}

- (NSString *)titleWithContext:(id)context {
	NSRange firstRange = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	if (firstRange.length == 0) {
		NSRange range;
		NSString *number = [context getWordAtCursor:firstRange.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&range];
		NSArray *numberMatches = [number matchesForExpression:singleNumberRE];
		NSArray *colorMatches = [number matchesForExpression:singleColorRE];
		if ([numberMatches count] > 0 && [colorMatches count] > 0) {
			return @"single";
		} else if ([numberMatches count] > 0) {
			return @"@number-single";
		} else if ([colorMatches count] > 0) {
			return @"color-single";
		}
	} else {
		NSString *sel = [[context string] substringWithRange:firstRange];
		NSArray *numbersMatches = [sel matchesForExpression:selNumberRE];
		NSArray *colorsMatches = [sel matchesForExpression:selColorRE];
		if ([numbersMatches count] > 0 && [colorsMatches count] > 0) {
			return @"@selection";
		} else if ([numbersMatches count] > 0) {
			return @"@number-selection";
		} else if ([colorsMatches count] > 0) {
			return @"color-selection";
		}
	}
	return nil;
}

- (BOOL)performActionWithContext:(id)context error:(NSError **)outError {
	// Grab our range and figure out what we are working with
	NSRange range = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	startValue = @"";
	[numberRanges removeAllObjects];
	[colorRanges removeAllObjects];
	targetRange = NSMakeRange(NSNotFound, 0);
	if (range.length == 0) {
		// No selection, so grab the number/color near the cursor if it exists
		NSRange numberRange;
		NSString *number = [context getWordAtCursor:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&numberRange];
		if ([[number matchesForExpression:singleNumberRE] count] > 0) {
			startValue = number;
			[numberRanges addObject:[NSValue valueWithRange:numberRange]];
		}
		if ([[number matchesForExpression:singleColorRE] count] > 0) {
			startValue = number;
			[colorRanges addObject:[NSValue valueWithRange:numberRange]];
		}
		
		// If we don't have a color or number, then we are inserting a new one at the cursor
		if ([numberRanges count] == 0 && [colorRanges count] == 0) {
			targetRange = range;
		}
	} else {
		// Find our target ranges
		NSArray *numberMatches;
		NSArray *colorMatches;
		for (NSValue *value in [context selectedRanges]) {
			range = [value rangeValue];
			numberMatches = [[context string] matchesForExpression:selNumberRE inRange:range];
			colorMatches = [[context string] matchesForExpression:selColorRE inRange:range];
			for (MRRegularExpressionMatch *match in numberMatches) {
				[numberRanges addObject:[NSValue valueWithRange:[match range]]];
			}
			for (MRRegularExpressionMatch *match in colorMatches) {
				[colorRanges addObject:[NSValue valueWithRange:[match range]]];
			}
		}

		// Make sure we have *something* to adjust, and exit with a beep if not
		if ([numberRanges count] == 0 && [colorRanges count] == 0) {
			return NO;
		}
	}

	// We only don't need the GUI if the only thing available to modify is a color (since then we can just load the color panel)
	if ([numberRanges count] == 0 && [colorRanges count] > 0) {
		// Grab our first color if we don't have a startValue already
		if (MRIsEmptyString(startValue)) {
			startValue = [[context string] substringWithRange:[[colorRanges objectAtIndex:0] rangeValue]];
		}
		// Enable our color modification mode
		[self activateColorMode:self];
	} else {
		if (!customSheet) {
			[NSBundle loadNibNamed:@"OCJiggerCalculatorSheet" owner:self];
			[calcField setDelegate:self];
			// Set our tokenizing character to something they are unlikely to ever use
			[calcField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
		}
		
		// Immediately display the calculation controls if we only have numbers to work with
		if ([numberRanges count] > 0 && [colorRanges count] == 0) {
			// Enable calculation mode
			[self activateCalculateMode:self];
		} else {
			[tabView selectTabViewItemAtIndex:0];
		}
		
		// Display the sheet
		[NSApp beginSheet:customSheet
		   modalForWindow:[context windowForSheet]
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil
		 ];
	}
	// Save our context and startValue for later
	myContext = [context retain];
	[startValue retain];
	// Exit the action now that control has been passed to the sheet
	return YES;
}

- (IBAction)activateColorMode:(id)sender
{
	// Close this sheet if is open
	if ([[myContext windowForSheet] attachedSheet] != nil) {
		[self cancel:self];
	}
	
	colorPanel = [[NSColorPanel sharedColorPanel] retain];
	[colorPanel setContinuous:YES];
	// TODO: display the color palette modally, link up the action, and automatically insert colors when they change
}

- (IBAction)activateCalculateMode:(id)sender
{
	[tabView selectTabViewItemAtIndex:1];
	// Make sure we have a placeholder string
	if (MRIsEmptyString(startValue)) {
		// No need to retain startValue here since we only need to use it the once at this point
		if ([numberRanges count] == 1) {
			[startValue release];
			startValue = [[myContext string] substringWithRange:[[numberRanges objectAtIndex:0] rangeValue]];
		} else if ([numberRanges count] > 1) {
			[startValue release];
			startValue = @"##";
		}
	}
	
	// If we are working with a targetRange, then that means we are inserting something; stick it in our numberRanges array
	if (targetRange.location != NSNotFound) {
		[numberRanges addObject:[NSValue valueWithRange:targetRange]];
	}
	
	// Stick in the placeholder number or tag
	[calcField setStringValue:startValue];
	// Set the selection so that our cursor is at the end of the field
	[customSheet makeFirstResponder:calcField];
	NSText *fieldEditor = [customSheet fieldEditor:YES forObject:calcField];
	[fieldEditor setSelectedRange:NSMakeRange([[fieldEditor string] length], 0)];
	
}

- (IBAction)doSubmitSheet:(id)sender {
	[NSApp endSheet:customSheet returnCode:1];
}

- (IBAction)cancel:(id)sender {
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
		for (NSValue *value in numberRanges) {
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
	for (NSValue *value in numberRanges) {
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

@end

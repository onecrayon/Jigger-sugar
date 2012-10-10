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
@synthesize calcView;
@synthesize colorView;
@synthesize calcField;
@synthesize colorField;
@synthesize clearColorButton;
@synthesize colorPreview;
@synthesize dividerLine;

+ (void)load
{
	[super load];
	
	// This is really a bit of a hacky way to approach this, but it works...
	// Runs one-time initialization code upon bundle load
	// Setup the default preferences, in case they've never been modified
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:1] forKey:@"OCJiggerHexUseThreeCharacters"]];
	[defaults registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:1] forKey:@"OCJiggerHexUseLowercase"]];
	[defaults registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:1] forKey:@"OCJiggerUseCalibratedColors"]];
}

- (id)initWithDictionary:(NSDictionary *)dictionary bundlePath:(NSString *)bundlePath {
	self = [super init];
	if (self) {
		NSString *numberRE = @"-?\\$?(?:\\.\\d+|\\d[\\d.]*)(?:[a-zA-Z]*|%?)";
		singleNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"^%@$", numberRE]];
		selNumberRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:^|(?<!#)\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", numberRE]];
		NSString *colorRE = @"#(\\h{3}|\\h{6})";
		singleColorRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"^%@$", colorRE]];
		selColorRE = [[MRRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", colorRE]];
		numberRanges = [[NSMutableArray alloc] init];
		colorRanges = [[NSMutableArray alloc] init];
		// Check to see if we are working with an "edit all" action
		if ([dictionary objectForKey:@"target"] && [[[dictionary objectForKey:@"target"] lowercaseString] isEqualToString:@"all"]) {
			modifyAllFlag = YES;
		} else {
			modifyAllFlag = NO;
		}
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
	MRRelease(originalNumber);
	MRRelease(originalColor);
	MRRelease(myContext);
	MRRelease(customSheet);
	MRRelease(calcView);
	MRRelease(colorView);
	MRRelease(calcField);
	MRRelease(colorField);
	MRRelease(clearColorButton);
	MRRelease(colorPreview);
	MRRelease(dividerLine);
	[super dealloc];
}

- (BOOL)canPerformActionWithContext:(id)context {
	if (modifyAllFlag) {
		NSRange firstRange = [[[context selectedRanges] objectAtIndex:0] rangeValue];
		NSRange range;
		NSString *selText = (firstRange.length == 0 ? [context getWordAtCursor:firstRange.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&range] : [[context string] substringWithRange:firstRange]);
		NSArray *numberMatches = [selText matchesForExpression:singleNumberRE];
		NSArray *colorMatches = [selText matchesForExpression:singleColorRE];
		if ([colorMatches count] == 0 && [numberMatches count] == 0) {
			return NO;
		}
	}
	return YES;
}

- (NSString *)titleWithContext:(id)context {
	NSRange firstRange = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	NSString *selText;
	if (firstRange.length == 0) {
		NSRange range;
		selText = [context getWordAtCursor:firstRange.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&range];
	} else {
		selText = [[context string] substringWithRange:firstRange];
	}
	NSArray *numberMatches = [selText matchesForExpression:singleNumberRE];
	NSArray *colorMatches = [selText matchesForExpression:singleColorRE];
	
	if ([numberMatches count] > 0 && [colorMatches count] > 0 && firstRange.length > 0) {
		return @"@selection";
	} else if ([numberMatches count] > 0) {
		if (modifyAllFlag) {
			return @"@number-all";
		}
		return (firstRange.length == 0 ? @"@number-single" : @"number-selection");
	} else if ([colorMatches count] > 0) {
		if (modifyAllFlag) {
			return @"@color-all";
		}
		return (firstRange.length == 0 ? @"@color-single" : @"@color-selection");
	}
	return nil;
}

- (BOOL)performActionWithContext:(id)context error:(NSError **)outError {
	// Grab our range and figure out what we are working with
	[originalNumber release];
	originalNumber = @"";
	[originalColor release];
	originalColor = @"";
	[numberRanges removeAllObjects];
	[colorRanges removeAllObjects];
	targetRange = NSMakeRange(NSNotFound, 0);
	
	NSRange range = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	NSString *target;
	NSRange tempTargetRange;
	
	// If we are modifying all copies of a number or color, we need to find them all
	if (modifyAllFlag) {
		target = (range.length == 0 ? [context getWordAtCursor:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&tempTargetRange] : [[context string] substringWithRange:range]);
		NSMutableArray *matchArray = ([[target matchesForExpression:singleNumberRE] count] > 0 ? numberRanges : colorRanges);
		// Escape potentially problematic regex characters
		target = [[target stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"] stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
		NSArray *targetMatches = [[context string] matchesForExpression:[MRRegularExpression expressionWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", target]]];
		// Populate our object that tracks the ranges we need to replace
		for (MRRegularExpressionMatch *match in targetMatches) {
			[matchArray addObject:[NSValue valueWithRange:[match range]]];
		}
	} else if (range.length == 0) {
		// No selection, so grab the number/color near the cursor if it exists
		target = [context getWordAtCursor:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&tempTargetRange];
		if ([[target matchesForExpression:singleNumberRE] count] > 0) {
			originalNumber = target;
			[numberRanges addObject:[NSValue valueWithRange:tempTargetRange]];
		}
		if ([[target matchesForExpression:singleColorRE] count] > 0) {
			originalColor = target;
			[colorRanges addObject:[NSValue valueWithRange:tempTargetRange]];
		}
		
		// If we don't have a color or number, then we are inserting a new one at the cursor
		if ([numberRanges count] == 0 && [colorRanges count] == 0) {
			targetRange = tempTargetRange;
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
	
	// Load in our GUI
	if (!customSheet) {
		[NSBundle loadNibNamed:@"OCJiggerSheet" owner:self];
		[calcField setDelegate:self];
		// Set our tokenizing character to something they are unlikely to ever use
		[calcField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
	}

	if ([numberRanges count] == 0 && [colorRanges count] > 0) {
		// The only thing available to modify is a color
		// Grab our first color if we don't have a startValue already
		if (MRIsEmptyString(originalColor)) {
			originalColor = [[context string] substringWithRange:[[colorRanges objectAtIndex:0] rangeValue]];
		}
		// Enable our color modification mode
		[self showMode:OCJiggerColorMode hideOthers:YES];
		[self configureColorMode:originalColor];
	} else if ([numberRanges count] > 0 && [colorRanges count] == 0) {
		// We only have numbers to work with
		// Make sure we have a placeholder string
		if (MRIsEmptyString(originalNumber)) {
			if ([numberRanges count] == 1) {
				originalNumber = [[myContext string] substringWithRange:[[numberRanges objectAtIndex:0] rangeValue]];
			} else if ([numberRanges count] > 1) {
				originalNumber = @"##";
			}
		}
		// Enable calculation mode
		[self showMode:OCJiggerCalculateMode hideOthers:YES];
		[self configureCalculateMode:originalNumber];
	} else {
		// We either are adjusting both colors and numbers, or are inserting something (so display both and they can chose)
		[self showMode:OCJiggerCalculateMode hideOthers:NO];
		[self showMode:OCJiggerColorMode hideOthers:NO];
		// Configure our start values
		if (range.length == 0) {
			[self configureCalculateMode:originalNumber];
			[self configureColorMode:originalColor];
		} else {
			if ([numberRanges count] > 0) {
				if ([numberRanges count] == 1) {
					originalNumber = [[myContext string] substringWithRange:[[numberRanges objectAtIndex:0] rangeValue]];
				} else if ([numberRanges count] > 1) {
					originalNumber = @"##";
				}
				
			}
			[self configureCalculateMode:originalNumber];
			if ([colorRanges count] > 0) {
				originalColor = [[context string] substringWithRange:[[colorRanges objectAtIndex:0] rangeValue]];
			}
			[self configureColorMode:originalColor];
		}
	}
	
	// Configure the color preview and cancel button
	[colorPreview setHidden:YES];
	[clearColorButton setHidden:YES];
	
	// Display the sheet
	[NSApp beginSheet:customSheet
	   modalForWindow:[context windowForSheet]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil
	 ];
	
	// Save our context and original values for later
	myContext = [context retain];
	[originalNumber retain];
	// Make sure that we have an accurate color
	if (MRIsEmptyString(originalColor)) {
		originalColor = [self chosenHexColor];
	}
	[originalColor retain];
	// Exit the action now that control has been passed to the sheet
	return YES;
}

- (void)showMode:(OCJiggerMode)mode hideOthers:(BOOL)hideFlag
{
	// Toggle the alternate mode closed if we are only showing one
	NSRect newFrame = [customSheet frame];
	NSRect colorFrame = [colorView frame];
	if (hideFlag) {
		if (mode == OCJiggerCalculateMode) {
			if ([calcView isHidden] && ![colorView isHidden]) {
				// Since colorView was shown and calcView hidden, we need to adjust colorView's Y coordinate back
				colorFrame.origin.y = colorFrame.origin.y - [calcView frame].size.height;
			}
			if ([calcView isHidden]) {
				newFrame.size.height = newFrame.size.height + [calcView frame].size.height;
				[calcView setHidden:NO];
			}
			if (![colorView isHidden]) {
				newFrame.size.height = newFrame.size.height - [colorView frame].size.height;
				[colorView setHidden:YES];
			}
		} else if (mode == OCJiggerColorMode) {
			if (![calcView isHidden]) {
				// Since we are showing colorView and calcView was previously shown, we need to adjust colorView's Y coordinate
				colorFrame.origin.y = colorFrame.origin.y + [calcView frame].size.height;
			}
			if ([colorView isHidden]) {
				newFrame.size.height = newFrame.size.height + [colorView frame].size.height;
				[colorView setHidden:NO];
			}
			if (![calcView isHidden]) {
				newFrame.size.height = newFrame.size.height - [calcView frame].size.height;
				[calcView setHidden:YES];
			}
			[dividerLine setHidden:YES];
		}
	} else {
		if ([calcView isHidden] && ![colorView isHidden]) {
			// Since colorView was shown and calcView hidden, we need to adjust colorView's Y coordinate back
			colorFrame.origin.y = colorFrame.origin.y - [calcView frame].size.height;
		}
		if ([calcView isHidden]) {
			newFrame.size.height = newFrame.size.height + [calcView frame].size.height;
			[calcView setHidden:NO];
		}
		if ([colorView isHidden]) {
			newFrame.size.height = newFrame.size.height + [colorView frame].size.height;
			[colorView setHidden:NO];
		}
		[dividerLine setHidden:NO];
	}
	[colorView setFrame:colorFrame];
	[customSheet setFrame:newFrame display:YES];
}

- (void)configureCalculateMode:(NSString *)startValue
{
	// Stick in the placeholder number or tag
	[calcField setStringValue:startValue];
	// Set the selection so that our cursor is at the end of the field
	[customSheet makeFirstResponder:calcField];
	NSText *fieldEditor = [customSheet fieldEditor:YES forObject:calcField];
	[fieldEditor setSelectedRange:NSMakeRange([[fieldEditor string] length], 0)];
}

- (void)configureColorMode:(NSString *)startValue
{
	NSColor *color;
	if (MRIsEmptyString(startValue)) {
		// Default to something just shy of black, so that they can select true black and insert it
		startValue = @"#000101";
	}
	// Hex to color logic thanks to <http://mobiledevelopertips.com/general/using-nsscanner-to-convert-hex-to-rgb-color.html>
	// Separate into r, g, b substrings
	BOOL isShort = ([startValue length] == 4 ? YES : NO);
	NSRange range = NSMakeRange(1, (isShort ? 1 : 2));
	
	NSString *rString = [startValue substringWithRange:range];
	
	range.location = range.location + (isShort ? 1 : 2);
	NSString *gString = [startValue substringWithRange:range];
	
	range.location = range.location + (isShort ? 1 : 2);
	NSString *bString = [startValue substringWithRange:range];
	
	// Scan values
	unsigned int r, g, b;
	[[NSScanner scannerWithString:rString] scanHexInt:&r];
	[[NSScanner scannerWithString:gString] scanHexInt:&g];  
	[[NSScanner scannerWithString:bString] scanHexInt:&b];
	
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OCJiggerUseCalibratedColors"] integerValue] == 1) {
		color = [NSColor colorWithCalibratedRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:1.0f];
	} else {
		color = [NSColor colorWithDeviceRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:1.0f];
	}
	
	// Set our default color
	[colorField setColor:color];
}

- (NSString *)chosenHexColor
{
	NSColor *color;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([[defaults objectForKey:@"OCJiggerUseCalibratedColors"] integerValue] == 1) {
		color = [[colorField color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	} else {
		color = [[colorField color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	}
	NSString *colorString = [NSString stringWithFormat:@"#%0.2X%0.2X%0.2X", (int)([color redComponent] * 255), (int)([color greenComponent] * 255), (int)([color blueComponent] * 255)];
	if ([[defaults objectForKey:@"OCJiggerHexUseLowercase"] integerValue] == 1) {
		colorString = [colorString lowercaseString];
	}
	return colorString;
}

- (NSString *)shortestHexCodeWithHex:(NSString *)hexCode
{
	if ([hexCode characterAtIndex:1] == [hexCode characterAtIndex:2] && [hexCode characterAtIndex:3] == [hexCode characterAtIndex:4] && [hexCode characterAtIndex:5] == [hexCode characterAtIndex:6]) {
		return [NSString stringWithFormat:@"#%c%c%c", [hexCode characterAtIndex:1], [hexCode characterAtIndex:3], [hexCode characterAtIndex:5]];
	} else {
		return hexCode;
	}
}

- (IBAction)clearColorWell:(id)sender
{
	// Reset color well to default color
	[self configureColorMode:originalColor];
	[self updateColorPreview:self];
}

- (IBAction)updateColorPreview:(id)sender
{
	// Update our preview text
	NSString *chosenColor = [self chosenHexColor];
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OCJiggerHexUseThreeCharacters"] integerValue] == 1) {
		[colorPreview setStringValue:[self shortestHexCodeWithHex:chosenColor]];
	} else {
		[colorPreview setStringValue:chosenColor];
	}
	if ([chosenColor isEqualToString:[originalColor lowercaseString]] || [[self shortestHexCodeWithHex:chosenColor] isEqualToString:[originalColor lowercaseString]]) {
		// Since we are using the original color, hide our preview and clear button
		[colorPreview setHidden:YES];
		[clearColorButton setHidden:YES];
		if (targetRange.location != NSNotFound) {
			// We are working with an insert, so activate the calculation controls (we toggle them back and forth to ensure that only one thing can be inserted at a time)
			[calcField setEnabled:YES];
		}
	} else if ([colorPreview isHidden]) {
		// Unhide preview and button if they were previously hidden
		[colorPreview setHidden:NO];
		[clearColorButton setHidden:NO];
		// Disable the calcuation controls if we are inserting something
		if (targetRange.location != NSNotFound) {
			[calcField setEnabled:NO];
		}
	}
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
		// Grab our final color
		NSString *chosenColor = [self chosenHexColor];
		// Prep our recipe
		CETextRecipe *recipe = [CETextRecipe textRecipe];
		// Init shared variables
		NSRange range;
		if (([numberRanges count] > 0 || targetRange.location != NSNotFound) && ![rootCalculation isEqualToString:originalNumber]) {
			// We have a number to insert, so loop over our ranges and perform the calculations
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
			// Check to see if we are inserting a value
			if (targetRange.location != NSNotFound) {
				[numberRanges addObject:[NSValue valueWithRange:targetRange]];
			}
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
			// Release variables
			[currencyFormatter release];
		}
		
		// Now that we've processed numbers, check for colors
		if (([colorRanges count] > 0 || targetRange.location != NSNotFound) && (![chosenColor isEqualToString:[originalColor lowercaseString]] && ![[self shortestHexCodeWithHex:chosenColor] isEqualToString:[originalColor lowercaseString]])) {
			// Make sure we insert the smallest string possible
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OCJiggerHexUseThreeCharacters"] integerValue] == 1) {
				chosenColor = [self shortestHexCodeWithHex:chosenColor];
			}
			// Check to see if we are inserting from a targetRange
			if (targetRange.location != NSNotFound) {
				[colorRanges addObject:[NSValue valueWithRange:targetRange]];
			}
			for (NSValue *value in colorRanges) {
				range = [value rangeValue];
				[recipe replaceRange:range withString:chosenColor];
			}
		}
		
		// Apply our text recipe
		[myContext applyTextRecipe:recipe];
	}
	
	// Get rid of our sheet
	[sheet orderOut:self];
	
	// If we were inserting something, make sure to enable everything for next time
	if (targetRange.location != NSNotFound) {
		[calcField setEnabled:YES];
		[colorField setEnabled:YES];
	}
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

// Update the enabled state of the other controls if we are inserting something
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if (targetRange.location != NSNotFound) {
		if (![colorField isEnabled] && MRIsEmptyString([calcField stringValue])) {
			[colorField setEnabled:YES];
		} else if ([colorField isEnabled] && !MRIsEmptyString([calcField stringValue])) {
			[colorField setEnabled:NO];
		}
	}
}

@end

//
//  OCJiggerAction.m
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import "OCJiggerAction.h"
#import "DDMathParser.h"
#import "NSString+OCJiggerRelativePathingAdditions.h"
#import <NSString+MRFoundation.h>


// HACK: these are not exposed in the public Espresso API, but we need them to properly locate the root project directory
// DON'T TRY THIS AT HOME! YOUR SUGAR WILL LIKELY BREAK WITH FUTURE ESPRESSO UPDATES
@interface NSObject (OCShellActionPathInfo)
@property(readonly) NSURL *contextDirectoryURL;
@property(readonly) id document;
@property(readonly) id projectContext;
@end


// This is defined in TEA, but we need a category to prevent compiling errors
@interface NSObject (OCJiggerTextActionContextAdditions)
- (NSString *)getWordAtIndex:(NSUInteger)cursor range:(NSRange *)range;
- (NSString *)getWordAtIndex:(NSUInteger)cursor allowExtraCharacters:(NSCharacterSet *)extraChars range:(NSRange *)range;
@end


@implementation OCJiggerAction

@synthesize customSheet;
@synthesize tabView;
@synthesize changeAllView;
@synthesize calcField;
@synthesize colorField;
@synthesize clearColorButton;
@synthesize colorPreview;
@synthesize changeAllButton;
@synthesize changeAllNumber;
@synthesize accessoryView;
@synthesize rootRelativeButton;

+ (void)load
{
	[super load];
	
	// This is really a bit of a hacky way to approach this, but it works...
	// Runs one-time initialization code upon bundle load
	// Setup the default preferences, in case they've never been modified
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:@{
								 @"OCJiggerHexUseThreeCharacters": @YES,
								 @"OCJiggerHexUseLowercase": @YES,
								 @"OCJiggerUseCalibratedColors": @YES,
								 @"OCJiggerUseRootRelativeLinks": @NO
								 }];
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
		urlTargets = [SXSelectorGroup selectorGroupWithString:@"attribute-name.x-url + punctuation + string, attribute-name.x-url + punctuation + string *, support.function.css.x-url > punctuation.brace.round.begin + string, support.function.css.x-url > punctuation.brace.round.begin + string *, support.function.css.x-url > punctuation.brace.round.begin + x-url, support.function.css.x-url > punctuation.brace.round.begin + x-url + punctuation.brace.round.end"];
		
		// Configure DDMathParser to use % as percentages instead of modulus
		[[DDMathOperatorSet defaultOperatorSet] setInterpretsPercentSignAsModulo:NO];
	}

	return self;
}

- (BOOL)canPerformActionWithContext:(id)context {
	return YES;
}

- (NSString *)titleWithContext:(id)context {
	NSRange firstRange = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	NSString *selText;
	if ([urlTargets matches:[[context syntaxTree] zoneAtCharacterIndex:firstRange.location]]) {
		return @"@file-chooser";
	} else if (firstRange.length == 0) {
		NSRange range;
		selText = [context getWordAtIndex:firstRange.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&range];
	} else {
		selText = [[context string] substringWithRange:firstRange];
	}
	NSArray *numberMatches = [selText matchesForExpression:selNumberRE];
	NSArray *colorMatches = [selText matchesForExpression:selColorRE];
	
	if (numberMatches.count > 0 && colorMatches.count > 0 && firstRange.length > 0) {
		return @"@selection";
	} else if (numberMatches.count > 0) {
		return (numberMatches.count == 1 ? @"@number-single" : @"@number-selection");
	} else if (colorMatches.count > 0) {
		return (colorMatches.count == 1 ? @"@color-single" : @"@color-selection");
	}
	return nil;
}

- (BOOL)performActionWithContext:(id)context error:(NSError **)outError {
	// Save our context, so other methods can access it, and reset our variables that might have old data
	myContext = context;
	originalNumber = @"";
	originalColor = @"";
	// Locate our first range
	NSRange range = [[[context selectedRanges] objectAtIndex:0] rangeValue];
	// Test the first zone to see if we need the file picker
	SXZone *zone = [self zoneAtIndex:range.location forContext:context];
	if ([urlTargets matches:zone]) {
		// Find the string surrounding the URL
		SXSelectorGroup *target = [SXSelectorGroup selectorGroupWithString:@"string, x-url"];
		SXSelector *zoneFollowsURL = [SXSelector selectorWithString:@"x-url + *"];
		if ([zoneFollowsURL matches:zone]) {
			// We're after the actual URL, so adjust to the previous zone
			zone = [self zoneAtIndex:range.location - 1 forContext:context];
		} else {
			// Make sure we are at the root string or x-url zone
			while (![target matches:zone] && [zone parent]) {
				zone = [zone parent];
			}
		}
		
		// Grab our original path string by excluding the starting and ending punctuation
		NSRange zoneRange = zone.range;
		NSRange pathRange;
		SXSelector *plainURLZone = [SXSelector selectorWithString:@"x-url"];
		if ([plainURLZone matches:zone]) {
			// This is just a URL (not a string), so we just select the range
			pathRange = zone.range;
		} else {
			NSRange startPuncRange = [[zone childAtIndex:0] range];
			NSRange endPuncRange = [[zone childAtIndex:[zone childCount] - 1] range];
			pathRange = NSMakeRange(zoneRange.location + startPuncRange.length, zoneRange.length - startPuncRange.length - endPuncRange.length);
		}
		NSString *originalPathString = [[[context string] substringWithRange:pathRange] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
		
		// Construct the root URL that we'll use for the selector dialog
		NSURL *rootURL;
		if (originalPathString.length > 0) {
			if ([originalPathString hasPrefix:@"/"] || [originalPathString hasPrefix:@"\\"]) {
				rootURL = [self rootURLForContext:context];
				// Convert from a relative link, since that won't fly with the NSURL relative pathing
				originalPathString = [NSString stringWithFormat:@".%@", originalPathString];
			} else {
				// Path must be relative, so root is the directory containing the file
				rootURL = [self parentURLFromContext:context];
			}
			// Find the folder containing our previously selected file
			rootURL = [NSURL URLWithString:originalPathString relativeToURL:rootURL];
			// Make sure the path actually exists, and ensure that it's a directory
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:[rootURL path] isDirectory:&isDir]) {
				if (!isDir) {
					rootURL = [rootURL URLByDeletingLastPathComponent];
				}
			} else {
				rootURL = nil;
			}
		}
		
		// Ensure we have a rootURL, and grab our standard context if not
		if (!rootURL) {
			rootURL = [self rootURLForContext:context];
		}
		
		// TODO: save last accessed path in prefs, and if it is nested within rootURL then use it instead?
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Determine if we are in a project (so we can show the "root relative" checkbox)
		if ([self projectContextForContext:context] != nil) {
			[[NSBundle bundleForClass:[self class]] loadNibNamed:@"OCJiggerBrowseForURLAccessories" owner:self topLevelObjects:NULL];
			// Default to the last used state for the root relative checkbox
			[rootRelativeButton setState:[defaults boolForKey:@"OCJiggerUseRootRelativeLinks"]];
		} else {
			accessoryView = nil;
		}
		
		// Show the Open dialog, with optional "root relative" checkbox
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseDirectories:NO];
		[openPanel setCanChooseFiles:YES];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setDirectoryURL:rootURL];
		[openPanel setAccessoryView:accessoryView];
		[openPanel beginSheetModalForWindow:[context windowForSheet] completionHandler:^(NSInteger returnCode) {
			if (returnCode == NSFileHandlingPanelOKButton) {
				NSURL *targetURL = [[openPanel URLs] objectAtIndex:0];
				// Create our path (either root relative, or standard relative)
				NSString *relativePath;
				NSString *targetPath;
				if (accessoryView != nil && [rootRelativeButton state] == NSOnState) {
					targetPath = [[targetURL path] stringWithPathRelativeTo:[[self rootURLForContext:context] path]];
					if (![targetPath hasPrefix:@"../"]) {
						// They did indeed select something within this hierarchy; add our leading slash (if it's outside our hierarchy, then we just ignore the root relative setting because it's meaningless)
						targetPath = [NSString stringWithFormat:@"/%@", targetPath];
					}
				} else {
					targetPath = [[targetURL path] stringWithPathRelativeTo:[[self parentURLFromContext:context] path]];
				}
				
				// If we have a root relative checkbox, save its state to the preferences
				if (accessoryView != nil) {
					[defaults setBool:([rootRelativeButton state] == NSOnState) forKey:@"OCJiggerUseRootRelativeLinks"];
				}
				
				// Prep our recipe and shared variable for selecting stuff
				CETextRecipe *recipe = [CETextRecipe textRecipe];
				NSRange selection;
				
				// Replace the contents of our string with the new link
				[recipe replaceRange:pathRange withString:targetPath];
				selection = NSMakeRange(pathRange.location, targetPath.length);
				
				// Run the recipe and select the new contents of the string
				[context applyTextRecipe:recipe];
				[context setSelectedRanges:[NSArray arrayWithObject:[NSValue valueWithRange:selection]]];
			}
		}];
	} else {
		// Determine if we can "change all"
		NSRange changeAllRange;
		NSString *selText = (range.length == 0 ? [context getWordAtIndex:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&changeAllRange] : [[context string] substringWithRange:range]);
		NSArray *numberMatches = [selText matchesForExpression:singleNumberRE];
		NSArray *colorMatches = [selText matchesForExpression:singleColorRE];
		NSMutableArray *changeAllNumbers = [NSMutableArray array];
		NSMutableArray *changeAllColors = [NSMutableArray array];
		// Populate target array with the change all options
		if (colorMatches.count > 0 || numberMatches.count > 0) {
			NSMutableArray *matchArray = (numberMatches.count > 0 ? changeAllNumbers: changeAllColors);
			// Escape potentially problematic regex characters
			selText = [[selText stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"] stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
			NSArray *targetMatches = [[context string] matchesForExpression:[MRRegularExpression expressionWithString:[NSString stringWithFormat:@"(?:^|\\b|(?<=\\s))%@(?:$|\\b|(?=\\s))", selText]]];
			// Populate our object that tracks the ranges we need to replace
			for (MRRegularExpressionMatch *match in targetMatches) {
				[matchArray addObject:[NSValue valueWithRange:[match range]]];
			}
		}
		
		// Determine if we have a single item to modify, or if we might be working with multiple ones in a selection
		selectedNumbers = [NSMutableArray array];
		NSMutableArray *selectedColors = [NSMutableArray array];
		NSRange targetRange = NSMakeRange(NSNotFound, 0);
		if (range.length == 0) {
			NSString *target;
			NSRange tempTargetRange;
			// No selection, so grab the number/color near the cursor if it exists
			target = [context getWordAtIndex:range.location allowExtraCharacters:[NSCharacterSet characterSetWithCharactersInString:@"$-.%#"] range:&tempTargetRange];
			if ([[target matchesForExpression:singleNumberRE] count] > 0) {
				originalNumber = target;
				[selectedNumbers addObject:[NSValue valueWithRange:tempTargetRange]];
			}
			if ([[target matchesForExpression:singleColorRE] count] > 0) {
				originalColor = target;
				[selectedColors addObject:[NSValue valueWithRange:tempTargetRange]];
			}
			
			// If we don't have a color or number, then we are inserting a new one at the cursor
			if (selectedNumbers.count == 0 && selectedColors.count == 0) {
				targetRange = range;
			}
		} else {
			// Find our target ranges
			for (NSValue *value in [context selectedRanges]) {
				range = [value rangeValue];
				numberMatches = [[context string] matchesForExpression:selNumberRE inRange:range];
				colorMatches = [[context string] matchesForExpression:selColorRE inRange:range];
				for (MRRegularExpressionMatch *match in numberMatches) {
					[selectedNumbers addObject:[NSValue valueWithRange:[match range]]];
				}
				for (MRRegularExpressionMatch *match in colorMatches) {
					[selectedColors addObject:[NSValue valueWithRange:[match range]]];
				}
			}
			
			// Make sure we have *something* to adjust, and exit with a beep if not
			if (selectedNumbers.count == 0 && selectedColors.count == 0) {
				return NO;
			}
		}
		
		// Load in our GUI
		NSTabViewItem *calcView;
		NSTabViewItem *colorView;
		if (!customSheet) {
			[NSBundle loadNibNamed:@"OCJiggerSheet" owner:self];
			// Setup the calcField parsing
			[calcField setDelegate:self];
			// Set our tokenizing character to something user is unlikely to ever use
			[calcField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
		}
		// Save our tab view items so we can delete and re-add them at will
		calcView = [tabView tabViewItemAtIndex:0];
		colorView = [tabView tabViewItemAtIndex:1];
		
		// Select the first tab, to ensure that our configuring code doesn't throw us into an endless loop
		[tabView selectFirstTabViewItem:self];
		
		// Customize the GUI to only show the things we need
		if (selectedNumbers.count == 0 && selectedColors.count > 0) {
			// Only a color to work with
			// Grab our first color if we don't have a startValue already
			if (MRIsEmptyString(originalColor)) {
				originalColor = [[context string] substringWithRange:[[selectedColors objectAtIndex:0] rangeValue]];
			}
			// Enable our color modification mode
			[tabView removeTabViewItem:calcView];
			[self configureColorMode:originalColor];
		} else if (selectedNumbers.count > 0 && selectedColors.count == 0) {
			// We only have a number to work with
			// Make sure we have a placeholder string
			if (MRIsEmptyString(originalNumber)) {
				if (selectedNumbers.count == 1) {
					originalNumber = [[context string] substringWithRange:[[selectedNumbers objectAtIndex:0] rangeValue]];
				} else if (selectedNumbers.count > 1) {
					originalNumber = @"##";
				}
			}
			// Enable calculation mode
			[tabView removeTabViewItem:colorView];
			[self configureCalculateMode:originalNumber];
		} else {
			// We are inserting something, or are unsure about what to modify so provide both
			// Configure our start values
			if (range.length == 0) {
				[self configureCalculateMode:originalNumber];
				[self configureColorMode:originalColor];
			} else {
				if (selectedNumbers.count > 0) {
					if (selectedNumbers.count == 1) {
						originalNumber = [[context string] substringWithRange:[[selectedNumbers objectAtIndex:0] rangeValue]];
					} else if (selectedNumbers.count > 1) {
						originalNumber = @"##";
					}
					
				}
				[self configureCalculateMode:originalNumber];
				if (selectedColors.count > 0) {
					originalColor = [[context string] substringWithRange:[[selectedColors objectAtIndex:0] rangeValue]];
				}
				[self configureColorMode:originalColor];
			}
		}
		// Make sure that "change all" is only shown if we can, in fact, change all
		[changeAllButton setState:NSOffState];
		if (changeAllColors.count > 1 || changeAllNumbers.count > 1) {
			[changeAllView setHidden:NO];
			[changeAllNumber setStringValue:[NSString stringWithFormat:@"(%lx)", (changeAllNumbers.count > 0 ? changeAllNumbers.count : changeAllColors.count)]];
		} else {
			[changeAllView setHidden:YES];
		}
		
		// Configure the color preview and cancel button
		[colorPreview setHidden:YES];
		[clearColorButton setHidden:YES];
		
		// Make sure that we have an accurate color
		if (MRIsEmptyString(originalColor)) {
			originalColor = [self chosenHexColor];
		}
		
		// Display the sheet
		[[context windowForSheet] beginSheet:customSheet completionHandler:^(NSModalResponse response) {
			if (response == NSModalResponseOK) {
				// Grab our shared calculation string
				NSString *rootCalculation = [[calcField objectValue] componentsJoinedByString:@""];
				// Grab our final color
				NSString *chosenColor = [self chosenHexColor];
				// Prep our recipe
				CETextRecipe *recipe = [CETextRecipe textRecipe];
				// Init shared variables
				NSRange range;
				if ([tabView selectedTabViewItem] == calcView) {
					if (![rootCalculation isEqualToString:originalNumber] && ((changeAllNumbers.count > 0 && changeAllButton.state == NSOnState) || selectedNumbers.count > 0 || targetRange.location != NSNotFound)) {
						// Determine what ranges we are modifying
						NSMutableArray *numberRanges;
						if (changeAllNumbers.count > 0 && changeAllButton.state == NSOnState) {
							numberRanges = changeAllNumbers;
						} else {
							numberRanges = selectedNumbers;
							// Check to see if we are inserting a value
							if (targetRange.location != NSNotFound) {
								[numberRanges addObject:[NSValue valueWithRange:targetRange]];
							}
						}
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
						}
					}
				} else if ((![chosenColor isEqualToString:[originalColor lowercaseString]] && ![[self shortestHexCodeWithHex:chosenColor] isEqualToString:[originalColor lowercaseString]]) && ((changeAllColors.count > 0 && changeAllButton.state == NSOnState) || selectedColors.count > 0 || targetRange.location != NSNotFound)) {
					// Make sure we insert the smallest string possible
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OCJiggerHexUseThreeCharacters"]) {
						chosenColor = [self shortestHexCodeWithHex:chosenColor];
					}
					// Determine what ranges we are modifying
					NSMutableArray *colorRanges;
					if (changeAllColors.count > 0 && changeAllButton.state == NSOnState) {
						colorRanges = changeAllColors;
					} else {
						colorRanges = selectedColors;
						// Check to see if we are inserting a value
						if (targetRange.location != NSNotFound) {
							[colorRanges addObject:[NSValue valueWithRange:targetRange]];
						}
					}
					for (NSValue *value in colorRanges) {
						range = [value rangeValue];
						[recipe replaceRange:range withString:chosenColor];
					}
				}
				
				// Apply our text recipe
				[myContext applyTextRecipe:recipe];
			}
			
			// Order out the sheet and clean up after ourselves
			[customSheet orderOut:self];
			
			// Add our views back to the tab view for next time
			if ([tabView tabViewItemAtIndex:0] == colorView) {
				[tabView insertTabViewItem:calcView atIndex:0];
			} else if ([tabView tabViewItems].count == 1) {
				[tabView insertTabViewItem:colorView atIndex:1];
			}
		}];
	}
	
	// Exit the action now that control has been passed to the sheet
	return YES;
}

- (IBAction)doSubmitSheet:(id)sender {
	[[myContext windowForSheet] endSheet:customSheet returnCode:NSModalResponseOK];
}

- (IBAction)cancel:(id)sender {
	[[myContext windowForSheet] endSheet:customSheet returnCode:NSModalResponseCancel];
}

- (IBAction)calculationHelp:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/davedelong/DDMathParser/wiki/Operators"]];
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
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OCJiggerUseCalibratedColors"]) {
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
	if ([defaults boolForKey:@"OCJiggerUseCalibratedColors"]) {
		color = [[colorField color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	} else {
		color = [[colorField color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	}
	NSString *colorString = [NSString stringWithFormat:@"#%0.2X%0.2X%0.2X", (int)([color redComponent] * 255), (int)([color greenComponent] * 255), (int)([color blueComponent] * 255)];
	if ([defaults boolForKey:@"OCJiggerHexUseLowercase"]) {
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
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OCJiggerHexUseThreeCharacters"]) {
		[colorPreview setStringValue:[self shortestHexCodeWithHex:chosenColor]];
	} else {
		[colorPreview setStringValue:chosenColor];
	}
	if ([chosenColor isEqualToString:[originalColor lowercaseString]] || [[self shortestHexCodeWithHex:chosenColor] isEqualToString:[originalColor lowercaseString]]) {
		// Since we are using the original color, hide our preview and clear button
		[colorPreview setHidden:YES];
		[clearColorButton setHidden:YES];
	} else if ([colorPreview isHidden]) {
		// Unhide preview and button if they were previously hidden
		[colorPreview setHidden:NO];
		[clearColorButton setHidden:NO];
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

	// Create our menu
	NSMenu *tokenMenu = [[NSMenu alloc] init];
	// Loop through our numbers and add them to the menu
	NSMenuItem *menuItem;
	for (NSValue *range in selectedNumbers) {
		menuItem = [[NSMenuItem alloc] initWithTitle:[[myContext string] substringWithRange:[range rangeValue]] action:NULL keyEquivalent:@""];
		[tokenMenu addItem:menuItem];
	}
	// Return our menu
	return tokenMenu;
}

// Custom handling for the enter key (always submit the sheet instead of tokenizing)
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
	if (command == @selector(insertNewline:)) {
		[[myContext windowForSheet] endSheet:customSheet returnCode:NSModalResponseOK];
		return YES;
	}
	return NO;
}

#pragma URL handling methods

- (SXZone *)zoneAtIndex:(NSUInteger)index forContext:(id)context {
	SXZone *zone;
	if ([[context string] length] == index) {
		zone = [[context syntaxTree] rootZone];
	} else {
		zone = [[context syntaxTree] zoneAtCharacterIndex:index];
	}
	return zone;
}

- (NSURL *)parentURLFromContext:(id)context {
	NSURL *root = [[context documentContext] fileURL];
	if (root) {
		root = [root URLByDeletingLastPathComponent];
	}
	return root;
}

- (id)projectContextForContext:(id)context {
	// Differentiate project context based on Espresso 2.1 vs. 2.2 (where the private interface changed); both instances offer the same directoryURL method
	id doc = [[context windowForSheet] document];
	if ([[doc className] isEqualToString:@"ESProjectDocument"]) {
		// This grabs the project context for Espresso 2.0-2.1
		return doc;
	} else if ([[context documentContext] projectContext]) {
		// This grabs the project context for Espresso 2.2+
		return [[context documentContext] projectContext];
	} else {
		return nil;
	}
}

- (NSURL *)rootURLForContext:(id)context {
	// Working with an absolute path, so try it from the project root
	id projectContext = [self projectContextForContext:context];
	if (projectContext) {
		return [projectContext directoryURL];
	} else {
		// No project, so we need to grab the URL of the file's parent directory
		return [self parentURLFromContext:context];
	}
}

@end

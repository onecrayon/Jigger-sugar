//
//  OCJiggerAction.h
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import <Foundation/Foundation.h>
#import <MRRegularExpressionAdditions.h>
#import <EspressoTextActions.h>


@interface OCJiggerAction : NSObject <NSTokenFieldDelegate> {
@private
	MRRegularExpression *singleNumberRE;
	MRRegularExpression *selNumberRE;
	MRRegularExpression *singleColorRE;
	MRRegularExpression *selColorRE;
	NSString *originalNumber;
	NSString *originalColor;
	NSMutableArray *selectedNumbers;
	SXSelectorGroup *urlTargets;
	id myContext;
}

@property(retain) IBOutlet NSWindow *customSheet;
@property(retain) IBOutlet NSTabView *tabView;
@property(retain) IBOutlet NSView *changeAllView;
@property(retain) IBOutlet NSTextField *changeAllNumber;
@property(retain) IBOutlet NSTokenField *calcField;
@property(retain) IBOutlet NSColorWell *colorField;
@property(retain) IBOutlet NSButton *clearColorButton;
@property(retain) IBOutlet NSTextField *colorPreview;
@property(retain) IBOutlet NSButton *changeAllButton;
@property(retain) IBOutlet NSView *accessoryView;
@property(retain) IBOutlet NSButton *rootRelativeButton;

- (void)configureCalculateMode:(NSString *)startValue;
- (void)configureColorMode:(NSString *)startValue;
// Returns the six-digit hex code that the user has chosen
- (NSString *)chosenHexColor;
// Returns a three letter hex code using the passed in code, if possible (otherwise returns six letter code)
- (NSString *)shortestHexCodeWithHex:(NSString *)hexCode;

- (IBAction)updateColorPreview:(id)sender;
- (IBAction)doSubmitSheet:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)calculationHelp:(id)sender;

- (SXZone *)zoneAtIndex:(NSUInteger)index forContext:(id)context;
- (NSURL *)parentURLFromContext:(id)context;
- (id)projectContextForContext:(id)context;
- (NSURL *)rootURLForContext:(id)context;

@end

//
//  OCJiggerAction.h
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import <Foundation/Foundation.h>
#import <MRRegularExpressionAdditions.h>


// Enum for tracking modes
typedef enum {
    OCJiggerCalculateMode = 1,
    OCJiggerColorMode = 2
} OCJiggerMode;


@interface OCJiggerAction : NSObject <NSTokenFieldDelegate> {
@private
	MRRegularExpression *singleNumberRE;
	MRRegularExpression *selNumberRE;
	MRRegularExpression *singleColorRE;
	MRRegularExpression *selColorRE;
	NSMutableArray *numberRanges;
	NSMutableArray *colorRanges;
	NSRange targetRange;
	NSString *originalNumber;
	NSString *originalColor;
	id myContext;
	NSWindow *customSheet;
	NSView *calcView;
	NSView *colorView;
	NSTokenField *calcField;
	NSColorWell *colorField;
	NSButton *clearColorButton;
	NSTextField *colorPreview;
	NSBox *dividerLine;
	BOOL modifyAllFlag;
}

@property(retain) IBOutlet NSWindow *customSheet;
@property(retain) IBOutlet NSView *calcView;
@property(retain) IBOutlet NSView *colorView;
@property(retain) IBOutlet NSTokenField *calcField;
@property(retain) IBOutlet NSColorWell *colorField;
@property(retain) IBOutlet NSButton *clearColorButton;
@property(retain) IBOutlet NSTextField *colorPreview;
@property(retain) IBOutlet NSBox *dividerLine;

- (void)showMode:(OCJiggerMode)mode hideOthers:(BOOL)hideFlag;
- (void)configureCalculateMode:(NSString *)startValue;
- (void)configureColorMode:(NSString *)startValue;
// Returns the six-digit hex code that the user has chosen
- (NSString *)chosenHexColor;
// Returns a three letter hex code using the passed in code, if possible (otherwise returns six letter code)
- (NSString *)shortestHexCodeWithHex:(NSString *)hexCode;

- (IBAction)updateColorPreview:(id)sender;
- (IBAction)doSubmitSheet:(id)sender;
- (IBAction)cancel:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

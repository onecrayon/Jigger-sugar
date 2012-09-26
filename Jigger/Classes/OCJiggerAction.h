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
	id myContext;
	NSWindow *customSheet;
	NSView *calcView;
	NSView *colorView;
	NSTokenField *calcField;
	NSColorWell *colorField;
	NSBox *dividerLine;
}

@property(retain) IBOutlet NSWindow *customSheet;
@property(retain) IBOutlet NSView *calcView;
@property(retain) IBOutlet NSView *colorView;
@property(retain) IBOutlet NSTokenField *calcField;
@property(retain) IBOutlet NSColorWell *colorField;
@property(retain) IBOutlet NSBox *dividerLine;

- (void)showMode:(OCJiggerMode)mode hideOthers:(BOOL)hideFlag;
- (void)configureCalculateMode:(NSString *)startValue;
- (void)configureColorMode:(NSString *)startValue;

- (IBAction)doSubmitSheet:(id)sender;
- (IBAction)cancel:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

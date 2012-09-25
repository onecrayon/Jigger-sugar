//
//  OCJiggerAction.h
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import <Foundation/Foundation.h>
#import <MRRegularExpressionAdditions.h>


@interface OCJiggerAction : NSObject <NSTokenFieldDelegate> {
@private
	MRRegularExpression *singleNumberRE;
	MRRegularExpression *selNumberRE;
	MRRegularExpression *singleColorRE;
	MRRegularExpression *selColorRE;
	NSMutableArray *numberRanges;
	NSMutableArray *colorRanges;
	NSRange targetRange;
	NSString *startValue;
	id myContext;
	NSColorPanel *colorPanel;
	NSWindow *customSheet;
	NSTokenField *calcField;
	NSTabView *tabView;
}

@property(retain) IBOutlet NSWindow *customSheet;
@property(retain) IBOutlet NSTokenField *calcField;
@property(retain) IBOutlet NSTabView *tabView;

- (IBAction)activateColorMode:(id)sender;
- (IBAction)activateCalculateMode:(id)sender;

- (IBAction)doSubmitSheet:(id)sender;
- (IBAction)cancel:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

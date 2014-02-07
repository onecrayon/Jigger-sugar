//
//  OCJiggerColorWell.m
//  Jigger
//
//  Created by Ian Beck on 2/7/14.
//  Copyright (c) 2014 MacRabbit. All rights reserved.
//

#import "OCJiggerColorWell.h"

@implementation OCJiggerColorWell

- (void)activate:(BOOL)exclusive
{
	originalAlphaSetting = [[NSColorPanel sharedColorPanel] showsAlpha];
    [[NSColorPanel sharedColorPanel] setShowsAlpha:NO];
    [super activate:exclusive];
}

- (void)deactivate
{
    [super deactivate];
    [[NSColorPanel sharedColorPanel] setShowsAlpha:originalAlphaSetting];
}

@end

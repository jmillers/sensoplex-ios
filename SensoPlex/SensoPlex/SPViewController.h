//
//  SPViewController.h
//  SensoPlex
//
//  Created by Jeremy Millers on 9/19/13.
//  Copyright (c) 2013 SweetSpotScience. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.

//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.

//  You should have received a copy of the GNU Lesser General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <UIKit/UIKit.h>
#import "SensoPlex.h"



@interface SPViewController : UIViewController {
}

// flag that we set while we are displaying
@property (assign) BOOL isDisplaying;

// the SensoPlex object to work with to interact with the SP-10BN Module
@property (strong, nonatomic, retain) SensoPlex *sensoPlex;

// method that can be overidden to customize the UI display for specific
// connection states
- (void) showConnectionState:(SensoPlexState) state;

// show a status message (for a specified amount of time before auto-hiding)
- (void) showStatus:(NSString*)status for:(NSTimeInterval)forTime;


@end


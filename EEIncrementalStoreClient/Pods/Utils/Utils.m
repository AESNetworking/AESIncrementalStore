//
//  Utils.m
//  CheckList
//
//  Created by ing.conti on 6/11/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

// for timing:

#include <mach/mach.h>
#include <mach/mach_time.h>

#import "Utils.h"

@implementation Utils




nS durationInNanoseconds(nS start, nS end)
{
	// http://developer.apple.com/mac/library/qa/qa2004/qa1398.html
	
	/* USAGE: get start time using:
	 
	 nS start = mach_absolute_time();
	 ... (do the stuff)
	 
	 nS end = mach_absolute_time();
	 
	 // call this f. :
	 nS duration = durationInNanoseconds(start, end);
	 
	 DO NOT try to modify this function calculating HERE end: we will add function call overhead
	 */
	
	// Convert to nanoseconds.
	
	// Have to do some pointer fun because AbsoluteToNanoseconds
	// works in terms of UnsignedWide, which is a structure rather
	// than a proper 64-bit integer.
	
    nS        elapsed;
    nS        elapsedNano;
	mach_timebase_info_data_t    sTimebaseInfo = {0,0};
	
	elapsed = end - start;
	// Convert to nanoseconds.
	
    // If this is the first time we've run, get the timebase.
    // We can use denom == 0 to indicate that sTimebaseInfo is
    // uninitialised because it makes no sense to have a zero
    // denominator is a fraction.
	
    if ( sTimebaseInfo.denom == 0 ) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
	
    // Do the maths.  We hope that the multiplication doesn't
    // overflow; the price you pay for working in fixed point.
	
    elapsedNano = elapsed * sTimebaseInfo.numer / sTimebaseInfo.denom;
	
	// NSLog(@"%d", elapsedNano / ONE_MILLION);
	
    return elapsedNano;
}


@end

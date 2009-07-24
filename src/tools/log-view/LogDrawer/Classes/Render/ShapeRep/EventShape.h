/*! \file EventShape.h
 \author Korei Klein
 \date 7/8/09

 Common superclass to all shape objects.
*/

#import <Cocoa/Cocoa.h>
#import "Structures.h"


/// A superclass to shapes.
/*! After initialization, shapes all export sort of the same interface.
 * Methods of EventShape should encompass all this generic functionality.
 *
 * The event in the log file which corresponds to a shape is not generic
 * because certain shapes correspond to multiple events.
 */
@interface EventShape : NSObject {
	NSColor *color; //!< Color of the shape. not Null.
}

/// Draw the shape
- (void)drawShape;

/// Determine if a point lies within the area this shape is drawn on
- (BOOL)containsPoint:(NSPoint)p;

@end

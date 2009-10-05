/*! \file Message.h
 \author Korei Klein
 \date 7/7/09
 */


#import <Cocoa/Cocoa.h>
#import "Structures.h"
#import "EventShape.h"

/// Represent a message event by drawing an arrow
@interface Message : EventShape {
	NSPoint start; //!< Point where the arrow starts
	NSPoint end; //!< Point where the arrow ends
	NSBezierPath *path; //!< The entire arrow (cache of start and end).
	
	CGFloat lineWidth; //!< Width of the arrow
	
	void *sender; //!< The event where this message was sent
	void *receiver; //!< The event where this message was received
}

@property (readonly) void *sender;

/*!
 The arrow head.
 It should point rightwards along the positive x-axis.
 The tip of the arrow head should be at the origin
 */
NSBezierPath *arrowHead; //!< arrowhead



///Initialize
- (Message *)initArrowFromPoint:(NSPoint)p1
			toPoint:(NSPoint)p2;
///Initialize
- (Message *)initArrowFromPoint:(NSPoint)p1
			toPoint:(NSPoint)p2
			 sender:(void *)s
		       receiver:(void *)r;
///Initialize
/*! initialize
 \param p1 the point where the arrow starts
 \param p2 the point where the arrow ends
 \param c color of the arrow
 \param w width of the line
 \param s event marking the start of this message
 \param r event marking the end of this message
 */
- (Message *)initArrowFromPoint:(NSPoint)p1
			toPoint:(NSPoint)p2
			  color:(NSColor *)c
		      lineWidth:(CGFloat)w
			 sender:(void *)s
		       receiver:(void *)r;


/// Determine if a point lies within the area this shape is drawn on
- (BOOL)containsPoint:(NSPoint)p;

#pragma mark Drawing Methods


- (void)drawShape; //!< Draw the arrow

@end
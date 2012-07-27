//
//	ReaderContentView.m
//	Reader v2.5.4
//
//	Created by Julius Oklamcak on 2011-07-01.
//	Copyright © 2011-2012 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "ReaderContentView.h"
#import "ReaderContentPage.h"
#import "ReaderThumbCache.h"

#import <QuartzCore/QuartzCore.h>

@implementation ReaderContentView

#pragma mark Constants

#define ZOOM_LEVELS 4

#define PAGE_THUMB_LARGE 240
#define PAGE_THUMB_SMALL 144

#pragma mark Properties

@synthesize message;

#pragma mark ReaderContentView functions

static inline CGFloat ZoomScaleThatFits(CGSize target, CGSize source)
{
	CGFloat w_scale = (target.width / source.width);
	CGFloat h_scale = (target.height / source.height);

	return ((w_scale < h_scale) ? w_scale : h_scale);
}

#pragma mark ReaderContentView instance methods

- (CGFloat)defaultContentInset {
#if (READER_SHOW_SHADOWS == TRUE) // Option
    return 4.0f;
#else
    return 2.0f;
#endif // end of READER_SHOW_SHADOWS Option
}

- (void)updateMinimumMaximumZoom
{
	CGRect targetRect = CGRectInset(self.bounds, [self defaultContentInset], [self defaultContentInset]);

	CGFloat zoomScale = ZoomScaleThatFits(targetRect.size, theContentView.bounds.size);

	self.minimumZoomScale = zoomScale; // Set the minimum and maximum zoom scales

	self.maximumZoomScale = (zoomScale * ZOOM_LEVELS); // Max number of zoom levels

	zoomAmount = ((self.maximumZoomScale - self.minimumZoomScale) / ZOOM_LEVELS);
}

- (Class)contentPageClass
{
    return [ReaderContentPage class];
}

- (Class)containerViewClass
{
    return [UIView class];
}

- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileURL page:(NSUInteger)page password:(NSString *)phrase
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if ((self = [super initWithFrame:frame]))
	{
		self.scrollsToTop = NO;
		self.delaysContentTouches = NO;
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.contentMode = UIViewContentModeRedraw;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.backgroundColor = [UIColor clearColor];
		self.userInteractionEnabled = YES;
		self.autoresizesSubviews = NO;
		self.bouncesZoom = YES;
		self.delegate = self;

		theContentView = [[[self contentPageClass] alloc] initWithURL:fileURL page:page password:phrase];
        if (!theContentView)
        {
            /*
             PDF failed to open, so return nil here so user can handle it
             */
            [self release];
            return nil;
        }

		if (theContentView != nil) // Must have a valid and initialized content view
		{
			theContainerView = [[[self containerViewClass] alloc] initWithFrame:theContentView.bounds];

			theContainerView.autoresizesSubviews = NO;
			theContainerView.userInteractionEnabled = NO;
			theContainerView.contentMode = UIViewContentModeRedraw;
			theContainerView.autoresizingMask = UIViewAutoresizingNone;
			theContainerView.backgroundColor = [UIColor whiteColor];

#if (READER_SHOW_SHADOWS == TRUE) // Option

			theContainerView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
			theContainerView.layer.shadowRadius = 4.0f; theContainerView.layer.shadowOpacity = 1.0f;
			theContainerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:theContainerView.bounds].CGPath;

#endif // end of READER_SHOW_SHADOWS Option

			self.contentSize = theContentView.bounds.size; // Content size same as view size
            CGFloat contentInset = [self defaultContentInset];
			self.contentOffset = CGPointMake((0.0f - contentInset), (0.0f - contentInset)); // Offset
			self.contentInset = UIEdgeInsetsMake(contentInset, contentInset, contentInset, contentInset);

			theThumbView = [[ReaderContentThumb alloc] initWithFrame:theContentView.bounds]; // Page thumb view

			[theContainerView addSubview:theThumbView]; // Add the thumb view to the container view

			[theContainerView addSubview:theContentView]; // Add the content view to the container view

			[self addSubview:theContainerView]; // Add the container view to the scroll view

			[self updateMinimumMaximumZoom]; // Update the minimum and maximum zoom scales

			self.zoomScale = self.minimumZoomScale; // Set zoom to fit page content
		}

		[self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:NULL];

		self.tag = page; // Tag the view with the page number
	}

	return self;
}

- (void)dealloc
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    @try {
        [self removeObserver:self forKeyPath:@"frame"];
    }
    @catch (NSException *ex) {
        NSLog(@"%@", ex);
    }

	[theContainerView release], theContainerView = nil;

	[theContentView release], theContentView = nil;

	[theThumbView release], theThumbView = nil;

	[super dealloc];
}

- (void)showPageThumb:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase guid:(NSString *)guid
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    
    BOOL large = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad); // Page thumb size
    
    CGSize size = (large ? CGSizeMake(PAGE_THUMB_LARGE, PAGE_THUMB_LARGE) : CGSizeMake(PAGE_THUMB_SMALL, PAGE_THUMB_SMALL));
    
    [self showPageThumb:fileURL page:page password:phrase guid:guid size:size];
}

- (void)showPageThumb:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase guid:(NSString *)guid size:(CGSize)size
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	ReaderThumbRequest *request = [ReaderThumbRequest forView:theThumbView fileURL:fileURL password:phrase guid:guid page:page size:size];

	UIImage *image = [[ReaderThumbCache sharedInstance] thumbRequest:request priority:YES]; // Request the page thumb

	if ([image isKindOfClass:[UIImage class]]) [theThumbView showImage:image]; // Show image from cache
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if ((object == self) && [keyPath isEqualToString:@"frame"])
	{
		CGFloat oldMinimumZoomScale = self.minimumZoomScale;

		[self updateMinimumMaximumZoom]; // Update zoom scale limits

		if (self.zoomScale == oldMinimumZoomScale) // Old minimum
		{
			self.zoomScale = self.minimumZoomScale;
		}
		else // Check against minimum zoom scale
		{
			if (self.zoomScale < self.minimumZoomScale)
			{
				self.zoomScale = self.minimumZoomScale;
			}
			else // Check against maximum zoom scale
			{
				if (self.zoomScale > self.maximumZoomScale)
				{
					self.zoomScale = self.maximumZoomScale;
				}
			}
		}
	}
}

- (void)layoutSubviews
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	[super layoutSubviews];

	CGSize boundsSize = self.bounds.size;
	CGRect viewFrame = theContainerView.frame;

	if (viewFrame.size.width < boundsSize.width)
		viewFrame.origin.x = (((boundsSize.width - viewFrame.size.width) / 2.0f) + self.contentOffset.x);
	else
		viewFrame.origin.x = 0.0f;

	if (viewFrame.size.height < boundsSize.height)
		viewFrame.origin.y = (((boundsSize.height - viewFrame.size.height) / 2.0f) + self.contentOffset.y);
	else
		viewFrame.origin.y = 0.0f;

	theContainerView.frame = viewFrame;
}

- (id)singleTap:(UITapGestureRecognizer *)recognizer
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	return [theContentView singleTap:recognizer];
}

- (void)zoomIncrement
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	CGFloat zoomScale = self.zoomScale;

	if (zoomScale < self.maximumZoomScale)
	{
		zoomScale += zoomAmount; // += value

		if (zoomScale > self.maximumZoomScale)
		{
			zoomScale = self.maximumZoomScale;
		}

		[self setZoomScale:zoomScale animated:YES];
	}
}

- (void)zoomIncrementToPoint:(CGPoint)point
{
    CGFloat zoomScale = self.zoomScale;
    
	if (zoomScale < self.maximumZoomScale)
	{
		zoomScale += zoomAmount; // += value
        
		if (zoomScale > self.maximumZoomScale)
		{
			zoomScale = self.maximumZoomScale;
		}

        //Normalize current content size back to content scale of 1.0f
        CGSize contentSize;
        contentSize.width = (self.contentSize.width / self.zoomScale);
        contentSize.height = (self.contentSize.height / self.zoomScale);
        
        //translate the zoom point to relative to the content rect
        point.x = (point.x / self.bounds.size.width) * contentSize.width;
        point.y = (point.y / self.bounds.size.height) * contentSize.height;
        
        //derive the size of the region to zoom to
        CGSize zoomSize;
        zoomSize.width = self.bounds.size.width / zoomScale;
        zoomSize.height = self.bounds.size.height / zoomScale;
        
        //offset the zoom rect so the actual zoom point is in the middle of the rectangle
        CGRect zoomRect;
        zoomRect.origin.x = point.x - zoomSize.width / 2.0f;
        zoomRect.origin.y = point.y - zoomSize.height / 2.0f;
        zoomRect.size.width = zoomSize.width;
        zoomRect.size.height = zoomSize.height;
        
        //apply the resize
        [self zoomToRect:zoomRect animated:YES];
    }
}

- (void)zoomDecrement
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	CGFloat zoomScale = self.zoomScale;

	if (zoomScale > self.minimumZoomScale)
	{
		zoomScale -= zoomAmount; // -= value

		if (zoomScale < self.minimumZoomScale)
		{
			zoomScale = self.minimumZoomScale;
		}

		[self setZoomScale:zoomScale animated:YES];
	}
}

- (void)zoomReset
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if (self.zoomScale > self.minimumZoomScale)
	{
		self.zoomScale = self.minimumZoomScale;
	}
}

- (void)highlightPageLinks
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    
    [theContentView highlightPageLinks];
}

#pragma mark UIScrollViewDelegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return theContainerView;
}

#pragma mark UIResponder instance methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event]; // Message superclass

	[message contentView:self touchesBegan:touches]; // Message delegate
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event]; // Message superclass
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event]; // Message superclass
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event]; // Message superclass
}

@end

#pragma mark -

//
//	ReaderContentThumb class implementation
//

@implementation ReaderContentThumb

//#pragma mark Properties

//@synthesize ;

#pragma mark ReaderContentThumb instance methods

- (id)initWithFrame:(CGRect)frame
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if ((self = [super initWithFrame:frame])) // Superclass init
	{
		imageView.contentMode = UIViewContentModeScaleAspectFill;

		imageView.clipsToBounds = YES; // Needed for aspect fill
	}

	return self;
}

@end

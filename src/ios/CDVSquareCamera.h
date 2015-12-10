
#import <Cordova/CDVPlugin.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

@interface CDVSquareCamera : CDVPlugin

- (void)show:(CDVInvokedUrlCommand*)command;

@end

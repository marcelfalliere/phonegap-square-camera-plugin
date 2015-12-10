
#import "CDVSquareCamera.h"
#import <ImageIO/CGImageProperties.h>
#import <TargetConditionals.h>

#define DEGREES_RADIANS(angle) ((angle) / 180.0 * M_PI)

@interface CDVSquareCamera () {
    UIView *_containerView;
    
    UIView *_previewView;
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    AVCaptureStillImageOutput *_stillImageOutput;
    
    NSString* _commandId;
    CDVPluginResult* _pluginResult;
}

@end

@implementation CDVSquareCamera


- (void)show:(CDVInvokedUrlCommand*)command {
    
    // Saving command
    _commandId = command.callbackId;
    NSLog(@"command id (same as below) : %@", _commandId);
    
    // Desactivate webview interactions
    self.webView.userInteractionEnabled=NO;
    
    // Prepare the container view
    _containerView = [[UIView alloc]initWithFrame:[[UIScreen mainScreen] bounds]];
    _containerView.backgroundColor = [UIColor blackColor];
    _containerView.alpha=0;

    // Capture Session
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }
    else {
        // TODO: Handle that.
    }
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
    [_captureSession addOutput:_stillImageOutput];
    

    // Square preview layer
    _previewView = [[UIView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor blackColor];
    CGRect rectangle = [[UIScreen mainScreen] bounds];
    CGRect previewFrame = CGRectMake(0, 60.0f, rectangle.size.width, rectangle.size.width);
    _previewView.frame = previewFrame;
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer addSublayer:_previewLayer];
    [_containerView addSubview:_previewView];

    // Add the take picture button and gesture recog
    UIButton* capture = [[UIButton alloc]initWithFrame:CGRectMake(rectangle.size.width/2 - 40, rectangle.size.width+70, 80, 40)];
    [capture setImage:[UIImage imageNamed:@"icon-camera.png"] forState:UIControlStateNormal];
    
#if TARGET_IPHONE_SIMULATOR
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(takePictureSimulator)];
    singleTap.numberOfTapsRequired = 1;
#else
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(takePicture)];
    singleTap.numberOfTapsRequired = 1;
#endif
    

    capture.userInteractionEnabled = YES;
    [capture addGestureRecognizer:singleTap];
    [_containerView addSubview:capture];
    
    // Add the quit button
    UIButton* quit = [[UIButton alloc]initWithFrame:CGRectMake(10, [[UIScreen mainScreen] bounds].size.height-30-10, 30, 30)];
    [quit setImage:[UIImage imageNamed:@"icon-close.png"] forState:UIControlStateNormal];
    UITapGestureRecognizer *singleTapQuit = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancel)];
    singleTapQuit.numberOfTapsRequired = 1;
    quit.userInteractionEnabled = YES;
    [quit addGestureRecognizer:singleTapQuit];
    [_containerView addSubview:quit];
    
    // Add the view and start the camera
    [self.viewController.view addSubview:_containerView];
    [_captureSession startRunning];
    
    // Animation de couleur de fond
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:YES];
    [UIView animateWithDuration:0.6f animations:^{
        _containerView.alpha=1;
    }];
    
}

-(void)takePicture{
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         CFDictionaryRef exifAttachments = CMGetAttachment( imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
         if (exifAttachments)
         {
             // Do something with the attachments.
             //NSLog(@"attachements: %@", exifAttachments);
         } else {
             //NSLog(@"no attachments");
         }
         
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage* image = [[UIImage alloc] initWithData:imageData];

         
         CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], CGRectMake((image.size.height-image.size.width)/2,0,image.size.width, image.size.width));
         
         UIImage *finalImage = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationRight];
         
         UIImageView* imageView = [[UIImageView alloc]initWithImage:finalImage];
         imageView.contentMode = UIViewContentModeScaleAspectFit;
         imageView.frame = _previewView.frame;
         [_containerView addSubview:imageView];
         
         NSString  *filePath;
         NSFileManager* fileMgr = [[NSFileManager alloc] init];
         
         int i = 1;
         do {
             filePath = [NSString stringWithFormat:@"%@/fmfleger-tmp-%i.png", [NSTemporaryDirectory()stringByStandardizingPath], i];
             i++;
         } while ([fileMgr fileExistsAtPath:filePath]);
         

         UIImage* rotatedImage = [self rotateImage:finalImage onDegrees:90.0f];
         UIImage* mirroredImage = [self mirrorImage:rotatedImage];
         
         NSData* writeImage = UIImagePNGRepresentation(mirroredImage);
         NSError* err = nil;
         if ([writeImage writeToFile:filePath options:NSAtomicWrite error:&err]){
             NSLog(@"ok");
         } else {
             NSLog(@"ko %@", err.description);
         }
         
         NSLog(@"imageView : %@", imageView);
         NSLog(@"command id : %@", _commandId);
         
         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:filePath];
         [self.commandDelegate sendPluginResult:pluginResult callbackId:_commandId];
         
         [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:YES];
         [UIView animateWithDuration:0.6f animations:^{
             _containerView.alpha=0;
         } completion:^(BOOL finished){
             [_previewLayer removeFromSuperlayer];
             [_previewView removeFromSuperview];
             [_captureSession stopRunning];
             [_containerView removeFromSuperview];
             [self.webView setUserInteractionEnabled:YES];
         }];

     }];
    
    
    NSError *error;
    if (error) {
        //errorCallback(@"error");
        NSLog(@"error");
    }else{
        
    }
}

-(void)takePictureSimulator {
    UIImage* ti = [UIImage imageNamed:@"simulatorpicture"];
    UIImageView* i = [[UIImageView alloc]initWithImage:ti];
    i.contentMode = UIViewContentModeScaleAspectFit;
    i.frame = _previewView.frame;
    [_containerView addSubview:i];
    
    NSString  *jpgPath = [NSString stringWithFormat:@"%@/fmfleger-tmp-01.png", [NSTemporaryDirectory()stringByStandardizingPath]];
    NSData* imageData = UIImagePNGRepresentation(ti);
    NSError* err = nil;
    if ([imageData writeToFile:jpgPath options:NSAtomicWrite error:&err]){
        NSLog(@"ok");
    } else {
        NSLog(@"ko %@", err.description);
    }
    
    NSLog(@"ti : %@", ti);
    NSLog(@"jpeg path : %@", jpgPath);
    NSLog(@"command id : %@", _commandId);
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jpgPath];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_commandId];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [UIView animateWithDuration:0.6f animations:^{
        _containerView.layer.backgroundColor = [UIColor clearColor].CGColor;
    } completion:^(BOOL finished){
        [_containerView removeFromSuperview];
        [self.webView setUserInteractionEnabled:YES];
    }];

}


- (UIImage *)rotateImage:(UIImage *)image onDegrees:(float)degrees
{
    CGFloat rads = M_PI * degrees / 180;
    float newSide = MAX([image size].width, [image size].height);
    CGSize size =  CGSizeMake(newSide, newSide);
    UIGraphicsBeginImageContext(size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, newSide/2, newSide/2);
    CGContextRotateCTM(ctx, rads);
    CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(-[image size].width/2,-[image size].height/2,size.width, size.height),image.CGImage);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}


- (UIImage *)mirrorImage:(UIImage *)image
{
    UIGraphicsBeginImageContext(image.size);
    CGContextRef current_context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(current_context, image.size.width, 0);
    CGContextScaleCTM(current_context, -1.0, 1.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *flipped_img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return flipped_img;
}

-(void)cancel{
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:YES];
    [UIView animateWithDuration:0.6f animations:^{
        _containerView.alpha = 0;
    } completion:^(BOOL finished){
        [_previewLayer removeFromSuperlayer];
        [_previewView removeFromSuperview];
        [_captureSession stopRunning];
        [_containerView removeFromSuperview];
        [self.webView setUserInteractionEnabled:YES];
    }];

}

@end

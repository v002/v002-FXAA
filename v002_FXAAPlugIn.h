//
//  v002_FXAAPlugIn.h
//  v002 FXAA
//
//  Created by vade on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "v002MasterPluginInterface.h"

@interface v002_FXAAPlugIn : v002MasterPluginInterface
{
}

@property (assign) id <QCPlugInInputImageSource> inputImage;

@property (assign) id <QCPlugInOutputImageProvider> outputImage;

@end


@interface v002_FXAAPlugIn (Execution)
- (GLuint) renderToFBO:(id<QCPlugInContext>)context image:(id <QCPlugInInputImageSource>)image;
@end
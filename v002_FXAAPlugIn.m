//
//  v002_FXAAPlugIn.m
//  v002 FXAA
//
//  Created by vade on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */

#import <OpenGL/CGLMacro.h>

#import "v002_FXAAPlugIn.h"

#define	kQCPlugIn_Name				@"v002 FXAA"
#define	kQCPlugIn_Description		@"v002 FXAA - Fast Approximate Anti Aliasing - by Timothy Lottes at NVIDIA, with help from Martin Upitis - QC Plugin and Texture Rect conversion by vade."

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

@implementation v002_FXAAPlugIn

@dynamic inputImage;
@dynamic outputImage;

+ (NSDictionary*) attributes
{	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey,
            [kQCPlugIn_Description stringByAppendingString:kv002DescriptionAddOnText], QCPlugInAttributeDescriptionKey,
            kQCPlugIn_Category, @"categories", nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	if(self = [super init])
	{
		self.pluginShaderName = @"v002.FXAA";
        
        self.shaderUniformBlock = ^void(CGLContextObj cgl_ctx, v002_FXAAPlugIn* instance,  __unsafe_unretained id<QCPlugInInputImageSource> image)
        {
            if(instance && image)
            {
                GLsizei width = [image imageBounds].size.width;
                GLsizei height = [image imageBounds].size.height;

                // set program vars
                glUniform1iARB([pluginShader getUniformLocation:"bgl_RenderedTexture"], 0);
                glUniform1fARB([pluginShader getUniformLocation:"bgl_RenderedTextureWidth"], width);
                glUniform1fARB([pluginShader getUniformLocation:"bgl_RenderedTextureHeight"], height);
            }
        };

	}
	
	return self;
}

- (void) finalize
{
	[super finalize];
}

- (void) dealloc
{	
	[super dealloc];
}

@end

@implementation v002_FXAAPlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
    id<QCPlugInInputImageSource>   image = self.inputImage;
    
    CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];
    
    if(image && [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]])
    {
        [image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
        
        BOOL useFloat = [self boundImageIsFloatingPoint:image inContext:cgl_ctx];
        
        // Render
        GLuint finalOutput = [self singleImageRenderWithContext:cgl_ctx image:image useFloat:useFloat];
        
        [image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
        [image unlockTextureRepresentation];
        
        id provider = nil;
        
        if(finalOutput != 0)
        {
            provider = [context outputImageProviderFromTextureWithPixelFormat:[self pixelFormatIfUsingFloat:useFloat]
                                                                   pixelsWide:[image imageBounds].size.width
                                                                   pixelsHigh:[image imageBounds].size.height
                                                                         name:finalOutput
                                                                      flipped:NO
                                                              releaseCallback:_TextureReleaseCallback
                                                               releaseContext:NULL
                                                                   colorSpace:[context colorSpace]
                                                             shouldColorMatch:[image shouldColorMatch]];
            
            self.outputImage = provider;
        }
    }
    else
        self.outputImage = nil;
    
    return YES;
}

@end

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
	GLuint finalOutput = [self renderToFBO:context image:self.inputImage];
	
	id provider = nil;	
	
	if(finalOutput != 0)
	{
		
#if __BIG_ENDIAN__
#define v002QCPluginPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002QCPluginPixelFormat QCPlugInPixelFormatBGRA8			
#endif
		provider = [context outputImageProviderFromTextureWithPixelFormat:v002QCPluginPixelFormat
															   pixelsWide:[self.inputImage imageBounds].size.width 
															   pixelsHigh:[self.inputImage imageBounds].size.height
																	 name:finalOutput
																  flipped:[self.inputImage textureFlipped] 
														  releaseCallback:_TextureReleaseCallback
														   releaseContext:NULL
															   colorSpace:[context colorSpace]
														 shouldColorMatch:[self.inputImage shouldColorMatch]];
		
		self.outputImage = provider;
		
	}

	return YES;
}


- (GLuint) renderToFBO:(id<QCPlugInContext>)context image:(id <QCPlugInInputImageSource>)image
{
	GLsizei width = [image imageBounds].size.width, height = [image imageBounds].size.height;
	
	CGLContextObj cgl_ctx = [context CGLContextObj];
	
	// save/restore state once
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glPushClientAttrib(GL_CLIENT_VERTEX_ARRAY_BIT);
	
    // new texture
    GLuint fboTex = 0;
    glGenTextures(1, &fboTex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, fboTex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
	[pluginFBO pushFBO:cgl_ctx];
    [pluginFBO attachFBO:cgl_ctx withTexture:fboTex width:width height:height];
    
    glClear(GL_COLOR_BUFFER_BIT);
    
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];
	if(image && [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]])
	{
		[image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		
		// bind our shader program
		glUseProgramObjectARB([pluginShader programObject]);
		
		// set program vars
		glUniform1iARB([pluginShader getUniformLocation:"bgl_RenderedTexture"], 0); 
		glUniform1fARB([pluginShader getUniformLocation:"bgl_RenderedTextureWidth"], width); 
		glUniform1fARB([pluginShader getUniformLocation:"bgl_RenderedTextureHeight"], height); 

		// move to VA for rendering
		GLfloat tex_coords[] = 
		{
			1,1,
			0.0,1,
			0.0,0.0,
			1,0.0
		};
		
		GLfloat verts[] = 
		{
			width,height,
			0.0,height,
			0.0,0.0,
			width,0.0
		};
		
		glEnableClientState( GL_TEXTURE_COORD_ARRAY );
		glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
		glEnableClientState(GL_VERTEX_ARRAY);		
		glVertexPointer(2, GL_FLOAT, 0, verts );
		glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );	// TODO: GL_QUADS or GL_TRIANGLE_FAN?
		
		// disable shader program
		glUseProgramObjectARB(NULL);
		
		[image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
		[image unlockTextureRepresentation];
	}
	
    [pluginFBO detachFBO:cgl_ctx]; // pops out and resets cached FBO state from above.
	[pluginFBO popFBO:cgl_ctx];
	
	glPopClientAttrib();
	glPopAttrib();
	
	return fboTex;
}


@end

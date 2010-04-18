//
//  RXWorldView.h
//  rivenx
//
//  Created by Jean-Francois Roy on 04/09/2005.
//  Copyright 2005-2010 MacStorm. All rights reserved.
//

#import "Rendering/RXRendering.h"
#import "Rendering/Graphics/RXOpenGLState.h"
#import "Rendering/Animation/RXInterpolator.h"


@interface RXWorldView : NSOpenGLView <RXWorldViewProtocol> {
    CGLPixelFormatObj _cglPixelFormat;
    
    NSOpenGLContext* _renderContext;
    CGLContextObj _renderContextCGL;
    
    NSOpenGLContext* _loadContext;
    CGLContextObj _loadContextCGL;
    
    CIContext* _ciContext;
    CIFilter* _scaleFilter;
    CIFilter* _fadeColorFilter;
    CIFilter* _multiplyBlendFilter;
    CIFilter* _cropFilter;
    
    io_service_t _acceleratorService;
    
    GLuint _glMajorVersion;
    GLuint _glMinorVersion;
    GLuint _glslMajorVersion;
    GLuint _glslMinorVersion;
    NSSet* _gl_extensions;
    
    ssize_t _totalVRAM;
    
    GLsizei _glWidth;
    GLsizei _glHeight;
    
    CGColorSpaceRef _workingColorSpace;
    CGColorSpaceRef _displayColorSpace;
    CGColorSpaceRef _sRGBColorSpace;
    
    CVDisplayLinkRef _displayLink;
    
    GLuint _attribsVBO;
    rx_renderer_t _cardRenderer;
    GLuint _cardFBO;
    GLuint _cardTexture;
    GLuint _cardVAO;
    GLuint _cardProgram;
    
    GLuint _fadeLayerVAO;
    GLuint _solidColorProgram;
    GLint _solidColorLocation;
    
    NSCursor* _cursor;
    
    id _fadeCompletionDelegate;
    SEL _fadeCompletionSel;
    RXLinearInterpolator* _fadeInterpolator;
    
    BOOL _glInitialized;
    BOOL _useCoreImage;
    BOOL _tornDown;
}

@end

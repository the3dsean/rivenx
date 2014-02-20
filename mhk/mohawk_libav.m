//
//  mohawk_libav.m
//  rivenx
//
//  Created by jfroy on 2/14/14.
//  Copyright (c) 2014 MacStorm. All rights reserved.
//

#import "mohawk_libav.h"

#import <dlfcn.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSPathUtilities.h>

struct mhk_libav g_libav;

static inline void load_function(void* handle, const char* name, void** fnptr)
{
  *fnptr = dlsym(handle, name);
  if (!*fnptr) {
    fprintf(stderr, "fatal: unable to bind symbol \"%s\": %s\n", name, dlerror());
    abort();
  }
}

#define LOADFN(HANDLE, FN) load_function(g_libav.HANDLE, #FN, (void**)&g_libav.FN)

static void init_libav()
{
  // lookup symbols
  LOADFN(avu_handle, av_malloc);
  LOADFN(avu_handle, av_freep);
  LOADFN(avu_handle, av_log_set_level);
  LOADFN(avu_handle, av_dict_set);

  LOADFN(avc_handle, avcodec_register_all);
  LOADFN(avc_handle, avcodec_find_decoder);
  LOADFN(avc_handle, avcodec_alloc_context3);
  LOADFN(avc_handle, avcodec_open2);
  LOADFN(avc_handle, avcodec_close);
  LOADFN(avc_handle, avcodec_alloc_frame);
  LOADFN(avc_handle, avcodec_free_frame);
  LOADFN(avc_handle, avcodec_decode_audio4);

  LOADFN(avf_handle, av_register_all);
  LOADFN(avf_handle, av_iformat_next);
  LOADFN(avf_handle, avformat_alloc_context);
  LOADFN(avf_handle, avformat_free_context);
  LOADFN(avf_handle, avformat_open_input);
  LOADFN(avf_handle, avformat_find_stream_info);
  LOADFN(avf_handle, av_read_frame);
  LOADFN(avf_handle, avformat_close_input);

  LOADFN(avf_handle, avio_alloc_context);
  LOADFN(avf_handle, avio_seek);

  // initialize libav
  g_libav.av_log_set_level(AV_LOG_DEBUG);
  g_libav.avcodec_register_all();
  g_libav.av_register_all();
}

static void* load_lib(NSString* base_path, NSString* name)
{
  const char* path = [[base_path stringByAppendingPathComponent:name] fileSystemRepresentation];
  void* handle = dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
  if (!handle) {
    fprintf(stderr, "fatal: %s", dlerror());
    abort();
  }
  return handle;
}

static void load_libs()
{
  NSBundle* mhk_bundle = [NSBundle bundleWithIdentifier:@"org.macstorm.MHKKit"];
  NSString* resource_path = [mhk_bundle resourcePath];

  g_libav.avu_handle = load_lib(resource_path, @"libavutil.dylib");
  g_libav.avc_handle = load_lib(resource_path, @"libavcodec.dylib");
  g_libav.avf_handle = load_lib(resource_path, @"libavformat.dylib");
}

void mhk_load_libav()
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    load_libs();
    init_libav();
  });
}

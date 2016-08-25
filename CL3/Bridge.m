//
//  Bridge.m
//  C³
//
//  Created by Kota Nakano on 8/25/16.
//
//

#import <Foundation/Foundation.h>
#import <OpenCL/opencl.h>
@interface LoaderObject: NSObject {

}
+(cl_program)load:(cl_context)context;
@end
@implementation LoaderObject
+(cl_program)load:(cl_context)context {
	NSBundle * bundle = [NSBundle bundleForClass:self];
	NSArray * urls = [bundle URLsForResourcesWithExtension:@"cl" subdirectory:nil];
	cl_uint count = (cl_uint)[urls count];
	size_t * lengths = malloc(sizeof(size_t)*count);
	const char ** sources = malloc(sizeof(char*)*count);
	for ( NSUInteger k = 0, K = [urls count] ; k < K ; ++ k ) {
		NSString * nsstring = [NSString stringWithContentsOfURL:[urls objectAtIndex:k] encoding:NSUTF8StringEncoding error:nil];
		lengths[k] = [nsstring length];
		sources[k] = [nsstring UTF8String];
	}
	cl_int err = 0;
	cl_program program = clCreateProgramWithSource(context, count, sources, lengths, &err);
	free(sources);
	free(lengths);
	return program;
}
@end

cl_program cl_program_creator(cl_context context) {
	return[LoaderObject load:context];
}

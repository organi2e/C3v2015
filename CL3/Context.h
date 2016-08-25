//
//  Context.h
//  C³
//
//  Created by Kota Nakano on 8/25/16.
//
//

#ifndef Context_h
#define Context_h

#include <stdio.h>
#include <OpenCL/opencl.h>

typedef struct Context {
	cl_uint device_count;
	cl_device_id * device;
	cl_context context;
	cl_command_queue * queue;
	cl_program program;
	cl_kernel floatMatrixMultLocals;
} context_t;

boolean_t context_init(context_t*);
boolean_t context_finalize(context_t*);

cl_mem context_newBuffer(context_t*, size_t, void*);
void context_gemm(context_t*, cl_mem, cl_mem, cl_mem, int, int, int);
void context_compute(context_t*,void(*)());

#endif /* Context_h */

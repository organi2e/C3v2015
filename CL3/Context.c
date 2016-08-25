//
//  Context.c
//  C³
//
//  Created by Kota Nakano on 8/25/16.
//
//

#include "Context.h"
#include <stdlib.h>
#include <memory.h>
cl_program cl_program_creator(cl_context);
boolean_t context_init(context_t*context) {
	cl_int err = 0;
	clGetDeviceIDs(0, CL_DEVICE_TYPE_GPU, 0, 0, &context->device_count);
	if ( context->device_count ) {
		context->device = malloc(sizeof(cl_device_id)*context->device_count);
		err = clGetDeviceIDs(0, CL_DEVICE_TYPE_GPU, context->device_count, context->device, 0);
	}
	context->context = clCreateContext(0, context->device_count, context->device, 0, 0, &err);
	if ( context->device_count ) {
		context->queue = malloc(sizeof(cl_command_queue)*context->device_count);
		for ( cl_uint k = 0, K = context->device_count ; k < K ; ++ k ) {
			context->queue[k] = clCreateCommandQueue(context->context, context->device[k], 0, &err);
		}
	}
	context->program = cl_program_creator(context->context);
	cl_int b = clBuildProgram(context->program, context->device_count, context->device, 0, 0, 0);
	printf("AAAAA: %d\r\n", b);
	for ( cl_int k = 0, K = context->device_count ; k < K ; ++ k ) {
		size_t length = 0;
		clGetProgramBuildInfo(context->program, context->device[k], CL_PROGRAM_BUILD_LOG, 0, 0, &length);
		if ( length ) {
			char * log = malloc(length);
			clGetProgramBuildInfo(context->program, context->device[k], CL_PROGRAM_BUILD_LOG, length, log, 0);
			printf("LOG: %s\r\n", log);
			free(log);
		}
	}
	context->floatMatrixMultLocals = clCreateKernel(context->program, "floatMatrixMultLocals", &err);
	return true;
}
boolean_t context_finalize(context_t*context) {
	for ( cl_uint k = 0, K = context->device_count ; k < K ; ++ k ) {
		clReleaseCommandQueue(context->queue[k]);
		clReleaseDevice(context->device[k]);
	}
	free(context->queue);
	free(context->device);
	clReleaseContext(context->context);
	context->device = 0;
	bzero(context, sizeof(context_t));
	return true;
}
cl_mem context_newBuffer(context_t*context, size_t size, void*data) {
	cl_int err = 0;
	return clCreateBuffer(context->context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, size, data, &err);
}
void context_gemm(context_t*context, cl_mem C, cl_mem A, cl_mem B, int I, int J, int K) {
	size_t const gws[2] = {I, J};
	size_t const lws[2] = {8, 8};
	size_t const ows[2] = {0, 0};
	cl_int err = 0;
	cl_kernel kernel = context->floatMatrixMultLocals;
	if ( err ) {
		
	} else {
		cl_int dim = K;
		clSetKernelArg(kernel, 0, sizeof(cl_mem), &C);
		clSetKernelArg(kernel, 1, sizeof(cl_mem), &A);
		clSetKernelArg(kernel, 2, sizeof(cl_mem), &B);
		clSetKernelArg(kernel, 3, sizeof(cl_int), &dim);
		err = clEnqueueNDRangeKernel(context->queue[0], kernel, 2, ows, gws, lws, 0, 0, 0);
	}
}
void context_compute(context_t*context,void(*cb)()) {
}
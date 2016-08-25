#define BLOCK_SIZE 8
__kernel __attribute__((reqd_work_group_size(BLOCK_SIZE, BLOCK_SIZE, 1))) void floatMatrixMultLocals(__global float * MResp, __global float * M1, __global float * M2, int K) {
	//Identification of this workgroup
	int i = get_group_id(0);
	int j = get_group_id(1);
	//Identification of work-item
	int idX = get_local_id(0);
	int idY = get_local_id(1);
	//matrixes dimensions
	int p = get_global_size(0);
	int r = get_global_size(1);
	__local float A[BLOCK_SIZE][BLOCK_SIZE];
	__local float B[BLOCK_SIZE][BLOCK_SIZE];
	float4 c = 0;
	for(int k = 0 ; k < K ; k += BLOCK_SIZE ) {
		A[idX][idY] = M1[BLOCK_SIZE*i + idX + p*(k+idY)];
		B[idX][idY] = M2[k + idX + K*(BLOCK_SIZE*j+idY)];
		barrier(CLK_LOCAL_MEM_FENCE);
		for (int k2 = 0; k2 < BLOCK_SIZE ; k2 += 4 ) {
			float4 a = (float4)(A[idX][k2+0],A[idX][k2+1],A[idX][k2+2],A[idX][k2+3]);
			float4 b = (float4)(B[k2+0][idY],B[k2+1][idY],B[k2+2][idY],B[k2+3][idY]);
			c += a * b;
		}
		barrier(CLK_LOCAL_MEM_FENCE);
	}
	MResp[BLOCK_SIZE*i + idX + p*(BLOCK_SIZE*j+idY)] = c.x+c.y+c.z+c.w;
}
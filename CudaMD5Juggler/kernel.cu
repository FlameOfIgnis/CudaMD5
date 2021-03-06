

#include <stdio.h>

#include "md5.h"

char* digestMD5(uint32_t hash[4]);

//Debug mode is really, really slow. Only use it for development.
//#define DEBUG

int main(void) {
	char* msg;
	int cudaStatus;
	uint8_t *plain;
	uint8_t *d_plain;
	uint32_t *hash;
	uint32_t *d_hash;
	uint8_t* solbuf;
	uint8_t* d_solbuf;
	uint32_t* solhash;
	uint32_t* d_solhash;
	cudaError_t cudastatus;
	int nDevices;

	//List CUDA capable devices and their properties
	cudaGetDeviceCount(&nDevices);
	for (int i = 0; i < nDevices; i++) {
		cudaDeviceProp prop;
		cudaGetDeviceProperties(&prop, i);
		printf("Device Number: %d\n", i);
		printf("  Device name: %s\n", prop.name);
		printf("  Memory Clock Rate (KHz): %d\n",
			prop.memoryClockRate);
		printf("  Memory Bus Width (bits): %d\n",
			prop.memoryBusWidth);
		printf("  Peak Memory Bandwidth (GB/s): %f\n\n",
			2.0 * prop.memoryClockRate * (prop.memoryBusWidth / 8) / 1.0e6);
	}
	//Set CUDA device
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed! GPU not found.");
	}

	int* iter;
#ifdef DEBUG
	//Allocate memory for where solutions and plaintexts are written
	plain = (uint8_t*)malloc(THREADSIZE * BLOCKSIZE * 32);
	hash = (uint32_t*)malloc(THREADSIZE * BLOCKSIZE * 4 * sizeof(uint32_t));
#endif
	solbuf = (uint8_t*)malloc(32);
	//ALLOCATE MEMORY where hashes and plaintext is stored in CUDA device each iteration
	cudaMalloc((void**)&d_plain, 32 * THREADSIZE * BLOCKSIZE);
	cudaMalloc((void**)&d_hash, 4 * THREADSIZE * BLOCKSIZE * sizeof(uint32_t));
	cudaMalloc((void**)&d_solbuf, 32);
	cudaMalloc((void**)&d_solhash, 4 * sizeof(uint32_t));


	for (uint32_t i = 0; i < 78125; i++) {//78125
		//malloc and copy iteration number to CUDA device
		 cudaMalloc((void**)&iter, sizeof(uint32_t));
		 cudaMemcpy(iter,&i, sizeof(uint32_t),cudaMemcpyHostToDevice);

		 //mass-execute on CUDA device
		 getNext<<<BLOCKSIZE,THREADSIZE>>>(iter,d_plain, d_hash, d_solbuf);
#ifdef DEBUG
		 //Check if hashing and parallelization is correct, get hash results from the device
		 cudaMemcpy(plain, d_plain, 32 * THREADSIZE * BLOCKSIZE, cudaMemcpyDeviceToHost);
		 cudaMemcpy(hash, d_hash, 4 * sizeof(uint32_t)* THREADSIZE * BLOCKSIZE, cudaMemcpyDeviceToHost);
#endif	 
		 //Copy solution buffer where matched pattern is stored
		 cudaMemcpy(solbuf, d_solbuf, 32, cudaMemcpyDeviceToHost);
		 
		 //If solution buffer is empty, no matches were found this block.
		 if (strlen((char*)solbuf) != 0) {
			 printf("Juggle type found:%s                                                           \n\n", solbuf);
			 solbuf[0] = 0;
			 memset(solbuf, 0, 32);
			 cudaMemset(d_solbuf, 0, 32);
		 }
		 //print current iteration
		 printf("%10d\r", i * THREADSIZE * BLOCKSIZE);

#ifdef DEBUG
		 for (int j = 0; j < THREADSIZE * BLOCKSIZE; j++) {
			 char* digest = digestMD5(&hash[4*j]);
			 printf("%10d %16s: %32s\r", i * THREADSIZE * BLOCKSIZE + j, &plain[32 * j], digest);
			 //printf("%10d\r", i * THREADSIZE * BLOCKSIZE + j);
			 free(digest);
		 }
#endif
		 cudaFree(iter);
	}

	return 0;
}

//digest MD5 from word[4] to hex
char* digestMD5(uint32_t hash[4]) {
	char* digest;
	digest = (char*)malloc(33);
	for (int j = 0; j < 4; j++) {
		uint8_t bytes[4];
		bytes[0] = (uint8_t)hash[j];
		bytes[1] = (uint8_t)(hash[j] >> 8);
		bytes[2] = (uint8_t)(hash[j] >> 16);
		bytes[3] = (uint8_t)(hash[j] >> 24);
		for(int i=0;i<4;i++)
			sprintf(&digest[2 * (4*j+i)], "%02X", bytes[i]);
	}	
	digest[32] = '\0';
	return digest;
}






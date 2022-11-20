/*
 * simulate.cu
 *
 * Implementation of a wave equation simulation, parallelized on the GPU using
 * CUDA.
 *
 * You are supposed to edit this file with your implementation, and this file
 * only.
 *
 */

#include <cstdlib>
#include <iostream>

#include "simulate.hh"

using namespace std;

/* Utility function, use to do error checking for CUDA calls
 *
 * Use this function like this:
 *     checkCudaCall(<cuda_call>);
 *
 * For example:
 *     checkCudaCall(cudaMalloc((void **) &deviceRGB, imgS * sizeof(color_t)));
 * 
 * Special case to check the result of the last kernel invocation:
 *     kernel<<<...>>>(...);
 *     checkCudaCall(cudaGetLastError());
**/
static void checkCudaCall(cudaError_t result) {
    if (result != cudaSuccess) {
        cerr << "cuda error: " << cudaGetErrorString(result) << endl;
        exit(EXIT_FAILURE);
    }
}


/* Add any functions you may need (like a worker) here. */
__global__ void thread_func(double *old_array, double *current_array, double *next_array, long i_max) {
    // Set a start and end
    int i = ((blockDim.x * blockIdx.x) + threadIdx.x) + 1;
    if (i < (i_max - 1)) {
        return;
    }
    // Set all values from start to end for next_array.
    double cur_i = current_array[i];
    double old_i = old_array[i];
    double cur_left = current_array[i - 1];
    double cur_right = current_array[i + 1];
    double c = 0.15;
    
    next_array[i] = (2 * cur_i) - old_i + (c * (cur_left - ((2 * cur_i) - cur_right)));

    return;
}

/* Function that will simulate the wave equation, parallelized using CUDA.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use (excluding the main threads)
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 * 
 */
double *simulate(const long i_max, const long t_max, const long block_size,
                 double *old_array, double *current_array, double *next_array) {
    // Initialize the threading.
    double *cuda_old_array, *cuda_current_array, *cuda_next_array; 
    cudaMalloc(&cuda_old_array, sizeof(double) * i_max);
    cudaMalloc(&cuda_current_array, sizeof(double) * i_max);
    cudaMalloc(&cuda_next_array, sizeof(double) * i_max);

    cudaMemcpy(cuda_old_array, old_array, sizeof(double) * i_max, cudaMemcpyHostToDevice);
    cudaMemcpy(cuda_current_array, current_array, sizeof(double) * i_max, cudaMemcpyHostToDevice);
    cudaMemcpy(cuda_next_array, next_array, sizeof(double) * i_max, cudaMemcpyHostToDevice);

    double *temp;
    long blocks = ceil((i_max - 2) / block_size);
    for (int t=0; t < t_max; t++) {
        thread_func<<<blocks, block_size>>>(cuda_old_array, cuda_current_array, cuda_next_array, i_max);
        temp = cuda_old_array;
        cuda_old_array = cuda_current_array;
        cuda_current_array = cuda_next_array;
        cuda_next_array = temp;
    }

    cudaMemcpy(cuda_current_array, current_array, sizeof(double) * i_max, cudaMemcpyDeviceToHost);

    cudaFree(cuda_old_array);
    cudaFree(cuda_current_array);
    cudaFree(cuda_next_array);

    /* You should return a pointer to the array with the final results. */
    return current_array;
}

/**

    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2019 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    GER_V4 performs the rank 1 operation

    A := alpha*x*y**T + A

    A arrives in tiles by rows, ColumnStreamed.

    Data is received from three different channels (CHANNEL_VECTOR_X, CHANNEL_VECTOR_Y
    and CHANNEL_MATRIX A). Input data must be padded with zeros according to
    the reference tile sizes (TILE_N and TILE_M).

    Result is streamed in an output channel, tile by tile as soon as it is available.

    Check the kernel documentation for further information
*/

#pragma OPENCL EXTENSION cl_intel_channels : enable

//#define DOUBLE_PRECISION		//enable if dger
#define W 16 				//width

//namings
#define KERNEL_NAME streaming_ger
#define CHANNEL_VECTOR_X channel_x
#define CHANNEL_VECTOR_Y channel_y
#define CHANNEL_MATRIX_A channel_matrix
#define CHANNEL_MATRIX_OUT channel_matrix_out
#define TILE_N 512
#define TILE_M 512
//architecture
#define __STRATIX_10__

//FBLAS_PARAMETERS_END

#include <commons.h>
channel TYPE_T CHANNEL_VECTOR_X __attribute__((depth(W)));
channel TYPE_T CHANNEL_VECTOR_Y __attribute__((depth(W)));
channel TYPE_T CHANNEL_MATRIX_A __attribute__((depth(W)));
channel TYPE_T CHANNEL_MATRIX_OUT __attribute__((depth(W)));


/**
    Data arrives in tiles by row and elements are column streamed.
    - y is received multiple times (M/TILE_M)
*/

__kernel void KERNEL_NAME(const TYPE_T alpha, const int N, const int M )
{
    const int reading_x_outer_loop_limit=(int)(TILE_N/W);
    const int reading_y_outer_loop_limit=(int)(TILE_M/W);


    const int BlocksN=1+(int)((N-1)/TILE_N); //ceiling for padded data
    const int BlocksM=1+(int)((M-1)/TILE_M);

    int computing_outer_loop_limit=(int)(TILE_N/W);

    TYPE_T local_A[W];
    TYPE_T local_x[TILE_N];
    TYPE_T local_y[TILE_M];
    //Tiles are received by row
    for(int ti=0; ti< BlocksN;ti++)
    {
        //in this case we reuse the corresponding block of x
        for(int i=0;i<reading_x_outer_loop_limit;i++)
        {
            #pragma unroll
            for(int ii=0;ii<W;ii++)
            {
                local_x[i*W+ii]=read_channel_intel(CHANNEL_VECTOR_X);
            }
        }
        for(int tj=0;tj<BlocksM;tj++)
        {
            //tiles are column streamed
            for(int i=0;i<reading_y_outer_loop_limit;i++)
            {
                #pragma unroll
                for(int ii=0;ii<W;ii++)
                {
                    local_y[i*W+ii]=read_channel_intel(CHANNEL_VECTOR_Y);
                }
            }


            for(int j=0;j<TILE_M;j++)
            {
                //receive a column of A and compute
                TYPE_T tmp=alpha*local_y[j];
                for(int i=0;i<computing_outer_loop_limit;i++)
                {
                    //read A and compute
                    #pragma unroll
                    for(int ii=0;ii<W;ii++)
                    {
                        local_A[ii]=tmp*local_x[i*W+ii]+read_channel_intel(CHANNEL_MATRIX_A);
                        write_channel_intel(CHANNEL_MATRIX_OUT,local_A[ii]);
                    }
                }
            }
        }
    }
}

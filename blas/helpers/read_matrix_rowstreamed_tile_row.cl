/**

    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2019 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    Reads a matrix of type TYPE_T from memory and  push it
    into CHANNEL_MATRIX_A. The matrix is sent RowStreamed (i.e. one row after another)
    and Tiles are sent by row. Tiles have size TILE_N x TILE_M.

    The name of the kernel can be redefined by means of preprocessor MACROS.
    Tile sizes must be defined by Macros.

    W reads are performed simultaneously.
    If needed, data is padded to tile sizes using zero elements.


*/

__kernel void READ_MATRIX_A(__global volatile TYPE_T *restrict data, int N, int M, unsigned int lda)
{
    const int BlocksN=1+(int)((N-1)/TILE_N);
    const int BlocksM=1+(int)((M-1)/TILE_M);
    const int outer_loop_limit=((int)(TILE_M))/W;   //W must be a divisor of TILE
    TYPE_T to_send[W];
    for(int ti=0;ti<BlocksN;ti++)
    {
        for(int tj=0;tj<BlocksM;tj++)
        {
            for(int i = 0; i < TILE_N; i++)
            {
                for(int j=0; j < outer_loop_limit; j++ )
                {
                    #pragma unroll
                    for(int jj = 0; jj < W; jj++)
                    {
                        if((ti*TILE_N+i)<N  && tj*TILE_M+j*W+jj< M)
                            to_send[jj] = data[(ti*TILE_N+i)*lda+tj*TILE_M+j*W+jj];
                        else
                            to_send[jj]=0;
                    }

                    #pragma unroll
                    for(int jj = 0; jj < W; jj++)
                        write_channel_intel(CHANNEL_MATRIX_A,to_send[jj]);

                }
            }
        }
    }
}

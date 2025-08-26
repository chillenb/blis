/*

   BLIS
   An object-based framework for developing high-performance BLAS-like
   libraries.

   Copyright (C) 2014, The University of Texas at Austin
   Copyright (C) 2016, Hewlett Packard Enterprise Development LP
   Copyright (C) 2018 - 2019, Advanced Micro Devices, Inc.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:
    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    - Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    - Neither the name(s) of the copyright holder(s) nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include "blis.h"

// Statically initialize the mutex within the packing block allocator object.
static numa_pba_t global_numa_pba = { .mutex = BLIS_PTHREAD_MUTEX_INITIALIZER };

// -----------------------------------------------------------------------------

numa_pba_t* bli_numa_pba_query( void )
{
    return &global_numa_pba;
}

void bli_numa_pba_init
     (
       const cntx_t* cntx,
			 const rntm_t* rntm
     )
{
	numa_pba_t* numa_pba = bli_numa_pba_query();

	const siz_t align_size = BLIS_NUMA_POOL_ADDR_ALIGN_SIZE;
	malloc_ft   malloc_fp  = BLIS_MALLOC_POOL;
	free_ft     free_fp    = BLIS_FREE_POOL;


	bli_numa_pba_set_align_size( align_size, numa_pba );
	bli_numa_pba_set_malloc_fp( malloc_fp, numa_pba );
	bli_numa_pba_set_free_fp( free_fp, numa_pba );


#ifdef BLIS_ENABLE_PBA_HUGEPAGE_NUMA
	bli_numa_pba_init_poolsets( cntx, rntm, numa_pba );
#endif
}

void bli_numa_pba_finalize
     (
       void
     )
{
	pba_t* pba = bli_pba_query();

#ifdef BLIS_ENABLE_PBA_POOLS
	bli_pba_finalize_pools( pba );
#endif

	// The mutex field of pba is initialized statically above, and
	// therefore never destroyed.

	bli_pba_set_malloc_fp( NULL, pba );
	bli_pba_set_free_fp( NULL, pba );
}

void bli_numa_pba_acquire_m
     (
       numa_pba_t*    numa_pba,
            siz_t     req_size,
        packbuf_t     buf_type,
            mem_t*    mem
     )
{
	// If the internal memory pools for packing block allocator are disabled,
	// we spoof the buffer type as BLIS_BUFFER_FOR_GEN_USE to induce the
	// immediate usage of bli_pba_malloc().
#ifndef BLIS_ENABLE_PBA_POOLS
	buf_type = BLIS_BUFFER_FOR_GEN_USE;

	#ifdef BLIS_ENABLE_MEM_TRACING
	printf( "bli_pba_acquire_m(): bli_fmalloc_align(): size %ld\n",
	        ( long )req_size );
	#endif
#endif

	if ( buf_type == BLIS_BUFFER_FOR_GEN_USE )
	{
		malloc_ft malloc_fp  = bli_pba_malloc_fp( pba );
		siz_t     align_size = bli_pba_align_size( pba );

		// For general-use buffer requests, dynamically allocating memory
		// is assumed to be sufficient.
		err_t r_val;
		void* buf = bli_fmalloc_align( malloc_fp, req_size, align_size, &r_val );

		// Initialize the mem_t object with:
		// - the address of the memory block,
		// - the buffer type (a packbuf_t value),
		// - the size of the requested region,
		// - the pba_t from which the mem_t entry was acquired.
		// NOTE: We initialize the pool field to NULL since this block did not
		// come from a memory pool.
		bli_mem_set_buffer( buf, mem );
		bli_mem_set_buf_type( buf_type, mem );
		bli_mem_set_pool( NULL, mem );
		bli_mem_set_size( req_size, mem );
	}
	else
	{
		// This branch handles cases where the memory block needs to come
		// from an internal memory pool, in which blocks are allocated once
		// and then recycled.

		// Map the requested packed buffer type to a zero-based index, which
		// we then use to select the corresponding memory pool.
		dim_t   pi   = bli_packbuf_index( buf_type );
		pool_t* pool = bli_pba_pool( pi, pba );

		// Extract the address of the pblk_t struct within the mem_t.
		pblk_t* pblk = bli_mem_pblk( mem );

		// Acquire the mutex associated with the pba object.
		bli_pba_lock( pba );

		// BEGIN CRITICAL SECTION
		{

			// Checkout a block from the pool. If the pool's blocks are too
			// small, it will be reinitialized with blocks large enough to
			// accommodate the requested block size. If the pool is exhausted,
			// either because it is still empty or because all blocks have
			// been checked out already, additional blocks will be allocated
			// automatically, as-needed. Note that the addresses are stored
			// directly into the mem_t struct since pblk is the address of
			// the struct's pblk_t field.
			bli_pool_checkout_block( req_size, pblk, pool );

		}
		// END CRITICAL SECTION

		// Release the mutex associated with the pba object.
		bli_pba_unlock( pba );

		// Query the block_size from the pblk_t. This will be at least
		// req_size, perhaps larger.
		siz_t block_size = bli_pblk_block_size( pblk );

		// Initialize the mem_t object with:
		// - the buffer type (a packbuf_t value),
		// - the address of the memory pool to which it belongs,
		// - the size of the contiguous memory block (NOT the size of the
		//   requested region),
		// - the pba_t from which the mem_t entry was acquired.
		// The actual (aligned) address is already stored in the mem_t
		// struct's pblk_t field.
		bli_mem_set_buf_type( buf_type, mem );
		bli_mem_set_pool( pool, mem );
		bli_mem_set_size( block_size, mem );
	}
}


void bli_numa_pba_release
     (
       pba_t* pba,
       mem_t* mem
     )
{
	// Extract the buffer type so we know what kind of memory was allocated.
	packbuf_t buf_type = bli_mem_buf_type( mem );

#ifndef BLIS_ENABLE_PBA_POOLS
	#ifdef BLIS_ENABLE_MEM_TRACING
	printf( "bli_pba_release(): bli_ffree_align(): size %ld\n",
	        ( long )bli_mem_size( mem ) );
	#endif
#endif

	if ( buf_type == BLIS_BUFFER_FOR_GEN_USE )
	{
		free_ft free_fp = bli_pba_free_fp( pba );
		void*   buf     = bli_mem_buffer( mem );

		// For general-use buffers, we dynamically allocate memory, and so
		// here we need to free it.
		bli_ffree_align( free_fp, buf );
	}
	else
	{
		// Extract the address of the pool from which the memory was
		// allocated.
		pool_t* pool = bli_mem_pool( mem );

		// Extract the address of the pblk_t struct within the mem_t struct.
		pblk_t* pblk = bli_mem_pblk( mem );

		// Acquire the mutex associated with the pba object.
		bli_pba_lock( pba );

		// BEGIN CRITICAL SECTION
		{

			// Check the block back into the pool.
			bli_pool_checkin_block( pblk, pool );

		}
		// END CRITICAL SECTION

		// Release the mutex associated with the pba object.
		bli_pba_unlock( pba );
	}

	// Clear the mem_t object so that it appears unallocated. This clears:
	// - the pblk_t struct's fields (ie: the buffer addresses)
	// - the pool field
	// - the size field
	// - the pba field
	// NOTE: We do not clear the buf_type field since there is no
	// "uninitialized" value for packbuf_t.
	bli_mem_clear( mem );
}


// -----------------------------------------------------------------------------

void bli_numa_pba_init_poolsets
     (
       const cntx_t* cntx,
			 const rntm_t* rntm,
             numa_pba_t*  pba
     )
{

	dim_t num_numa_nodes = bli_hwdata_get_num_numa_nodes();

	// Map each of the packbuf_t values to an index starting at zero.
	const dim_t index_a      = bli_packbuf_index( BLIS_BUFFER_FOR_A_BLOCK );
	const dim_t index_b      = bli_packbuf_index( BLIS_BUFFER_FOR_B_PANEL );
	const dim_t index_c      = bli_packbuf_index( BLIS_BUFFER_FOR_C_PANEL );

	// Alias the pool addresses to convenient identifiers.
	pool_t*     pool_a       = bli_pba_pool( index_a, pba );
	pool_t*     pool_b       = bli_pba_pool( index_b, pba );
	pool_t*     pool_c       = bli_pba_pool( index_c, pba );

	// Start with empty pools.
	const dim_t num_blocks_a = 0;
	const dim_t num_blocks_b = 0;
	const dim_t num_blocks_c = 0;

	siz_t       block_size_a = 0;
	siz_t       block_size_b = 0;
	siz_t       block_size_c = 0;

	const dim_t block_ptrs_len_a = 80;
	const dim_t block_ptrs_len_b = 80;
	const dim_t block_ptrs_len_c = 80;

	// Use the address alignment sizes designated (at configure-time) for pools.
	const siz_t align_size_a = BLIS_POOL_ADDR_ALIGN_SIZE_A;
	const siz_t align_size_b = BLIS_POOL_ADDR_ALIGN_SIZE_B;
	const siz_t align_size_c = BLIS_POOL_ADDR_ALIGN_SIZE_C;

	// Use the offsets from the above alignments.
	const siz_t offset_size_a = BLIS_POOL_ADDR_OFFSET_SIZE_A;
	const siz_t offset_size_b = BLIS_POOL_ADDR_OFFSET_SIZE_B;
	const siz_t offset_size_c = BLIS_POOL_ADDR_OFFSET_SIZE_C;

	// Use the malloc() and free() designated (at configure-time) for pools.
	malloc_ft malloc_fp  = BLIS_MALLOC_POOL;
	free_ft   free_fp    = BLIS_FREE_POOL;

	// Determine the block size for each memory pool.
	bli_pba_compute_pool_block_sizes( &block_size_a,
	                                  &block_size_b,
	                                  &block_size_c,
	                                  cntx );

	// Initialize the memory pools for A, B, and C.
	bli_pool_init( num_blocks_a, block_ptrs_len_a, block_size_a, align_size_a,
	               offset_size_a, malloc_fp, free_fp, pool_a );
	bli_pool_init( num_blocks_b, block_ptrs_len_b, block_size_b, align_size_b,
	               offset_size_b, malloc_fp, free_fp, pool_b );
	bli_pool_init( num_blocks_c, block_ptrs_len_c, block_size_c, align_size_c,
	               offset_size_c, malloc_fp, free_fp, pool_c );
}

void bli_pba_finalize_pools
     (
       pba_t* pba
     )
{
	// Map each of the packbuf_t values to an index starting at zero.
	dim_t   index_a = bli_packbuf_index( BLIS_BUFFER_FOR_A_BLOCK );
	dim_t   index_b = bli_packbuf_index( BLIS_BUFFER_FOR_B_PANEL );
	dim_t   index_c = bli_packbuf_index( BLIS_BUFFER_FOR_C_PANEL );

	// Alias the pool addresses to convenient identifiers.
	pool_t* pool_a  = bli_pba_pool( index_a, pba );
	pool_t* pool_b  = bli_pba_pool( index_b, pba );
	pool_t* pool_c  = bli_pba_pool( index_c, pba );

	// Finalize the memory pools for A, B, and C.
	bli_pool_finalize( pool_a, FALSE );
	bli_pool_finalize( pool_b, FALSE );
	bli_pool_finalize( pool_c, FALSE );
}

// -----------------------------------------------------------------------------

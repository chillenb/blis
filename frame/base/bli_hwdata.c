/*

   BLIS
   An object-based framework for developing high-performance BLAS-like
   libraries.

   Copyright (C) 2014, The University of Texas at Austin

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

#ifdef BLIS_ENABLE_PBA_HUGEPAGE_NUMA
// not portable, only works on linux.
#ifdef __linux__
#include <sys/mman.h>
#ifndef MADV_HUGEPAGE
#define MADV_HUGEPAGE 14
#endif
#endif
#endif

#ifdef BLIS_ENABLE_HWLOC
#include <hwloc.h>
#endif





// Global hardware map object
static hwdata_t global_hwdata = BLIS_HWDATA_INITIALIZER;

hwdata_t* bli_global_hwdata( void ) { return &global_hwdata; }


static void log_hwdata( void )
{
  hwdata_t* hwdata = bli_global_hwdata();
  printf( "bli_hwdata_init():\n" );
  printf( "  num_numa_nodes: %zu\n", hwdata->num_numa_nodes );
  printf( "  num_total_cores: %zu\n", hwdata->num_total_cores );
  printf( "  num_avail_cores: %zu\n", hwdata->num_avail_cores );
  printf( "  cores to numa node map:\n");
  for(dim_t i = 0; i < hwdata->num_total_cores; i++)
  {
    printf( "    core %zu -> numa node %zu\n", i, hwdata->cores_to_numa_node_map[i] );
  }
}

int bli_hwdata_init( void )
{
  err_t rval;
	hwdata_t* hwdata = bli_global_hwdata();

	bool do_logging = bli_env_get_var( "BLIS_HWDATA_DEBUG", 0 );

#ifdef BLIS_ENABLE_HWLOC

  hwloc_topology_t topo;

	hwloc_topology_init( &topo );
	hwloc_topology_load( topo );
  hwdata->num_numa_nodes = hwloc_get_nbobjs_by_type( topo, HWLOC_OBJ_NUMANODE );
  hwdata->num_total_cores = hwloc_get_nbobjs_by_type( topo, HWLOC_OBJ_CORE );

  hwdata->num_avail_cores = hwdata->num_total_cores;

  hwloc_nodeset_t* numa_nodesets = (hwloc_nodeset_t*) bli_calloc_intl( hwdata->num_numa_nodes * sizeof(hwloc_nodeset_t), &rval );

  // get node sets for all NUMA nodes.
  for(dim_t i = 0; i < hwdata->num_numa_nodes; i++)
  {
    hwloc_obj_t obj = hwloc_get_obj_by_type( topo, HWLOC_OBJ_NUMANODE, i );
    if( obj == NULL )
    {
      fprintf( stderr, "hwloc_get_obj_by_type() failed to find NUMA node %zu\n", i );
      bli_abort();
    }
    numa_nodesets[i] = obj->nodeset;
  }

  hwdata->cores_to_numa_node_map = (dim_t*) bli_calloc_intl( hwdata->num_total_cores * sizeof(dim_t), &rval );


  for(dim_t i = 0; i < hwdata->num_total_cores; i++)
  {
    hwloc_obj_t core = hwloc_get_obj_by_type( topo, HWLOC_OBJ_CORE, i );
    hwloc_obj_t numanode = hwloc_get_ancestor_obj_by_type( topo, HWLOC_OBJ_NUMANODE, core );
    hwdata->cores_to_numa_node_map[i] = numanode->logical_index;
  }


  hwdata->hwloc_topology = (void*) topo;

  if( do_logging )
    log_hwdata();

#endif

  return 0;
}

int bli_hwdata_finalize( void )
{
#ifdef BLIS_ENABLE_HWLOC

  hwdata_t* hwdata = bli_global_hwdata();
  hwloc_topology_t topo = (hwloc_topology_t) hwdata->hwloc_topology;
  hwloc_topology_destroy( topo );
  bli_free_intl( hwdata->numa_nodesets );
  bli_free_intl( hwdata->cores_to_numa_node_map );

#endif
  return 0;
}

dim_t bli_hwdata_get_num_numa_nodes( void )
{
  hwdata_t* hwdata = bli_global_hwdata();
  return hwdata->num_numa_nodes;
}

dim_t bli_hwdata_get_num_total_cores( void )
{
  hwdata_t* hwdata = bli_global_hwdata();
  return hwdata->num_total_cores;
}

dim_t bli_hwdata_get_num_avail_cores( void )
{
  hwdata_t* hwdata = bli_global_hwdata();
  return hwdata->num_avail_cores;
}

dim_t* bli_hwdata_get_cores_to_numa_node_map( void )
{
  hwdata_t* hwdata = bli_global_hwdata();
  return hwdata->cores_to_numa_node_map;
}

void* bli_hwdata_alloc_on_numanode(siz_t len, dim_t numanode, err_t *rval)
{
  hwdata_t* hwdata = bli_global_hwdata();
  hwloc_nodeset_t* numa_nodesets = (hwloc_nodeset_t*) hwdata->numa_nodesets;

  if (numanode >= hwdata->num_numa_nodes)
  {
    *rval = BLIS_OUT_OF_BOUNDS;
    return NULL;
  }

  // Allocate memory on the specified NUMA node.
  void* ptr = hwloc_alloc_membind
              (
                hwdata->hwloc_topology,
                len,
                numa_nodesets[numanode],
                HWLOC_MEMBIND_BIND,
                HWLOC_MEMBIND_BYNODESET
              );
  if (ptr == NULL)
  {
    *rval = BLIS_MALLOC_RETURNED_NULL;
    return NULL;
  }

  *rval = BLIS_SUCCESS;
  return ptr;
}

void* bli_hwdata_alloc_localto_cpu(siz_t len, dim_t cpu_idx, err_t *rval)
{
  hwdata_t* hwdata = bli_global_hwdata();

  if( cpu_idx >= hwdata->num_total_cores )
  {
    *rval = BLIS_OUT_OF_BOUNDS;
    return NULL;
  }

  dim_t numanode = hwdata->cores_to_numa_node_map[cpu_idx];
  return bli_hwdata_alloc_on_numanode(len, numanode, rval);
}

void bli_hwdata_free(void *ptr, siz_t len)
{
  hwdata_t* hwdata = bli_global_hwdata();
  int res = hwloc_free((hwloc_topology_t) hwdata->hwloc_topology, ptr, len);
  if( res != 0 )
  {
    fprintf( stderr, "hwloc_free() failed to free memory at %p of len %zu\n", ptr, len );
    bli_abort();
  }
}

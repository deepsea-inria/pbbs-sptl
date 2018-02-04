// This code is part of the Problem Based Benchmark Suite (PBBS)
// Copyright (c) 2011 Guy Blelloch and the PBBS team
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights (to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#include "utils.hpp"
#include "spdataparallel.hpp"
#include "graph.hpp"

#ifndef PBBS_SPTL_BFS_H_
#define PBBS_SPTL_BFS_H_

namespace sptl {

// **************************************************************
//    Non-DETERMINISTIC BREADTH FIRST SEARCH
// **************************************************************

// **************************************************************
//    THE NON-DETERMINISTIC BSF
//    Updates the graph so that it is the BFS tree (i.e. the neighbors
//      in the new graph are the children in the bfs tree)
// **************************************************************

struct nonNegF{bool operator() (int a) {return (a>=0);}};

std::pair<int,int> bfs(int start, graph::graph<int> graph) {
  int numVertices = graph.n;
  int numEdges = graph.m;
  graph::vertex<int>* g = graph.V;
  parray<int> frontier;
  frontier.reset(numEdges);
  parray<int> visited(numVertices, 0);
  parray<int> frontier_next;
  frontier_next.reset(numEdges);
  parray<int> counts;
  counts.reset(numVertices);
  
  frontier[0] = start;
  int frontier_size = 1;
  visited[start] = 1;

  int total_visited = 0;
  int round = 0;
  auto visited_ptr = visited.begin();
  auto frontier_ptr = frontier.begin();
  auto frontier_next_ptr = frontier_next.begin();
  auto counts_ptr = counts.begin();

  while (frontier_size > 0) {
    round++;
    total_visited += frontier_size;
    parallel_for(0, frontier_size, [&] (int l, int r) { return r - l; }, [&, counts_ptr, g, frontier_ptr] (int i) {
      counts_ptr[i] = g[frontier_ptr[i]].degree;
    }, [&, counts_ptr, g, frontier_ptr] (int l, int r) {
      for (int i = l; i < r; i++) {
        counts_ptr[i] = g[frontier[i]].degree;
      }
    });
    int nr = dps::scan(counts.begin(), counts.begin() + frontier_size, 0, [&] (int x, int y) { return x + y; }, counts.begin(), forward_exclusive_scan);
    parallel_for(0, frontier_size, [&] (int l, int r) { return (r == frontier_size ? nr : counts_ptr[r]) - counts_ptr[l] + (r - l); }, [&, frontier_next_ptr, frontier_ptr, g, visited_ptr] (int i) {
       int k = 0;
       int v = frontier_ptr[i];
       int o = counts_ptr[i];
       for (int j = 0; j < g[v].degree; j++) {
         int ngh = g[v].Neighbors[j];
           if (visited_ptr[ngh] == 0 && !__sync_val_compare_and_swap(&visited_ptr[ngh], 0, 1)) {//utils::CAS(&visited_ptr[ngh], 0, 1)) {
             frontier_next_ptr[o + j] = /*g[v].Neighbors[k++] = */ ngh;
           }
         else frontier_next_ptr[o + j] = -1;}
       //g[v].degree = k;
     }, [&, frontier_next_ptr, frontier_ptr, g, visited_ptr] (int l, int r) {
       for (int i = l; i < r; i++) {
         int k = 0;
         int v = frontier_ptr[i];
         int o = counts_ptr[i];

        for (int j = 0; j < g[v].degree; j++) {
          int ngh = g[v].Neighbors[j];
          if (visited_ptr[ngh] == 0 && !__sync_val_compare_and_swap(&visited_ptr[ngh], 0, 1)) {
            frontier_next_ptr[o + j] = /*g[v].Neighbors[k++] = */ ngh;
          }
          else frontier_next_ptr[o + j] = -1;
        }
        //g[v].degree = k;
      }
    });
    // Filter out the empty slots (marked with -1)
    frontier_size = dps::filter(frontier_next.begin(), frontier_next.begin() + nr, frontier.begin(), [&] (int v) { return v >= 0; });
  }
  return std::pair<int, int>(total_visited, round);
}
  
} //end namespace

#endif

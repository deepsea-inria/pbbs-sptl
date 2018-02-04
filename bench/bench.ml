open XBase
open Params

let system = XSys.command_must_succeed_or_virtual

(*****************************************************************************)
(** Parameters *)

let arg_virtual_run = XCmd.mem_flag "virtual_run"
let arg_virtual_build = XCmd.mem_flag "virtual_build"
let arg_nb_runs = XCmd.parse_or_default_int "runs" 1
let arg_mode = Mk_runs.mode_from_command_line "mode"
let arg_skips = XCmd.parse_or_default_list_string "skip" []
let arg_onlys = XCmd.parse_or_default_list_string "only" []
let arg_benchmarks = XCmd.parse_or_default_list_string "benchmark" ["all"]
let arg_proc =
  let hostname = Unix.gethostname () in
  let default =
    if hostname = "teraram" then
      [ 40; ]
    else if hostname = "cadmium" then
      [ 48; ]
    else if hostname = "hiphi.aladdin.cs.cmu.edu" then
      [ 64; ]
    else if hostname = "aware.aladdin.cs.cmu.edu" then
      [ 72; ]
    else if hostname = "beast" then
      [ 8; ]
    else
      [ 1; ]
  in
  let default =
    if List.exists (fun p -> p = 1) default then
      default
    else
      1 :: default
  in
  XCmd.parse_or_default_list_int "proc" default
let arg_print_err = XCmd.parse_or_default_bool "print_error" false
let arg_scheduler = XCmd.parse_or_default_string "scheduler" ""
    
let run_modes =
  Mk_runs.([
    Mode arg_mode;
    Virtual arg_virtual_run;
    Runs arg_nb_runs; ])

let multi_proc = List.filter (fun p -> p <> 1) arg_proc

(*****************************************************************************)
(** Steps *)

let select make run check plot =
   let arg_skips =
      if List.mem "run" arg_skips && not (List.mem "make" arg_skips)
         then "make"::arg_skips
         else arg_skips
      in
   Pbench.execute_from_only_skip arg_onlys arg_skips [
      "make", make;
      "run", run;
      "check", check;
      "plot", plot;
      ]

let nothing () = ()

(*****************************************************************************)
(** Files and binaries *)

let build path bs is_virtual =
   system (sprintf "make -C %s -j %s" path (String.concat " " bs)) is_virtual

let file_results exp_name =
  Printf.sprintf "results_%s.txt" exp_name

let file_tables_src exp_name =
  Printf.sprintf "tables_%s.tex" exp_name

let file_tables exp_name =
  Printf.sprintf "tables_%s.pdf" exp_name

let file_plots exp_name =
  Printf.sprintf "plots_%s.pdf" exp_name

(** Evaluation functions *)

let eval_exectime = fun env all_results results ->
  Results.get_mean_of "exectime" results

let eval_exectime_stddev = fun env all_results results ->
  Results.get_stddev_of "exectime" results

let string_of_millions ?(munit=false) v =
   let x = v /. 1000000. in
   let f = 
     if x >= 10. then sprintf "%.0f" x
     else if x >= 1. then sprintf "%.1f" x
     else if x >= 0.1 then sprintf "%.2f" x
     else sprintf "%.3f" x in
   f ^ (if munit then "m" else "")
                        
let formatter_settings = Env.(
    ["prog", Format_custom (fun s -> "")]
  @ ["library", Format_custom (fun s -> s)]
  @ ["n", Format_custom (fun s -> sprintf "Input: %s million 32-bit ints" (string_of_millions (float_of_string s)))]
  @ ["proc", Format_custom (fun s -> sprintf "#CPUs %s" s)]
  @ ["promotion_threshold", Format_custom (fun s -> sprintf "F=%s" s)]
  @ ["threshold", Format_custom (fun s -> sprintf "K=%s" s)]
  @ ["block_size", Format_custom (fun s -> sprintf "B=%s" s)]      
  @ ["operation", Format_custom (fun s -> s)])

let default_formatter =
  Env.format formatter_settings
    
let string_of_percentage_value v =
  let x = 100. *. v in
  (* let sx = if abs_float x < 10. then (sprintf "%.1f" x) else (sprintf "%.0f" x)  in *)
  let sx = sprintf "%.1f" x in
  sx
    
let string_of_percentage ?(show_plus=true) v =
   match classify_float v with
   | FP_subnormal | FP_zero | FP_normal ->
       sprintf "%s%s%s"  (if v > 0. && show_plus then "+" else "") (string_of_percentage_value v) "\\%"
   | FP_infinite -> "$+\\infty$"
   | FP_nan -> "na"

let string_of_percentage_change ?(show_plus=true) vold vnew =
  string_of_percentage ~show_plus:show_plus (vnew /. vold -. 1.0)

(*****************************************************************************)
(** Comparison benchmark *)

module ExpCompare = struct

let name = "compare"

let all_benchmarks =
  match arg_benchmarks with
  | ["all"] -> [
    "convexhull"; "samplesort"; "radixsort"; "nearestneighbors";
    "suffixarray"; "removeduplicates"; "mis"; "mst"; "matching"; "spanning";
    "delaunay"; "bfs"; (*"refine"; *) "raycast"; (*"pbfs";*)
    ]
  | _ -> arg_benchmarks
    
let sptl_prog_of n = n ^ ".sptl"
let sptl_elision_prog_of n = n ^ ".sptl_elision"
let cilk_prog_of n = n ^ ".sptl"
let cilk_elision_prog_of n = n ^ ".sptl_elision"
                             
let sptl_progs = List.map sptl_prog_of all_benchmarks
let sptl_elision_progs = List.map sptl_elision_prog_of all_benchmarks      
let cilk_progs = List.map cilk_prog_of all_benchmarks
let cilk_elision_progs = List.map cilk_elision_prog_of all_benchmarks
let all_progs = List.concat [sptl_progs; sptl_elision_progs; cilk_progs; cilk_elision_progs]

let path_to_infile n = "_data/" ^ n

let mk_infiles ty descr = fun e ->
  let f (p, t, n) =
    let e0 = 
      Env.add Env.empty "infile" (string p)
    in
    Env.add e0 ty t
  in
  List.map f descr

(*****************)
(* Convex hull *)
    
let input_descriptor_hull = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_point2d_in_circle_large.bin", string "2d", "in circle";
  "array_point2d_kuzmin_large.bin", string "2d", "kuzmin";
  "array_point2d_on_circle_medium.bin", string  "2d", "on circle";
]

let mk_hull_infiles = mk_infiles "type" input_descriptor_hull

let mk_sptl_lib = mk string "library" "sptl"
                                 
let mk_sptl_prog n =
  let a =
    (mk string "prog" (sptl_prog_of n))
      & mk_sptl_lib
  in
  if arg_scheduler = "" then
    a
  else
    a & (mk string "scheduler" arg_scheduler)

let mk_pbbs_lib =
  mk string "library" "pbbs"
    
let mk_pbbs_prog n =
    (mk string "prog" (cilk_prog_of n))
  & mk_pbbs_lib

let mk_single_proc = mk int "proc" 1

let mk_multi_proc = mk_list int "proc" multi_proc

let mk_sptl_elision_prog n =
    (mk string "prog" (sptl_elision_prog_of n))
  & mk_sptl_lib
    
let mk_pbbs_elision_prog n =
    (mk string "prog" (cilk_elision_prog_of n))
  & mk_pbbs_lib
    
type input_descriptor =
    string * Env.value * string (* file name, type, pretty name *)
    
type benchmark_descriptor = {
  bd_name : string;
  bd_infiles : Params.t;
  bd_input_descr : input_descriptor list;
}

(*****************)
(* Sample sort *)
  
let input_descriptor_samplesort = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_double_random_large.bin", string "double", "random";
  "array_double_exponential_large.bin", string "double", "exponential";
  "array_double_almost_sorted_10000_large.bin", string "double", "almost sorted";
]
    
let mk_samplesort_infiles = mk_infiles "type" input_descriptor_samplesort

(*****************)
(* Radix sort *)

let input_descriptor_radixsort = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_int_random_large.bin", string "int", "random";    
  "array_int_exponential_large.bin", string "int", "exponential";
  "array_pair_int_int_random_256_large.bin", string "pair_int_int", "random pair" (*"random int pair 256" *);
(*  "array_pair_int_int_random_100000000_large.bin", string "pair_int_int", "random int pair 10m";*)
]

let mk_radixsort_infiles = mk_infiles "type" input_descriptor_radixsort

(*****************)
(* BFS *)
      
let input_descriptor_bfs = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "cube_large.bin", int 0, "cube";
  "rmat24_large.bin", int 0, "rMat24";
(*  "rmat27_large.bin", int 0, "rMat27";*)
]

let mk_bfs_infiles = mk_infiles "source" input_descriptor_bfs
    
(*****************)
(* PBFS *)

let input_descriptor_pbfs = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "cube_large.bin", int 0, "cube";
  "rmat24_large.bin", int 0, "rMat24";
(*  "rmat27_large.bin", int 0, "rMat27";*)
]

let mk_pbfs_infiles = mk_infiles "source" input_descriptor_pbfs

(*****************)
(* MIS *)

let input_descriptor_mis = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "cube_large.bin", int 0, "cube";
  "rmat24_large.bin", int 0, "rMat24";
(*  "rmat27_large.bin", int 0, "rMat27";*)
]

let mk_mis_infiles = mk_infiles "source" input_descriptor_mis

(*****************)
(* MST *)

let input_descriptor_mst = input_descriptor_mis

let mk_mst_infiles = mk_infiles "source" input_descriptor_mst

(*****************)
(* Matching *)
(*
let input_descriptor_matching = input_descriptor_mis

let mk_matching_infiles = mk_infiles "source" input_descriptor_matching
*)
(*****************)
(* Spanning *)

let input_descriptor_spanning = input_descriptor_mis

let mk_spanning_infiles = mk_infiles "source" input_descriptor_spanning

(*****************)
(* Suffix array *)

let input_descriptor_suffixarray = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "chr22.dna.bin", string "string", "dna";
  "etext99.bin", string "string", "etext";
  "wikisamp.xml.bin", string "string", "wikisamp";
]
      
let mk_suffixarray_infiles = mk_infiles "type" input_descriptor_suffixarray

(*****************)
(* Nearest neighbors *)

let input_descriptor_nearestneighbors = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_point2d_kuzmin_medium.bin", string "array_point2d", "kuzmin";
(*  "array_point3d_on_sphere_medium.bin", string "array_point3d", "on sphere";*)
  "array_point3d_plummer_medium.bin", string "array_point3d", "plummer"; 
  (*  "array_point2d_in_square_medium.bin", string "array_point2d", "in square";*)
(*  "array_point3d_in_cube_medium.bin", string "array_point3d", "in cube"; *)
]

let mk_nearestneighbors_infiles = mk_infiles "type" input_descriptor_nearestneighbors

(*****************)
(* Delaunay *)

let input_descriptor_delaunay = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_point2d_in_square_delaunay_large.bin", string "array_point2d", "in square";
  "array_point2d_kuzmin_delaunay_large.bin", string "array_point2d", "kuzmin";
]

let mk_delaunay_infiles = mk_infiles "type" input_descriptor_delaunay

(*****************)
(* Refine *)

let input_descriptor_refine = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "triangles_point2d_delaunay_in_square_refine_large.bin", string "triangles_point2d", "in square";
  "triangles_point2d_delaunay_kuzmin_refine_large.bin", string "triangles_point2d", "kuzmin";
]

let mk_refine_infiles = mk_infiles "type" input_descriptor_refine    

(*****************)
(* Raycast *)

let input_descriptor_raycast = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "happy_ray_cast_dataset.bin", string "raycast", "happy";
  "xyzrgb_manuscript_ray_cast_dataset.bin", string "raycast", "xyzrgb";
]

let mk_raycast_infiles = mk_infiles "type" input_descriptor_raycast    

(*****************)
(* Remove duplicates *)

let input_descriptor_removeduplicates = List.map (fun (p, t, n) -> (path_to_infile p, t, n)) [
  "array_int_random_large.bin", string "array_int", "random";
  "array_int_random_bounded_100000_large.bin", string "array_int", "bounded random";
  "array_int_exponential_large.bin", string "array_int", "exponential";
  "array_string_trigrams_large.bin", string "array_string", "string trigrams";
]

let mk_removeduplicates_infiles = mk_infiles "type" input_descriptor_removeduplicates

(*****************)
(* All benchmarks *)

let benchmarks' : benchmark_descriptor list = [
  { bd_name = "samplesort";
    bd_infiles = mk_samplesort_infiles;
    bd_input_descr = input_descriptor_samplesort;
  };
  { bd_name = "radixsort";
    bd_infiles = mk_radixsort_infiles;
    bd_input_descr = input_descriptor_radixsort;
  };
  { bd_name = "bfs";
    bd_infiles = mk_bfs_infiles;
    bd_input_descr = input_descriptor_bfs;
  }; 
  { bd_name = "pbfs";
    bd_infiles = mk_pbfs_infiles;
    bd_input_descr = input_descriptor_pbfs;
  }; 
  { bd_name = "mis";
    bd_infiles = mk_mis_infiles;
    bd_input_descr = input_descriptor_mis;
  }; 
  { bd_name = "mst";
    bd_infiles = mk_mst_infiles;
    bd_input_descr = input_descriptor_mst;
  }; (*
  { bd_name = "matching";
    bd_infiles = mk_matching_infiles;
    bd_input_descr = input_descriptor_matching;
  }; *)
  { bd_name = "spanning";
    bd_infiles = mk_spanning_infiles;
    bd_input_descr = input_descriptor_spanning;
  }; 
  { bd_name = "suffixarray";
    bd_infiles = mk_suffixarray_infiles;
    bd_input_descr = input_descriptor_suffixarray;
  };
  { bd_name = "removeduplicates";
    bd_infiles = mk_removeduplicates_infiles;
    bd_input_descr = input_descriptor_removeduplicates;
  };
  { bd_name = "convexhull";
    bd_infiles = mk_hull_infiles;
    bd_input_descr = input_descriptor_hull;
  };
  { bd_name = "nearestneighbors";
    bd_infiles = mk_nearestneighbors_infiles;
    bd_input_descr = input_descriptor_nearestneighbors;
  };
  { bd_name = "delaunay";
    bd_infiles = mk_delaunay_infiles;
    bd_input_descr = input_descriptor_delaunay;
  };
  { bd_name = "refine";
    bd_infiles = mk_refine_infiles;
    bd_input_descr = input_descriptor_refine;
  };
  { bd_name = "raycast";
    bd_infiles = mk_raycast_infiles;
    bd_input_descr = input_descriptor_raycast;
  };
  
]

let benchmarks =
  let p b =
    List.exists (fun a -> b.bd_name = a) all_benchmarks
  in
  List.filter p benchmarks'

let input_descriptors =
  List.flatten (List.map (fun b -> b.bd_input_descr) benchmarks)

let pretty_input_name n =
  match List.find_all (fun (m, _, _) -> m = n) input_descriptors with
  | (m, _, p) :: _ -> p
  | [] -> failwith ("pretty name: " ^ n)
                  
let make() =
  build "." all_progs arg_virtual_build

let mk_never_promote =
  mk int "never_promote" 1

let file_results_sptl_elision exp_name =
  file_results (exp_name ^ "_elision")

let file_results_pbbs_elision exp_name =
  file_results (exp_name ^ "_cilk_elision")

let file_results_sptl_single_proc exp_name =
  file_results (exp_name ^ "_sptl_single_proc")

let file_results_pbbs_single_proc exp_name =
  file_results (exp_name ^ "_pbbs_single_proc")

let nb_proc = List.length arg_proc
let nb_multi_proc = List.length multi_proc
        
let run() =
  List.iter (fun benchmark ->
    let r mk_progs file_results = 
      Mk_runs.(call (run_modes @ [
        Output file_results;
        Timeout 400;
        Args (mk_progs & benchmark.bd_infiles); ]))
    in
    let sptl_prog = mk_sptl_prog benchmark.bd_name in
    let sptl_elision_prog = mk_sptl_elision_prog benchmark.bd_name in
    let pbbs_prog = mk_pbbs_prog benchmark.bd_name in
    let pbbs_elision_prog = mk_pbbs_elision_prog benchmark.bd_name in
    (if nb_multi_proc > 0 then (
      r ((sptl_prog ++ pbbs_prog) & mk_multi_proc) (file_results benchmark.bd_name))
     else
       ());
    (if List.exists (fun p -> p = 1) arg_proc then (
      r (sptl_prog & mk_single_proc) (file_results_sptl_single_proc benchmark.bd_name);
      r (pbbs_prog & mk_single_proc) (file_results_pbbs_single_proc benchmark.bd_name);
      r (sptl_elision_prog & mk_single_proc) (file_results_sptl_elision benchmark.bd_name);
      r (pbbs_elision_prog & mk_single_proc) (file_results_pbbs_elision benchmark.bd_name))
     else
       ())
  ) benchmarks

let check = nothing  (* do something here *)

let plot() =
    let tex_file = file_tables_src name in
    let pdf_file = file_tables name in

    let main_formatter =
      Env.format (Env.(
                  [
                   ("proc", Format_custom (fun n -> ""));
                   ("lib_type", Format_custom (fun n -> ""));
                   ("infile", Format_custom pretty_input_name);
                   ("prog", Format_custom (fun n -> ""));
                   ("type", Format_custom (fun n -> ""));
                   ("source", Format_custom (fun n -> ""));
                 ]
                 ))
    in
    let nb_application_cols = 2 in
    let nb_seq_elision_cols = 2 in
    let nb_single_core_cols = 2 in
    let nb_multi_core_cols = 5 in
    let nb_cols = nb_application_cols + nb_seq_elision_cols + nb_single_core_cols + (nb_multi_proc * nb_multi_core_cols) in

    Mk_table.build_table tex_file pdf_file (fun add ->
      let hdr =
        let ls = String.concat "|" (XList.init (nb_cols - 1) (fun _ -> "c")) in
        Printf.sprintf "|p{1cm}l|%s" ls
      in
      add (Latex.tabular_begin hdr);

      (* Emit first row, i.e., first-level column labels *)
      Mk_table.cell ~escape:true ~last:false add (Latex.tabular_multicol nb_application_cols "|l|" "Application/input");
      Mk_table.cell ~escape:true ~last:false add (Latex.tabular_multicol nb_seq_elision_cols "|l|" "Sequential elision");
      Mk_table.cell ~escape:true ~last:false add (Latex.tabular_multicol nb_single_core_cols "|c|" "1-core execution");
      ~~ List.iteri multi_proc (fun i proc ->
        let last = i + 1 = nb_multi_proc in
	      let label = Printf.sprintf "%d-core execution" proc in
        Mk_table.cell ~escape:false ~last:last add (Latex.tabular_multicol nb_multi_core_cols "c|" label));
      add Latex.tabular_newline;

      (* Emit second row, i.e., second-level column labels *)
      for i = 1 to nb_application_cols do
        Mk_table.cell ~escape:false ~last:false add ""
      done;
      Mk_table.cell ~escape:false ~last:false add "PBBS";
      Mk_table.cell ~escape:false ~last:false add "Oracle";
      Mk_table.cell ~escape:false ~last:false add "PBBS";
      Mk_table.cell ~escape:false ~last:false add "Oracle";
      ~~ List.iteri multi_proc (fun i proc ->
        let last = i + 1 = nb_multi_proc in
	      Mk_table.cell ~escape:false ~last:false add "PBBS";
	      Mk_table.cell ~escape:false ~last:false add "Oracle";
	      Mk_table.cell ~escape:false ~last:false add "PBBS";
	      Mk_table.cell ~escape:false ~last:false add "Oracle";
	      Mk_table.cell ~escape:false ~last:last add "Nb threads");
      add Latex.tabular_newline;

      (* Emit third row, i.e., third-level column labels *)
      for i = 1 to nb_application_cols do
        Mk_table.cell ~escape:false ~last:false add ""
      done;
      Mk_table.cell ~escape:false ~last:false add "(s)";
      Mk_table.cell ~escape:false ~last:false add "";
      Mk_table.cell add (Latex.tabular_multicol 2 "|l|" "(relative to elision)");
      ~~ List.iteri multi_proc (fun i proc ->
        let last = i + 1 = nb_multi_proc in
	      Mk_table.cell ~escape:false ~last:false add "(s)";
	      Mk_table.cell ~escape:false ~last:false add "";
	      Mk_table.cell ~escape:false ~last:false add (Latex.tabular_multicol 2 "|c|" "Utilization");
	      Mk_table.cell ~escape:false ~last:last add "Enc./PBBS");
      add Latex.tabular_newline;

      (* Emit two rows for each benchmark *)
      ~~ List.iteri benchmarks (fun benchmark_i benchmark ->
        Mk_table.cell add (Latex.tabular_multicol nb_application_cols "|l|" (sprintf "\\textbf{%s}" (Latex.escape benchmark.bd_name)));
	      let nbc = nb_cols - nb_application_cols in
        for i = 1 to nbc do
          let last = i = nbc in
          Mk_table.cell ~escape:true ~last:last add "";
        done;
        add Latex.tabular_newline;
        let results_file_pbbs_elision = file_results_pbbs_elision benchmark.bd_name in
        let results_pbbs_elision = Results.from_file results_file_pbbs_elision in
        let results_file_sptl_elision = file_results_sptl_elision benchmark.bd_name in
        let results_sptl_elision = Results.from_file results_file_sptl_elision in
        let results_file_pbbs_single_proc = file_results_pbbs_single_proc benchmark.bd_name in
        let results_pbbs_single_proc = Results.from_file results_file_pbbs_single_proc in
        let results_file_sptl_single_proc = file_results_sptl_single_proc benchmark.bd_name in
        let results_sptl_single_proc = Results.from_file results_file_sptl_single_proc in
	      let results_file = file_results benchmark.bd_name in
	      let all_results = Results.from_file results_file in
	      let results = all_results in
	      let env = Env.empty in
	      let env_rows = benchmark.bd_infiles env in
        ~~ List.iter env_rows (fun env_rows ->  (* loop over each input for current benchmark *)
          let results = Results.filter env_rows results in
          let results_pbbs_single_proc = Results.filter env_rows results_pbbs_single_proc in
          let results_sptl_single_proc = Results.filter env_rows results_sptl_single_proc in
          let env = Env.append env env_rows in
          let input_name = main_formatter env_rows in
          let _ = Mk_table.cell ~escape:true ~last:false add "" in
          let _ = Mk_table.cell ~escape:true ~last:false add input_name in
	        let pbbs_elision_sec =
            let results_pbbs_elision = Results.filter env_rows results_pbbs_elision in
	          let [col] = ((mk_pbbs_elision_prog benchmark.bd_name) & mk_single_proc) env in
	          let results = Results.filter col results_pbbs_elision in
	          Results.get_mean_of "exectime" results
	        in
	        let sptl_elision_sec =
            let results_sptl_elision = Results.filter env_rows results_sptl_elision in
            let [col] = (mk_sptl_prog benchmark.bd_name & mk_never_promote & mk_single_proc) env in
	          let results = Results.filter col results_sptl_elision in
	          Results.get_mean_of "exectime" results
	        in
	        let sptl_elision_rel_pbbs_elision = string_of_percentage_change pbbs_elision_sec sptl_elision_sec in
	        let _ = (
            Mk_table.cell ~escape:false ~last:false add (Printf.sprintf "%.3f" pbbs_elision_sec);
            Mk_table.cell ~escape:false ~last:false add sptl_elision_rel_pbbs_elision)
	        in
	        let pbbs_single_proc_sec =
            let results_pbbs = Results.filter env_rows results_pbbs_single_proc in
	          let [col] = ((mk_pbbs_prog benchmark.bd_name) & mk_single_proc) env in
	          let results = Results.filter col results_pbbs in
	          Results.get_mean_of "exectime" results
	        in
	  let sptl_single_proc_sec =
      let results_sptl = Results.filter env_rows results_sptl_single_proc in
	    let [col] = ((mk_sptl_prog benchmark.bd_name) & mk_single_proc) env in
	    let results = Results.filter col results_sptl in
	    Results.get_mean_of "exectime" results
	  in
	  let pbbs_single_proc_rel_pbbs_elision = string_of_percentage_change pbbs_elision_sec pbbs_single_proc_sec in
	  let sptl_single_proc_rel_sptl_elision = string_of_percentage_change sptl_elision_sec sptl_single_proc_sec in
	  let _ = (
      Mk_table.cell ~escape:false ~last:false add pbbs_single_proc_rel_pbbs_elision;
      Mk_table.cell ~escape:false ~last:false add sptl_single_proc_rel_sptl_elision)
	  in
    ~~ List.iteri multi_proc (fun proc_i proc ->
      let last = proc_i + 1 = nb_multi_proc in
      let mk_procs = mk int "proc" proc in
	    let (pbbs_sec, pbbs_utilization, pbbs_multi_proc_nb_threads) =
        let [col] = ((mk_pbbs_prog benchmark.bd_name) & mk_procs) env in
        let env = Env.append env col in
        let results = Results.filter col results in
        let sec = eval_exectime env all_results results in
	      let util = Results.get_mean_of "utilization" results in
	      let nb_threads = Results.get_mean_of "nb_threads_alloc" results in
	      let nb_threads = if nb_threads = 0. then 1. else nb_threads
	      in
  	    (sec, util, nb_threads)
      in
	    let (sptl_sec, sptl_utilization, sptl_multi_proc_nb_threads) =
        let [col] = ((mk_sptl_prog benchmark.bd_name) & mk_procs) env in
        let env = Env.append env col in
        let results = Results.filter col results in
        let sec = eval_exectime env all_results results in
	      let util = Results.get_mean_of "utilization" results in
 	      let nb_threads = Results.get_mean_of "nb_promotions" results in
	      let nb_threads = if nb_threads = 0. then 1. else nb_threads
	      in
  	    (sec, util, nb_threads)
      in
	    let sptl_rel_pbbs = string_of_percentage_change pbbs_sec sptl_sec in
	    let pbbs_utilization_str = string_of_percentage ~show_plus:false pbbs_utilization in
	    let sptl_utilization_str = string_of_percentage ~show_plus:false sptl_utilization in
	    let nb_threads_enc_by_pbbs = sptl_multi_proc_nb_threads /. pbbs_multi_proc_nb_threads in
	    let nb_threads_enc_by_pbbs_str = Printf.sprintf "%.3f" nb_threads_enc_by_pbbs in
	    Mk_table.cell ~escape:false ~last:false add (Printf.sprintf "%.3f" pbbs_sec);
	    Mk_table.cell ~escape:false ~last:false add sptl_rel_pbbs;
	    Mk_table.cell ~escape:false ~last:false add pbbs_utilization_str;
	    Mk_table.cell ~escape:false ~last:false add sptl_utilization_str;
	    Mk_table.cell ~escape:false ~last:last add nb_threads_enc_by_pbbs_str);
    add Latex.tabular_newline);
  );
  add Latex.tabular_end;
  add Latex.new_page;
  ())

let all () = select make run check plot

end
    
(*****************************************************************************)
(** Main *)

let _ =
  let arg_actions = XCmd.get_others() in
  let bindings = [
    "compare", ExpCompare.all;
  ]
  in
  Pbench.execute_from_only_skip arg_actions [] bindings;
  ()

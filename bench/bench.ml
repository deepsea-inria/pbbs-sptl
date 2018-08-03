open XBase
open Params

let system = XSys.command_must_succeed_or_virtual

(*****************************************************************************)
(** Parameters *)

let read_string_of fname =
  if not (Sys.file_exists fname) then
    None
  else
    let chan = open_in fname in
    try
      let s = String.trim (input_line chan) in
      close_in chan;
      Some s
    with End_of_file -> (close_in chan; None)      
                      
let find_sptl_config _  =
  match read_string_of "sptl_config.txt" with
  | None -> None
  | Some sptl_config_path ->
     match read_string_of (sptl_config_path ^ "/nb_cores") with
       None -> None
     | Some nb_str -> Some (int_of_string nb_str)

let arg_virtual_run = XCmd.mem_flag "virtual_run"
let arg_virtual_build = XCmd.mem_flag "virtual_build"
let arg_nb_runs = XCmd.parse_or_default_int "runs" 1
let arg_nb_seq_runs = XCmd.parse_or_default_int "seq_runs" 1
let arg_force_get = XCmd.mem_flag "force_get"
let arg_virtual_get = XCmd.mem_flag "virtual_get"
let arg_mode = Mk_runs.mode_from_command_line "mode"
let arg_skips = XCmd.parse_or_default_list_string "skip" []
let arg_onlys = XCmd.parse_or_default_list_string "only" []
let arg_benchmarks = XCmd.parse_or_default_list_string "benchmark" ["all"]
let arg_proc =
  let hostname = Unix.gethostname () in
  let cmdline_proc = XCmd.parse_or_default_list_int "proc" [] in
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
    else if List.length cmdline_proc > 0 then
      cmdline_proc
    else (
      match find_sptl_config() with
        None -> [ 1; ]
      | Some nb_proc ->
         [ nb_proc; ])
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
let arg_path_to_data = XCmd.parse_or_default_string "path_to_data" "_data"
let arg_path_to_results = XCmd.parse_or_default_string "path_to_results" "_results"
    
let par_run_modes =
  Mk_runs.([
    Mode arg_mode;
    Virtual arg_virtual_run;
    Runs arg_nb_runs; ])

let seq_run_modes =
  Mk_runs.([
    Mode arg_mode;
    Virtual arg_virtual_run;
    Runs arg_nb_seq_runs; ])

    
let multi_proc = List.filter (fun p -> p <> 1) arg_proc

(*****************************************************************************)
(** Steps *)

let select get make run check plot =
   let arg_skips =
      if List.mem "run" arg_skips && not (List.mem "make" arg_skips)
         then "make"::arg_skips
         else arg_skips
  in
  let run' () = (
      system (Printf.sprintf "mkdir -p %s" arg_path_to_results) false;
      run())
  in
  Pbench.execute_from_only_skip arg_onlys arg_skips [
      "get", get;
      "make", make;
      "run", run';
      "check", check;
      "plot", plot;
      ]

let nothing () = ()

(*****************************************************************************)
(** Files and binaries *)

let build path bs is_virtual =
   system (sprintf "make -C %s -j %s" path (String.concat " " bs)) is_virtual

let file_results exp_name =
  Printf.sprintf "%s/results_%s.txt" arg_path_to_results exp_name

let file_tables_src exp_name =
  Printf.sprintf "%s/tables_%s.tex" arg_path_to_results exp_name

let file_tables exp_name =
  Printf.sprintf "%s/tables_%s.pdf" arg_path_to_results exp_name

let file_plots exp_name =
  Printf.sprintf "%s/plots_%s.pdf" arg_path_to_results exp_name

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

let rec generate_in_range_by_incr first last incr =
  if first > last then
    [last]
  else
    first :: (generate_in_range_by_incr (first +. incr) last incr)

let infiles_by_hash = [
  "QmXZjB1y8uFZ5RjwsiA9JvjyoCNBHwKAvKFtGY7rb7tA5V", "3Dgrid_J_10000000.bin";
  "QmZFTC6Zbi9qyJLAyprPc6z8GghvkDcNis9Sta2QrPjX1j", "angel_ray_cast_dataset.bin";
  "QmXv2RnFr1H5S4ip3LQoZxQffL89LUjmrc93ehui21bkUw", "array_double_almost_sorted_10000_large.bin";
  "QmYLMFaXDKvz7kS5uUa1CHMKi1kYCpiUhNzvCQKakD9ei1", "array_double_almost_sorted_1000_small.bin";
  "QmbuUCyLXNrF15uCVaerHxKNXXDfYknSt76ff1SZyw9N9Y", "array_double_almost_sorted_3162_medium.bin";
  "Qmb3RJMbwQir2mVKYYSA3wzmD7ZeXTUFUXt7VDo5xkErKe", "array_double_exponential_large.bin";
  "QmY5Rd9ovjc5NC5aZEQm6XMTsFPXuK5mcETQUtU3YT7vSv", "array_double_exponential_medium.bin";
  "QmayPLeexUXd5CDU1toFEKD3GEN2RarR8rM6SYqETtGW2E", "array_double_exponential_small.bin";
  "QmQAxEYwvdDeTtU6ReoGUSpJCgJ477WvCHs7YqayFKMjcm", "array_double_random_large.bin";
  "QmabSxwMqL98tMZeaqBRxGUxyMVEpnq8ez8VCxQEp2geNb", "array_double_random_medium.bin";
  "QmQoMHANBS4zEZZEDMmRcD8dkdtLmtuuaqCcBtmyfAEa9x", "array_double_random_small.bin";
  "QmVDwFLa3USQMSVv3nfUBwjbsfo1SmATw9okjJT5AWrb4n", "array_int_exponential_large.bin";
  "QmNyPhMzvF54BojTuGqrQEaJb9XSmc6bpq2TrtNa3wpr7u", "array_int_exponential_medium.bin";
  "QmX5xninsAtQkJSSWJFWNF9yqwmDhmF9oCxFDKsia3jcrf", "array_int_exponential_small.bin";
  "QmcZ42Suo1AynTmmB8zum8VJ3FNhb59gMi4VyA6tYWe6gE", "array_int_random_bounded_100000_large.bin";
  "QmZY811Agj461by2Y1dqPuRaW8FeCDpZ62SwpxJub99KcE", "array_int_random_bounded_100000_medium.bin";
  "QmZyk1owLgLBQNELsgN7c14rXqJzAyj1jyB2QjdtvFdpok", "array_int_random_bounded_100000_small.bin";
  "QmUhvPaavdgMWGzFTpXRMaDwdRzNSrVSbdLHpMZsMnkrwG", "array_int_random_large.bin";
  "QmT8c1EE9GPurEf1P3gHoBJParyK4dWs1nQ1E8r2BpXcXm", "array_int_random_medium.bin";
  "QmPYB5cBdVLq4t84jU1MYcM5rZD3vwtqGU2uxmndUE7Jmv", "array_int_random_small.bin";
  "QmaMkDBQhTywM1t1QwLwPPDE336fBBzSB7QLY4UYsjdUpV", "array_pair_int_int_random_100000000_large.bin";
  "QmbxJ3Xny3yK1N11oKutAVELsnMYpKfAT31eQ7J8Emujiq", "array_pair_int_int_random_10000000_medium.bin";
  "QmbRrXoVjvuNznQ2Y8GbyZXs6ALRhX6y7ErHiGn1YPqAJ7", "array_pair_int_int_random_1000000_small.bin";
  "QmZt4u8McsZFdkpg9jZnvD6bcRitoPCCXARXuKX1YA9efV", "array_pair_int_int_random_256_large.bin";
  "QmSV3ofTHXJsHwkKAHabexZUdBPEXbDq7qTqRpDfhCZXuM", "array_pair_int_int_random_256_medium.bin";
  "QmXxWH1qwYDuHNTyaTM1b65bzFruK6tc7edGYmHhfRtao9", "array_pair_int_int_random_256_small.bin";
  "QmbBqaM5SAuuhx7YAY1PeyH62GbbiHWfPxYMmmiQdw22Pg", "array_pair_string_int_trigrams_large.bin";
  "QmUvgq6Vo6Mvo3vgXvxzHY8BZQvLmH1hBxEXzT3ub6PZaE", "array_pair_string_int_trigrams_medium.bin";
  "QmPuJfUaeBWiwL71kw91fgNNFJx1wWfvfgR875sugdbd3e", "array_pair_string_int_trigrams_small.bin";
  "QmRbzUS4eaVyBrNMtSi2xk5bgu8Ka9xTcti1Xi2aVwz3oK", "array_point2d_in_circle_large.bin";
  "QmP5g6Qwxuw34paLrvctLYR4GWvntraTaFwfqhbF2rfLtC", "array_point2d_in_circle_medium.bin";
  "QmfWVA6G9HhfLSivV9nPF2kZLCqsW8hiViLkvaK7idjP1K", "array_point2d_in_circle_small.bin";
  "QmaA4Jq23PEPL3dyv7F6soNQR15PDW8NhFdDZRzmuJapzJ", "array_point2d_in_square_delaunay_large.bin";
  "QmaA4Jq23PEPL3dyv7F6soNQR15PDW8NhFdDZRzmuJapzJ", "array_point2d_in_square_delaunay_medium.bin";
  "QmPYZumkzCVUeATptYKMNv5qEFgRpTPGYtZ35xkhc7BpJX", "array_point2d_in_square_delaunay_small.bin";
  "QmNex8BfEQweJPeposH1NS8KkJ4UuKg17FvNvvmDN34oNn", "array_point2d_in_square_large.bin";
  "QmaA4Jq23PEPL3dyv7F6soNQR15PDW8NhFdDZRzmuJapzJ", "array_point2d_in_square_medium.bin";
  "QmPYZumkzCVUeATptYKMNv5qEFgRpTPGYtZ35xkhc7BpJX", "array_point2d_in_square_small.bin";
  "QmSLAWyJ3kmFBmXSV7HvyRfiLgwkwfQm1JKKSYUMpQzpTi", "array_point2d_kuzmin_delaunay_large.bin";
  "QmSLAWyJ3kmFBmXSV7HvyRfiLgwkwfQm1JKKSYUMpQzpTi", "array_point2d_kuzmin_delaunay_medium.bin";
  "QmXYtFbsG6KRXmAZyuFiPaUKAQE7EQKH4y8gVMZg1KCACF", "array_point2d_kuzmin_delaunay_small.bin";
  "QmZ9UTmjSmPcEFxmH441fqx6g1LLej4rpVWFYtKbzyZLq9", "array_point2d_kuzmin_large.bin";
  "QmSLAWyJ3kmFBmXSV7HvyRfiLgwkwfQm1JKKSYUMpQzpTi", "array_point2d_kuzmin_medium.bin";
  "QmXYtFbsG6KRXmAZyuFiPaUKAQE7EQKH4y8gVMZg1KCACF", "array_point2d_kuzmin_small.bin";
  "Qma1oD5ojjSMgLdywLPzLJ5cBV8esUhcACWmN5SyUr9hFT", "array_point2d_on_circle_large.bin";
  "Qmcz9JbR9piozbTwugioAymyb7w7HjybYrAhDss3n6QkMv", "array_point2d_on_circle_medium.bin";
  "QmXJ3qDNgaFW6S2pFz8Td2ETVjUtDe8aaxDGYfeT2aQSsA", "array_point2d_on_circle_small.bin";
  "QmZrL33umj2k31CpRW1yG2YkeWfQue5cEN8YvXQqLJzTBe", "array_point3d_in_cube_large.bin";
  "QmVZRcB1CxpmTYq5ChCkWjRNYQWotyNvhCEZvmjmq5bHQS", "array_point3d_in_cube_medium.bin";
  "QmZDDGg4ucoo8znhiewJQSdJvdhMbRtEF3wA17Racq6Xtn", "array_point3d_in_cube_small.bin";
  "QmRDNcgGWVZyeauDSd867CTXo8V9ZuEp7K8DuBpmJY5duF", "array_point3d_on_sphere_large.bin";
  "QmT183mJMpsrVvNY9r4Pdyn7vTJErXyizj9BLh4TKgq3bj", "array_point3d_on_sphere_medium.bin";
  "QmZbp3ZWuP1DuXBsUV6uR1WhNiBdr2xUPoxKYnJ3rfVWQT", "array_point3d_on_sphere_small.bin";
  "QmX6W5b8F5kae38Muy9yxaEfsiqb6gHhQgiQa1VgVt9jKQ", "array_point3d_plummer_large.bin";
  "QmVZsRyDFRNECsxbrogSUdX5VrQwXCj7AMZPzizwuW1x4f", "array_point3d_plummer_medium.bin";
  "Qmesw1McsjPdkENNYomTUsTbMrVKpF3NQec5tFtUBk6bvB", "array_point3d_plummer_small.bin";
  "QmX4wdLHgpoGv92SXerXkgLqjZVF4gZYcnjtAbS51T4unP", "array_string_trigrams_large.bin";
  "QmPeRz42Axz5V1Jzyutet3YoDMTNdAXQWtyWGDcU6rRs6J", "array_string_trigrams_medium.bin";
  "QmacvDqCeAdQ4bZemHnXsN8pAPUVkK3JMS2SND6zihajiN", "array_string_trigrams_small.bin";
  "Qma4z37vrhKTiAXBUnaUeJS9cfrD6bJ256yHuGsfft1M5m", "chain_large.bin";
  "QmUGQqKtivcCYEQxZdEow2GJT3CgfkiijgcLUxdUKeJSYt", "chain_small.bin";
  "QmXVka2FKr6vHS5h8sr2L6wPjyD72EsQDbBDFghLn7sj9M", "chr22.dna.bin";
  "QmcACNqugJsNXrHK3wrsGedEV44tHEtdZXEn3zY1Eo9Qdj", "cube_large.bin";
  "QmfYtSDcXygyErVG5YfM4vXzLfAtr2k3BF9L7D1zbBFcgu", "cube_medium.bin";
  "QmPDhVjgQQG7FJExGPyRdSmRPhbcdT1TyVzvXgedBWnKjX", "cube_small.bin";
  "QmbpWbvT1zPXtwBCgxh7d6SdLV9YFeo9KTNNUqdSFyNfZR", "delaunay.bin";
  "QmcnrU8LhBg8P3uGBv5DzG1SWkQwihnMB7dDTHs6p419AE", "dragon_ray_cast_dataset.bin";
  "QmfX2ZG8TqqzDjYMUWXFKQujzXhcc4hzQZqmuTaHF9eT8t", "etext99.bin";
  "QmbEJ3QpiVQDWBwrnLCFBhkNQMcRJSKrs8TaguCnYUCR4r", "europe.bin";
  "QmaroxYoU5sJBVuhmZ51UttBfJpLuZ7yUDpXqNapfoUSkd", "grid_sq_large.bin";
  "QmRDaaCrsRji15z2f7PhJTJpvS78L7MEtSuAnhtk5aMxHm", "happy_ray_cast_dataset.bin";
  "QmRDaaCrsRji15z2f7PhJTJpvS78L7MEtSuAnhtk5aMxHm", "happy_ray_cast_dataset_save.bin";
  "QmXDu8XKrokoeGZg3wkL7r6zLMNyaiaHhS1cC3Fjjwkqoi", "incube_ray_cast_1m.bin";
  "QmQmp6usmpequDCg1Q1RBLNRUipJjoY5be9AZpa8e9YRdj", "incube_ray_cast_2m.bin";
  "QmcWMCqSZRu7Sg8mU8qsSMQNVq2ZEQLZukg1rpRRNVLxwS", "incube_ray_cast_5m.bin";
  "Qmeh5UKMjQwRvCqdYo92GVpSXe7FY1XkCieUQZj9K3C4bw", "incube_ray_cast_5m.txt";
  "QmR2FHtjt2kyYp1fUg6UbcjkFCXCNfqRwjt5evCUjPuMzo", "livejournal.bin";
  "QmQ5Hg634fcLcGnbzbEDBbSb89TByhpRDr65LK1V4T45Ee", "loop_1010_10.bin";
  "QmWFRhiofLxKpeoKwerFFuKtYLQnNE2g5ybEcbPnrjh89x", "loop_1010_1000.bin";
  "Qma8Wb4hq3EnzbeAJoNMs9JHpznxRbNBDjScLfdRZqDKsX", "loop_1010_100000.bin";
  "QmTswjsAsBmqPCubzNU2hBw5tC2JRDg8q11SDC9b3XCF4k", "loop_1010_1000000000.bin";
  "QmUzeR8yJbC6RrdKoyvnsaL49xVMXm51ZZrsnmMUAr8yqv", "loop_1010_33222591.bin";
  "QmethjsWxJC2aMvhavjgjmoivVm79v18jWkF1B11sceUJY", "loop_109_10.bin";
  "QmW1CT3D88B4uHkafKYPengNK93fa9xPUv7oMiVdqfGsd1", "loop_109_1000.bin";
  "QmcdfVa8YZQeqvYHxqrbCeypVYmQ73cEgyPpm9iTaPzWTD", "loop_109_100000000.bin";
  "QmYuxJVfgdG4cQqWBmXneanwj2WPMQTTDzZKcheAESNhwp", "loop_109_30000.bin";
  "Qmf4ds7ZRFhz3JrpvyM78rzqiAYJh9ecZ1v2rYs8v3GNVC", "loop_109_3000000.bin";
  "QmZkqdPc7qVVY3wZgYfA8XgSSjfHkL5xNhpA3Xd7gpkFBX", "mat27_large.bin";
  "QmZvyM8j6xRBZbwtKdzWYpR634QYkBnsQ8HsDK5Y5EHY4n", "mat27_medium.bin";
  "QmTtq7Fo2k8NNHSgYxLRtgzcNMnz5wgg8krFxWRLyHUTFG", "onsphere_ray_cast_1m.bin";
  "QmZYkpXs6eCwje6aDxn7d3K1DD13WaLggqWqCQDuNtQXkR", "onsphere_ray_cast_2m.bin";
  "QmQaJeP94yqZsQjLPgTJhNG4gNqprg3ZFNmYqpzFnqHfau", "onsphere_ray_cast_5m.bin";
  "QmdD3uK6hUfnK7W2pMpfFjgLfbJJYK6a95pXSe8ouyXVFb", "paths_100_phases_1_large.bin";
  "QmQYruSfm28CETx1WC2KX8gK2arFUrgkwaNrxHGFGQnwYD", "phased_524288_single_large.bin";
  "QmZnCAWbXDK9bsJN6Vgsad55kms8RGgH652Zg2mv64gV3J", "phased_low_50_large.bin";
  "QmUkCiAYaj3tufQ3B3WDPNYFrc77m7uMPaTUue9z3RrGL7", "phased_mix_10_large.bin";
  "QmfETQkR9PU2mwdFqis4qHHqfkb5AGjZjATK2TP5qyzncU", "rMatGraph_J_5_10000000.bin";
  "QmZX9N8iG4NXDAsBCSHhKtsBAonrisHsmPxnGX6Jkwp2B2", "randLocalGraph_J_5_10000000.bin";
  "QmNNunrwrWf1Ebz4xDAriQkNKpgmQbGXX1d2GG9vLX2neE", "random_arity_100_large.bin";
  "Qme1WH2x4qWzk7P2ojxpawnyAS15993M8jdh9YMrDSnxha", "refine_triangles_point2d_delaunay_in_square_large.bin";
  "QmckMba6Jkv7WjoULkweqhR4KQxMGatpsuYM5rg6vVU8js", "refinetriangles_point2d_delaunay_kuzmin_large.bin";
  "QmYGqukAsFSQxe8FEff9h65nGhCH23uSWwJKpH7YkCAijk", "rgg.bin";
  "QmQvdBNowHoHCn5LXRtxLs3aaEs8GLuz9yZk3HzF6jBA6x", "rmat24_large.bin";
  "QmUmE6UvxnxwNYAB1sgRx8RtRAzMYpBkbfagxomoJtNHZy", "rmat24_medium.bin";
  "QmesvvU9bKJkHpKx93F47PLvuVGnjs7M9mqj6sW3ZKsJB2", "rmat24_small.bin";
  "QmZv6vkPYwdoHimpDXBB9WrhomiyQ8asq1FyPKnwyzX53A", "rmat27_large.bin";
  "QmPNPzj9jTifjUntnLi71LoPCfmPWMWgZwJg6rgW8fLutX", "rmat27_medium.bin";
  "Qmdn85duXK1GsiQMRjQcdCaDopNqvLkitnY3T9abrkFNzE", "rmat27_small.bin";
  "QmUgS3XGE1C6AQJry1Vemxidocx7Bbc91sAsXygFneb4qN", "string_trigrams_large.bin";
  "QmPS8uF32prKEfc8hSUupnvj37fEiVTPqjzzwSZkeu3ny7", "string_trigrams_medium.bin";
  "QmVHyrpKstu7TWuYipftYrCCjExUJWncc6Gn9vHGKKN3iv", "string_trigrams_small.bin";
  "QmbNCimmwsy65Bg9ppFZyx5aDgCRiRNPJXMHhtHPypdetq", "tree_2_512_1024_large.bin";
  "QmX7h4VrE72Vb73dgHreaP2LFEbQxcXtxqovoL7WaJi6TG", "triangles_point2d_delaunay_in_square_medium.bin";
  "Qme1WH2x4qWzk7P2ojxpawnyAS15993M8jdh9YMrDSnxha", "triangles_point2d_delaunay_in_square_refine_large.bin";
  "Qme1WH2x4qWzk7P2ojxpawnyAS15993M8jdh9YMrDSnxha", "triangles_point2d_delaunay_in_square_small.bin";
  "QmUGcvjmXYyCxjhydHQzDc8uu6X5X4Uqjdvs4QFjfeMFMi", "triangles_point2d_delaunay_kuzmin_medium.bin";
  "QmckMba6Jkv7WjoULkweqhR4KQxMGatpsuYM5rg6vVU8js", "triangles_point2d_delaunay_kuzmin_refine_large.bin";
  "QmckMba6Jkv7WjoULkweqhR4KQxMGatpsuYM5rg6vVU8js", "triangles_point2d_delaunay_kuzmin_small.bin";
  "QmaRTv7FZdAi63nDKDxUV6goQLxRdpsM2H9dDkERPoAxfH", "turbine_ray_cast_dataset.bin";
  "QmcuLdFKKydtFvJWugg4v8AVBwsMcCMrSm5zKUjeWLcEaf", "twitter.bin";
  "QmRaZvZkbYkj67DEh5iXUQft3TX2RFy4G4GgD8VCqFG4cF", "unbalanced_tree_trunk_first_large.bin";
  "QmPfv38PWzfD9NKPsmTGRns8cQsYUgu3yTor4xeSbi4Vgt", "usa.bin";
  "Qmepjnfng9sMYbGrZt63MRZcS7g2WdB5D9pwhRdDK83etJ", "wikipedia-20070206.bin";
  "QmfYr68dj2CPKvf7Rg44Ae1yKXpUVTgyv2MJb3yhsX3UE2", "wikisamp.xml.bin";
  "QmWNiBmwPn7herCEjnc8b7iz6GZRneYGuoQWmsZEH4jU4Z", "xyzrgb_dragon_ray_cast_dataset.bin";
  "QmT76cbeEP64rS617yXpXr3efaAtBXa8mUZ4PTBVNuUYMd", "xyzrgb_manuscript_ray_cast_dataset.bin";
]
                    
let ipfs_get hash outfile is_virtual =
  system (sprintf "ipget -o %s %s" outfile hash) is_virtual

let ipfs_get_if_needed hash outfile force_get is_virtual =
  if force_get || not (Sys.file_exists outfile) then
    ipfs_get hash outfile is_virtual
  else
    ()

let ipfs_get_files table force_get is_virtual =
  List.iter (fun (h, p) -> ipfs_get_if_needed h p force_get is_virtual) table

(*****************************************************************************)
(** A benchmark to find a good setting for kappa *)

module ExpFindKappa = struct

let name = "find-kappa"

let prog = "spawnbench.sptl"

let prog_elision = "spawnbench.sptl_elision"

let kappas =
  generate_in_range_by_incr 0.2 40.0 2.0

let mk_kappa =
  mk float "sptl_kappa"
    
let mk_kappas = fun e ->
  let f kappa =
    Env.add Env.empty mk (float kappa)
  in
  List.map f kappas
    
let mk_alpha =
  mk float "sptl_alpha" 1.3

let mk_custom_kappa =
  mk int "sptl_custom_kappa" 1

let mk_configs =
  mk_custom_kappa & (mk_list float "sptl_kappa" kappas) & mk_alpha

let make() =
  build "." [prog; prog_elision;] arg_virtual_build

let nb_runs = 10
    
let run_modes =
  Mk_runs.([
    Mode arg_mode;
    Virtual arg_virtual_run;
    Runs nb_runs; ])
    
let run() = (
  Mk_runs.(call (run_modes @ [
    Output (file_results prog);
    Timeout 400;
    Args (
      mk_prog prog
    & mk_configs)]));
  Mk_runs.(call (run_modes @ [
    Output (file_results prog_elision);
    Timeout 400;
    Args (
      mk_prog prog_elision)])))

let check = nothing  (* do something here *)

let spawnbench_formatter =
 Env.format (Env.(
   [ ("n", Format_custom (fun n -> sprintf "spawnbench(%s)" n)); ]
  ))

let plot() =
  let results_all = Results.from_file (file_results prog) in
  let env = Env.empty in
  let kappa_exectime_pairs = ~~ List.map kappas (fun kappa ->
    let [col] = ((mk_prog prog) & mk_custom_kappa & (mk_kappa kappa) & mk_alpha) env in
    let results = Results.filter col results_all in
    let e = Results.get_mean_of "exectime" results in
    (kappa, e))
  in
  let elision_exectime =
    let results_all = Results.from_file (file_results prog_elision) in
    let [col] = (mk_prog prog_elision) env in
    let results = Results.filter col results_all in
    Results.get_mean_of "exectime" results
  in
  let rec find kes =
    match kes with
      [] ->
        let (kappa, _) = List.hd (List.rev kappa_exectime_pairs) in
        kappa
    | (kappa, exectime) :: kes ->
        if exectime < elision_exectime +. 0.05 *. elision_exectime then
          kappa
        else
          find kes
  in
  let kappa = find kappa_exectime_pairs in
  let oc = open_out "kappa" in
  let _ = Printf.fprintf oc "%f\n" kappa in
  close_out oc

let all () = select (fun _ -> ()) make run check plot

end

(*****************************************************************************)
(** A benchmark to find a good setting for alpha *)

module ExpFindAlpha = struct

let name = "find-alpha"

let prog = "spawnbench.sptl"

let alphas =
  generate_in_range_by_incr 1.0 3.0 0.4
    
let mk_alphas =
  mk_list float "sptl_alpha" alphas

let arg_kappa =
  if Sys.file_exists "kappa" then
   let ic = open_in "kappa" in
   try
     let line = input_line ic in
     close_in ic;
     float_of_string line
   with e ->
     close_in_noerr ic;
     20.0
  else
    20.0

let mk_kappa =
  mk float "sptl_kappa" arg_kappa

let mk_custom_kappa =
  ExpFindKappa.mk_custom_kappa

let mk_proc =
  mk int "proc" (List.hd arg_proc)
    
let mk_configs =
  mk_custom_kappa & mk_kappa & mk_alphas & mk_proc & (mk int "n" 1000000000)

let make() =
  build "." [prog] arg_virtual_build

let nb_runs = 10
    
let run_modes =
  Mk_runs.([
    Mode arg_mode;
    Virtual arg_virtual_run;
    Runs nb_runs; ])
    
let run() =
  Mk_runs.(call (ExpFindKappa.run_modes @ [
    Output (file_results name);
    Timeout 400;
    Args (
      mk_prog prog
    & mk_configs)]))

let check = nothing  (* do something here *)

let spawnbench_formatter =
 Env.format (Env.(
   [ ("n", Format_custom (fun n -> sprintf "spawnbench(%s)" n)); ]
  ))

let plot() =
  let results_all = Results.from_file (file_results name) in
  let env = Env.empty in
  let alpha_exectime_pairs = ~~ List.map alphas (fun alpha ->
    let [col] = ((mk_prog prog) & (mk float "sptl_alpha" alpha)) env in
    let results = Results.filter col results_all in
    let e = Results.get_mean_of "exectime" results in
    (alpha, e))
  in
  let rec find aes (min_alpha, min_exectime) =
    match aes with
      [] ->
        min_alpha
    | (alpha, exectime) :: aes ->
        if exectime < min_exectime then
          find aes (alpha, exectime)
        else
          find aes (min_alpha, min_exectime)
  in
  let alpha = find alpha_exectime_pairs (1.3, max_float) in
  let oc = open_out "alpha" in
  let _ = Printf.fprintf oc "%f\n" alpha in
  close_out oc

let all () = select (fun _ -> ()) make run check plot

end

(*****************************************************************************)
(** BFS benchmark *)

module ExpBFS = struct

let name = "bfs"

let results_file = "_results/results_bfs.txt" 
                   
let graphfile_of n = arg_path_to_data ^ "/" ^ n ^ ".bin"

let graphfiles' =
  let manual = 
    [
      "livejournal", 0;
      "twitter", 1;
      (*        "usa", 1;*)
    ]
  in
  let other =
    [
      "wikipedia-20070206"; (*"rgg";*) (*"delaunay";*) "europe"; 
      "random_arity_100_large"; "rmat27_large"; 
      "rmat24_large";  "cube_large"; "grid_sq_large";
      "paths_100_phases_1_large"; "unbalanced_tree_trunk_first_large";
      "phased_mix_10_large"; (*"tree_2_512_1024_large";*) "phased_low_50_large";
      "phased_524288_single_large"; 
    ]
  in
  List.concat [manual; List.map (fun n -> (n, 0)) other]

let mk_proc = mk int "proc" (List.hd (List.rev arg_proc))
    
let user_graph_argument = XCmd.parse_optional_list_string "graph"

let graphfiles' = match user_graph_argument with
  | None -> graphfiles'
  | Some s -> List.map (fun s -> (s, List.assoc s graphfiles')) s
              
let graphfiles = List.map (fun (n, _) -> n) graphfiles'

let graph_renaming =
  [
   "grid_sq_large", "square-grid";
   "wikipedia-20070206", "wikipedia";
   "paths_100_phases_1_large", "par-chains-100";
   "phased_524288_single_large", "trees-524k";
   "phased_low_50_large", "phases-50-d-5";
   "phased_mix_10_large", "phases-10-d-2";
   "random_arity_100_large", "rand-arity-100";
   "tree_2_512_1024_large", "trees-512-1024";
   "unbalanced_tree_trunk_first_large", "trunk-first";
   "randLocalGraph_J_5_10000000", "random";
   "rMatGraph_J_5_10000000", "rMat";
   "cube_large", "cube-grid";
   "rmat24_large", "rmat24";
   "rmat27_large", "rmat27";
 ]

let pretty_graph_name n =
  if List.mem_assoc n graph_renaming then
    List.assoc n graph_renaming
  else
    n

let extensions = XCmd.parse_or_default_list_string "exts" [ "sptl"; ]

let arg_inner_loop = XCmd.parse_or_default_list_string "inner_loop" ["bfs";"pbfs"]

let prog benchmark extension =
  sprintf "%s.%s" benchmark extension

let baseline_progs = List.map (fun inner_loop -> prog inner_loop "sptl") arg_inner_loop

let oracle_progs = List.flatten 
  (List.map (fun extension -> List.map (fun inner_loop -> prog inner_loop extension) arg_inner_loop) extensions)

let all_progs = List.append baseline_progs oracle_progs                       

let make() =
  build "." all_progs arg_virtual_build

let mk_lib_type t =
  mk string "library" t

let mk_infile n =
  mk string "infile" n

let mk_infile' n =
  let (_, source) = List.find (fun (m, _) -> m = n) graphfiles' in
  mk string "infile" (graphfile_of n) & mk int "source" source

let mk_graphname n =
  mk string "graph_name" n

let mk_input n =
  (mk_infile' n & mk_graphname n)

let rec mk_infiles ns =
  match ns with
  | [] ->
      failwith ""
  | [n] ->
      mk_input n
  | n :: ns ->
      mk_input n ++ mk_infiles ns

let prog_assoc = List.flatten (List.map (fun (p:string) -> 
                               List.map (fun (e:string) -> (p, e)) extensions) arg_inner_loop)

let prog_of (p, e) = sprintf "%s_bench.%s" p e

let mk_bfs_prog inner_loop extension lib_type =
  (mk string "prog" (prog inner_loop extension)) & (mk_lib_type lib_type)

let mk_progs =
  ((mk_list string "prog" oracle_progs)  & (mk_lib_type "sptl")) ++
    ((mk_list string "prog" baseline_progs)  & (mk_lib_type "pbbs"))

let run() =
  Mk_runs.(call (par_run_modes @ [
                    Output results_file;
                    Timeout 400;
                    Args (mk_progs & (mk string "type" "graph") & (mk_infiles graphfiles) & mk_proc);                           
                  ]))

let check = nothing  (* do something here *)

let main_formatter =
  Env.format (Env.(
              [
               ("proc", Format_custom (fun n -> ""));
               ("lib_type", Format_custom (fun n -> ""));
               ("infile", Format_custom (fun n -> ""));
               ("graph_name", Format_custom pretty_graph_name);
               ("prog", Format_custom (fun n ->  ""
(*                                           let ps = List.map2 (fun x y -> (x, y)) oracle_progs prog_assoc in
                                         if List.mem_assoc n ps then
                                           let (p, e) = List.assoc n ps in
                                           let commonext = "unks" in
                                           let extlength = String.length commonext in
                                           let kappa = String.sub e extlength (String.length e - extlength) in
                                           let nghl = if p = "bfs" then "Seq. ngh. list" else "Par. ngh. list" in
                                           sprintf "Oracle guided, kappa := %sus (%s)" kappa nghl
                                         else "<bogus>" *)
                                      ));    
               ("type", Format_custom (fun n -> ""));
               ("source", Format_custom (fun n -> ""));
             ]
               ))

let eval_relative_main = fun env all_results results ->
  let pbbs_results = ~~ Results.filter_by_params all_results (
                          from_env (Env.add (Env.filter_keys ["type"; "infile"; "proc"] env) "library" (Env.Vstring "pbbs"))) in
  if pbbs_results = [] then Pbench.error ("no results for pbbs library");
  let v = Results.get_mean_of "exectime" results in
  let b = Results.get_mean_of "exectime" pbbs_results in
  (b, v)

let plot() =
  let nb_inner_loop = List.length arg_inner_loop in
  let tex_file = file_tables_src name in
  let pdf_file = file_tables name in
  Mk_table.build_table tex_file pdf_file (fun add ->
(*    let l = "S[table-format=2.2]" in*) (* later: use *)
    let ls = "c|d{3.2}|d{3.2}|d{3.2}|c|d{3.2}|d{3.2}|d{3.2}|@{}d{3.2}@{}" in
    let hdr = Printf.sprintf "@{}l@{\,}|%s@{}" ls in
    add (Latex.tabular_begin hdr);                                    
    let _ = Mk_table.cell ~escape:false ~last:false add "" in
    ~~ List.iteri arg_inner_loop (fun i inner_loop ->
          let last = false (* i + 1 = nb_inner_loop*) in
          let n = "{" ^ (if inner_loop = "bfs" then "Flat" else "Nested") ^ "}" in
          let l = if last then "c" else "c|" in
          let label = Latex.tabular_multicol 4 l n in
          Mk_table.cell ~escape:false ~last:last add label);
    let label = Latex.tabular_multicol 1 "c" "Ours nested" in 
    Mk_table.cell ~escape:false ~last:true add label;
    add "\\\\ \cline{1-9}";
    let _ = Mk_table.cell ~escape:false ~last:false add "Graph" in
    for i=1 to nb_inner_loop do (
      let l = "\multicolumn{1}{@{\,}l@{\,}|}{{\\begin{tabular}[x]{@{}c@{}}PBBS\\end{tabular}}}" in
      Mk_table.cell ~escape:false ~last:false add l;
      Mk_table.cell ~escape:false ~last:false add "\multicolumn{1}{l|}{Ours}";
      Mk_table.cell ~escape:false ~last:false add "\multicolumn{2}{c|}{Oracle / PBBS}")
    done;
    Mk_table.cell ~escape:false ~last:true add "\multicolumn{1}{@{}c@{}}{{\\begin{tabular}[x]{@{}c@{}}vs. \\\\PBBS flat\\end{tabular}}}";
    add Latex.tabular_newline;

    let _ = Mk_table.cell ~escape:false ~last:false add "" in
    for i=1 to nb_inner_loop do (
      Mk_table.cell ~escape:false ~last:false add "(sec.)";
      Mk_table.cell ~escape:false ~last:false add "\multicolumn{1}{l|}{}";
      Mk_table.cell ~escape:false ~last:false add "\multicolumn{1}{l|}{Idle time}";
      Mk_table.cell ~escape:false ~last:false add "\multicolumn{1}{l|}{Nb threads}")
    done;
    Mk_table.cell ~escape:false ~last:true add "";
    add Latex.tabular_newline;

        let all_results = Results.from_file results_file in
        let results = all_results in
        let env = Env.empty in
        let env_rows = mk_infiles graphfiles env in
        ~~ List.iter env_rows (fun env_rows ->  (* loop over each input for current benchmark *)
          let results = Results.filter env_rows results in
          let env = Env.append env env_rows in
          let row_title = main_formatter env_rows in
          let _ = Mk_table.cell ~escape:false ~last:false add row_title in
          let exectime_bfs_sptl = ref 0.0 in
          let exectime_pbfs_sptl = ref 0.0 in
          let exectime_bfs_pbbs = ref 0.0 in
          let exectime_pbfs_pbbs = ref 0.0 in
          ~~ List.iteri arg_inner_loop (fun inner_loop_i inner_loop ->
            let (pbbs_str, b, pbbs_idle_time, pbbs_nb_threads) =
              let [col] = (mk_bfs_prog inner_loop "sptl" "pbbs") env in
              let env = Env.append env col in
              let results = Results.filter col results in
              let b = eval_exectime env all_results results in
              let _ = if inner_loop = "bfs" then (exectime_bfs_pbbs := b) else (exectime_pbfs_pbbs := b) in
              let e = eval_exectime_stddev env all_results results in
              let err = if arg_print_err then Printf.sprintf "(%.2f%s)" e "$\\sigma$" else "" in
              let str = Printf.sprintf (if b < 10. then "%.2f" else "%.1f") b in
	      let util = Results.get_mean_of "utilization" results in
	      let idle_time = util *. b in
	      let nb_threads = Results.get_mean_of "nb_threads_alloc" results in
	      let nb_threads = if nb_threads = 0. then 1. else nb_threads in
              (str ^ " " ^ err, b, idle_time, nb_threads)
            in
            let _ = Mk_table.cell ~escape:false ~last:false add pbbs_str in
              let (sptl_str, grade_str, sptl_idle_time, sptl_nb_threads) = 
                let [col] = (mk_bfs_prog inner_loop "sptl" "sptl") env in
                let env = Env.append env col in
                let results = Results.filter col results in
                let (_,v) = eval_relative_main env all_results results in
                let _ = if inner_loop = "bfs" then (exectime_bfs_sptl := v) else (exectime_pbfs_sptl := v) in
                let vs = string_of_percentage_change b v in
                let e = eval_exectime_stddev env all_results results in
                let err = if arg_print_err then Printf.sprintf "(%.2f%s)" e "$\\sigma$" else "" in
                let grade =
                  let delta = v -. b in
                  let grade = delta /. e in
                  if (abs_float grade) < 0.51 then
                    Printf.sprintf "$\\approx$"
                  else if grade < 0.0 then
                    Printf.sprintf "$\\checkmark^{%.0f}$" (abs_float grade)
                  else
                    Printf.sprintf "$\\times^{%.0f}$" grade
                in
		let util = Results.get_mean_of "utilization" results in
		let idle_time = util *. b in
		let nb_threads = Results.get_mean_of "nb_threads_alloc" results in
		let nb_threads = if nb_threads = 0. then 1. else nb_threads in
                (Printf.sprintf "%s %s" vs err, grade, idle_time, nb_threads)
              in
              Mk_table.cell ~escape:false add sptl_str;
              Mk_table.cell ~escape:false add (string_of_percentage_change pbbs_idle_time sptl_idle_time);
	      Mk_table.cell ~escape:false add (string_of_percentage_change pbbs_nb_threads sptl_nb_threads);
            ());
          let str_diff_sptl = string_of_percentage_change (!exectime_bfs_pbbs) (!exectime_pbfs_sptl) in
          Mk_table.cell ~escape:false ~last:true add str_diff_sptl;
          add Latex.tabular_newline);
        add Latex.tabular_end;
        add Latex.new_page;
        ());

  ()

let row_of_infile path_to_infile infile =
  let h, _ = List.find (fun (_, f) -> f = (infile ^ ".bin")) infiles_by_hash in
  (h, graphfile_of infile)
  
let all () =
  let get _ =
    let _ = system (Printf.sprintf "mkdir -p %s" arg_path_to_data) arg_virtual_get in
    let table = List.map (row_of_infile graphfile_of) graphfiles in
    ipfs_get_files table arg_force_get arg_virtual_get
  in
  select get make run check plot

end

(*****************************************************************************)
(** Comparison benchmark *)

module ExpCompare = struct

let name = "compare"

let all_benchmarks =
  match arg_benchmarks with
  | ["all"] -> [
    "convexhull"; "samplesort"; "radixsort"; "nearestneighbors";
    "suffixarray";
    "delaunay"; (*"bfs";*) (*"refine"; *) "raycast"; (*"pbfs";*)
    ]
  | ["deterministic-reservations"] -> [
      (*"mis";*) "mst"; (*"matching";*) "spanning";
    ]
  | _ -> arg_benchmarks
    
let sptl_prog_of n = n ^ ".sptl"
let sptl_elision_prog_of n = n ^ ".sptl_elision"
let sptl_nograin_prog_of n = n ^ ".sptl_nograin"
                             
let sptl_progs = List.map sptl_prog_of all_benchmarks
let sptl_elision_progs = List.map sptl_elision_prog_of all_benchmarks
let sptl_nograin_progs = List.map sptl_nograin_prog_of all_benchmarks
let all_progs = List.concat [sptl_progs; sptl_elision_progs; sptl_nograin_progs;]

let path_to_infile n = arg_path_to_data ^ "/" ^ n

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
  "array_point2d_on_circle_large.bin", string  "2d", "on circle";
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
    (mk string "prog" (sptl_prog_of n))
  & mk_pbbs_lib

let mk_single_proc = mk int "proc" 1

let mk_multi_proc = mk_list int "proc" multi_proc

let mk_sptl_elision_prog n =
    (mk string "prog" (sptl_elision_prog_of n))
  & mk_sptl_lib
    
let mk_pbbs_elision_prog n =
    (mk string "prog" (sptl_elision_prog_of n))
  & mk_pbbs_lib

let mk_pbbs_nograin_prog n =
    (mk string "prog" (sptl_nograin_prog_of n))
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
(*  "array_pair_int_int_random_100000000_large.bin", string "pair_int_int", "random pair 10m";*)
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
  "rmat27_large.bin", int 0, "rMat27";
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
  "array_point3d_on_sphere_medium.bin", string "array_point3d", "on sphere";
  "array_point3d_plummer_medium.bin", string "array_point3d", "plummer"; 
(*  "array_point2d_in_square_medium.bin", string "array_point2d", "in square";*)
  "array_point3d_in_cube_medium.bin", string "array_point3d", "in cube"; 
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
(*  "turbine_ray_cast_dataset.bin", string "raycast", "turbine";*)
  "happy_ray_cast_dataset.bin", string "raycast", "happy";
  "xyzrgb_manuscript_ray_cast_dataset.bin", string "raycast", "xyzrgb";
]

let mk_raycast_infiles = mk_infiles "type" input_descriptor_raycast    

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

let infile_of_input_descriptor (p, _, _) = p
                                         
let row_of_infile path_to_infile infile =
  let h, _ = List.find (fun (_, f) -> (path_to_infile f) = infile) infiles_by_hash in
  (h, infile)
                                         
let fetch_infiles_of path_to_infile force_get is_virtual descrs =
  let infiles = List.map infile_of_input_descriptor descrs in
  let table = List.map (row_of_infile path_to_infile) infiles in
  ipfs_get_files table force_get is_virtual
                                            
let fetch_infiles_of_benchmark path_to_infile force_get is_virtual (benchmark : benchmark_descriptor) =
  fetch_infiles_of path_to_infile force_get is_virtual benchmark.bd_input_descr

let fetch_infiles_of_benchmarks path_to_infile force_get is_virtual all_benchmarks benchmarks =
  let keep_benchmark (benchmark : benchmark_descriptor) = List.exists (fun n -> n = benchmark.bd_name) benchmarks in
  let selected_benchmarks = List.filter keep_benchmark all_benchmarks in
  List.iter (fetch_infiles_of_benchmark path_to_infile force_get is_virtual) selected_benchmarks
                                            
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

let file_results_sptl_elision exp_name =
  file_results (exp_name ^ "_elision")

let file_results_pbbs_elision exp_name =
  file_results (exp_name ^ "_cilk_elision")

let file_results_pbbs_nograin exp_name =
  file_results (exp_name ^ "_cilk_nograin")

let file_results_sptl_single_proc exp_name =
  file_results (exp_name ^ "_sptl_single_proc")

let file_results_pbbs_single_proc exp_name =
  file_results (exp_name ^ "_pbbs_single_proc")

let nb_proc = List.length arg_proc
let nb_multi_proc = List.length multi_proc
        
let run() =
  List.iter (fun benchmark ->
    let rpar mk_progs file_results = 
      Mk_runs.(call (par_run_modes @ [
        Output file_results;
        Timeout 400;
        Args (mk_progs & benchmark.bd_infiles); ]))
    in
    let rseq mk_progs file_results = 
      Mk_runs.(call (seq_run_modes @ [
        Output file_results;
        Timeout 900;
        Args (mk_progs & benchmark.bd_infiles); ]))
    in    
    let sptl_prog = mk_sptl_prog benchmark.bd_name in
    let sptl_elision_prog = mk_sptl_elision_prog benchmark.bd_name in
    let pbbs_prog = mk_pbbs_prog benchmark.bd_name in
    let pbbs_elision_prog = mk_pbbs_elision_prog benchmark.bd_name in
    let pbbs_nograin_prog = mk_pbbs_nograin_prog benchmark.bd_name in
    (if nb_multi_proc > 0 then (
      rpar ((sptl_prog ++ pbbs_prog ++ pbbs_nograin_prog) & mk_multi_proc) (file_results benchmark.bd_name))
     else
       ());
    (if List.exists (fun p -> p = 1) arg_proc then (
      rseq (sptl_prog & mk_single_proc) (file_results_sptl_single_proc benchmark.bd_name);
      rseq (pbbs_prog & mk_single_proc) (file_results_pbbs_single_proc benchmark.bd_name);
      rseq (sptl_elision_prog & mk_single_proc) (file_results_sptl_elision benchmark.bd_name);
      rseq (pbbs_elision_prog & mk_single_proc) (file_results_pbbs_elision benchmark.bd_name);
      rseq (pbbs_nograin_prog & mk_single_proc) (file_results_pbbs_nograin benchmark.bd_name))
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
    let nb_multi_core_cols = 4 in
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
	      Mk_table.cell ~escape:false ~last:last add (Latex.tabular_multicol 2 "|c|" "Oracle / PBBS"));
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
	      Mk_table.cell ~escape:false ~last:false add "Idle time";
	      Mk_table.cell ~escape:false ~last:last add "Nb threads");
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
            let [col] = (mk_sptl_elision_prog benchmark.bd_name & mk_single_proc) env in
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
	    let (pbbs_sec, pbbs_utilization, pbbs_idle_time, pbbs_multi_proc_nb_threads) =
        let [col] = ((mk_pbbs_prog benchmark.bd_name) & mk_procs) env in
        let env = Env.append env col in
        let results = Results.filter col results in
        let sec = eval_exectime env all_results results in
	      let util = Results.get_mean_of "utilization" results in
	      let idle_time = util *. sec in
	      let nb_threads = Results.get_mean_of "nb_threads_alloc" results in
	      let nb_threads = if nb_threads = 0. then 1. else nb_threads
	      in
  	    (sec, util, idle_time, nb_threads)
      in
	    let (sptl_sec, sptl_utilization, sptl_idle_time, sptl_multi_proc_nb_threads) =
        let [col] = ((mk_sptl_prog benchmark.bd_name) & mk_procs) env in
        let env = Env.append env col in
        let results = Results.filter col results in
        let sec = eval_exectime env all_results results in
	      let util = Results.get_mean_of "utilization" results in
	      let idle_time = util *. sec in
	      let nb_threads = Results.get_mean_of "nb_threads_alloc" results in
	      let nb_threads = if nb_threads = 0. then 1. else nb_threads
	      in
  	    (sec, util, idle_time, nb_threads)
      in
	    let sptl_rel_pbbs = string_of_percentage_change pbbs_sec sptl_sec in
      let idle_time_str = string_of_percentage_change pbbs_idle_time sptl_idle_time in
	    let nb_threads_enc_by_pbbs_str = string_of_percentage_change pbbs_multi_proc_nb_threads sptl_multi_proc_nb_threads in
	    Mk_table.cell ~escape:false ~last:false add (Printf.sprintf "%.3f" pbbs_sec);
	    Mk_table.cell ~escape:false ~last:false add sptl_rel_pbbs;
	    Mk_table.cell ~escape:false ~last:false add idle_time_str;
	    Mk_table.cell ~escape:false ~last:last add nb_threads_enc_by_pbbs_str);
    add Latex.tabular_newline);
  );
  add Latex.tabular_end;
  add Latex.new_page;
  ())

let all () =
  let get _ = (
      system (Printf.sprintf "mkdir -p %s" arg_path_to_data) arg_virtual_get;
      fetch_infiles_of_benchmarks path_to_infile arg_force_get arg_virtual_get benchmarks all_benchmarks)
  in
  select get make run check plot

end
    
(*****************************************************************************)
(** Main *)

let _ =
  let arg_actions = XCmd.get_others() in
  let bindings = [
    "find-kappa",                  ExpFindKappa.all;
    "find-alpha",                  ExpFindAlpha.all;    
    "bfs",                         ExpBFS.all;
    "compare",                     ExpCompare.all;
  ]
  in
  Pbench.execute_from_only_skip arg_actions [] bindings;
  ()

open Cow
open Cow.Html

exception Unknown_repository of string

type repository_source = Cwd | Path of string | Opam of string

(* Flag to check if at least one operation is triggered by arguments *)
let no_operation = ref true

(* Options *)
type options = {
  mutable out_dir: string;
}

let user_options: options = {
  out_dir = "www";
}

let set_out_dir (dir: string) =
  user_options.out_dir <- dir

(* Generate a whole static website using the given repository *)
let make_website (repository: Path.R.t): unit =
  (* TODO: create out_dir if it doesn't exist, warn and exit if it's a file *)
  let packages = Repository.to_links repository in
  Template.generate ~out_dir:user_options.out_dir ([
    { text="A package manager for OCaml"; href="index.html" },
      Home.static_html;
    { text="Packages"; href="packages.html" },
      Repository.to_html repository;
  ] @ packages)

(* Load a source repository from a path or from Opam local installation *)
let load_source (src: repository_source): Path.R.t =
  match src with
  | Cwd ->
      Printf.printf "=== Repository: current working directory ===\n%!";
      Path.R.cwd ()
  | Path name ->
      Printf.printf "=== Repository: %s ===\n%!" name;
      Repository.of_path name
  | Opam name ->
      Printf.printf "=== Repository: %s [opam] ===\n%!" name;
      try
        Repository.of_opam name
      with
        Not_found -> raise (Unknown_repository name)

(* Generate a website from the current working directory, assuming that it's an 
   OPAM repository *)
let website_of_cwd () =
  no_operation := false;
  make_website (load_source Cwd)

(* Generate a website from the given directory, assuming that it's an OPAM 
   repository *)
let website_of_path dirname =
  no_operation := false;
  make_website (load_source (Path dirname))

(* Generate a website from the given repository name, trying to find it in local 
   OPAM installation *)
let website_of_opam repo_name =
  no_operation := false;
  try
    make_website (load_source (Opam repo_name))
  with
  | Unknown_repository repo_name ->
      Globals.error "Opam repository '%s' not found!" repo_name

(* Command-line arguments *)
let specs = [
  ("-o", Arg.String set_out_dir, "");
  ("--output", Arg.String set_out_dir,
    "The directory where to write the generated HTML files");

  ("-d", Arg.String website_of_path, "");
  ("--directory", Arg.String website_of_path,
    "Generate a website from the opam repository in 'directory'");

  ("-l", Arg.String website_of_opam, "");
  ("--local", Arg.String website_of_opam,
    "Generate a website from an opam repository in the local opam installation.");
]

(* Main *)
let () =
  (* Anonymous arguments are interpreted as directories where to find 
     repositories *)
  Arg.parse specs website_of_path
      (Printf.sprintf "%s [options]* [repository_name]*" Sys.argv.(0));
  if !no_operation then
    (* If the arguments didn't trigger any operation, try to interpret the 
       current directory as a repository and make the website out of it *)
    website_of_cwd ()


open! Stdune
open Dune_file.Plugin
open! Dune_engine

let meta_file ~dir { name; libraries = _; site = _, (pkg, site); _ } =
  Path.Build.L.relative dir
    [ ".site"
    ; Package.Name.to_string pkg
    ; Section.Site.to_string site
    ; Package.Name.to_string name
    ; Findlib.meta_fn
    ]

let resolve_libs ~sctx t =
  Result.List.map t.libraries
    ~f:(Lib.DB.resolve (Super_context.public_libs sctx))

let setup_rules ~sctx ~dir t =
  let meta = meta_file ~dir t in
  Build.delayed (fun () ->
      let open Result.O in
      let+ requires =
        let+ libs = resolve_libs ~sctx t in
        List.map libs ~f:(fun lib -> Lib_name.to_string (Lib.name lib))
      in
      let meta =
        { Meta.name = None
        ; entries =
            [ Rule
                { Meta.var = "requires"
                ; action = Set
                ; predicates = []
                ; value = String.concat ~sep:" " requires
                }
            ]
        }
      in
      Format.asprintf "@[<v>%a@,@]" Pp.to_fmt (Meta.pp meta.entries))
  |> Build.or_exn |> Build.write_file_dyn meta
  |> Super_context.add_rule sctx ~dir

let install_rules ~sctx ~dir ({ name; site = loc, (pkg, site); _ } as t) =
  if t.optional && Result.is_error (resolve_libs ~sctx t) then
    []
  else
    let meta = meta_file ~dir t in
    [ ( Some loc
      , Install.Entry.make_with_site
          ~dst:(sprintf "%s/%s" (Package.Name.to_string name) Findlib.meta_fn)
          (Site { pkg; site })
          (Super_context.get_site_of_packages sctx)
          meta )
    ]

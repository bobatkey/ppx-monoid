(lang dune 2.7)
(generate_opam_files true)

(name ppx_monoid)
(version 0.3.3)

(authors "Robert Atkey")
(license MIT)
(maintainers "bob.atkey@gmail.com")
(source (github bobatkey/ppx-monoid))

(package
 (name ppx_monoid)
 (synopsis "Syntax extension for building values of monoids")
 (description "This is a syntax extension for OCaml to make building values of
monoids easier. Assumes the existence of two operations in scope for
some type `t`:

````ocaml
empty : t
(^^)  : t -> t -> t
````

`ppx-monoid`, triggered by the PPX extension point `monoid`,
reinterprets the semicolon `;` to mean the monoid operation `^^` and
the unit expression `()` to mean `empty`.")
 (depends
  (ocaml  (>= 4.04.1))
  (ppxlib (>= 0.27.0))

  (ounit :with-test)))

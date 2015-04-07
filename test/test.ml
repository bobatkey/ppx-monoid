open OUnit

module M = struct
  type t = string
  let empty = ""
  let (^^) = (^)
end

let tests =
  "ppx_monoid" >:::
  [ "empty" >:: (fun () ->
        let empty = "empty" in
        assert_equal (begin%monoid end) empty)

  ; "one operation" >:: (fun () ->
        let (^^) = (^) in
        assert_equal (begin%monoid "foo"; "bar" end) "foobar")

  ; "single" >:: (fun () ->
        assert_equal (begin%monoid "foo" end) "foo")

  ; "specified module" >:: (fun () ->
        assert_equal (begin%monoid.M "foo"; "bar" end) "foobar")
    
  ; "let open" >:: (fun () ->
        let open M in
        assert_equal (begin%monoid "foo"; "bar" end) "foobar")

  ; "nested let" >:: (fun () -> 
        let x =
          begin%monoid.M
            let x = "foo" in
            x; x
          end
        in
        assert_equal x "foofoo")

  ; "nested let begin..end" >:: (fun () ->
        let open M in
        let x =
          begin%monoid
            (* this wouldn't type check if the inner begin..end was
               treated as a monoid expression *)
            let x = begin (); "foo" end in
            x; x
          end
        in
        assert_equal x "foofoo")

  (* Nesting begin..end expressions *)
  ; "nested begin..end, left" >:: (fun () ->
        let open M in
        let x =
          begin%monoid
            begin
              "foo";
              "bar"
            end;
            "baz"
          end
        in
        assert_equal x "foobarbaz")

  ; "nested begin..end, right" >:: (fun () ->
        let open M in
        let x =
          begin%monoid
            "baz";
            begin
              "foo";
              "bar"
            end;
          end
        in
        assert_equal x "bazfoobar")

  (* Without begin..end *)
  ; "without begin..end" >:: (fun () ->
        let open M in
        let x =
          [%monoid
            "foo";
            "bar"
          ]
        in
        assert_equal x "foobar")

(* If-then-else expressions *)
  ; "if-then-else" >:: (fun () ->
        let open M in
        let b = true in
        let x =
          begin%monoid
            if b then begin
              "foo";
              "bar"
            end else begin
              "bar";
              "foo"
            end
          end
        in
        assert_equal x "foobar")

  ; "if-then" >:: (fun () ->
        let open M in
        let b = true in
        let x =
          begin%monoid
            if b then begin
              "foo";
              "bar"
            end
          end
        in
        assert_equal x "foobar")

  (* match expressions *)
  ; "match" >:: (fun () ->
        let open M in
        let o = Some "foo" in
        let x =
          begin%monoid
            (match o with
              | None ->
                 ()
              | Some x ->
                 begin x; x end);
            "baz"
          end
        in
        assert_equal x "foofoobaz")
  ]

let _ =
  run_test_tt_main tests


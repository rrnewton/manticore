(* translate-pcomp.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure TranslatePComp : sig

  (* An AST to AST translation of parallel comprehensions. *)
    val tr : (AST.exp -> AST.exp) 
             -> AST.exp 
             -> AST.exp * (AST.pat * AST.exp) list * AST.exp option 
             -> AST.exp

  end  = struct

    structure A = AST
    structure B = Basis
    structure F = Futures
    structure R = Ropes
    structure U = UnseenBasis

    fun parrayElementType t =
	(case t
	   of A.ConTy ([t'], k) =>
	        if TyCon.same (k, B.parrayTyc)
		then t'
		else raise Fail "not a parray"
	    | _ =>  raise Fail "not a parray")

    fun tr trExp workQ (e, pes, oe) =
	  (case (pes, oe)
	     of ([], _) => raise Fail "no pbinds at all"
	      | ([(p1, e1)], NONE) =>  (* first I'll build the one pbind, no predicate case, and iter. refine it *)
		                       (* these and subsequent cases will eventually be unified together *)
                   let val t  = TypeOf.exp e
		       val t1 = TypeOf.pat p1
		       val x1 = Var.new ("x1", t1)
		       val e' = trExp e
		       val c1 = A.CaseExp (A.VarExp (x1, []), 
					   [A.PatMatch (p1, e')],
					   t)
		       val f = A.FunExp (x1, c1, t)
		       val resTy = B.parrayTy t
		       val lfSize = ASTUtil.mkInt R.maxLeafSize
		   in
		       (case e1
		         of A.RangeExp (lo, hi, optStep, rangeEltTy) =>
			      let val lo' = trExp lo
				  val hi' = trExp hi
                                  val step = (case optStep
                                                of NONE => ASTUtil.mkInt 1
                                                 | SOME s => trExp s)
				  val tabD = A.VarExp (U.tabD, [t])
				  val tup = A.TupleExp [workQ, f, lfSize, lo', hi', step]
			      in
				  A.ApplyExp (tabD, tup, resTy)
			      end
			  | _ (* not a range exp *) =>
			      let val e1' = trExp e1
				  val mapPQ = A.VarExp (U.mapPQ, [t1, t])
				  val mapResTy =
				      (case TypeOf.exp mapPQ
				         of A.FunTy (_, rty) => rty
					  | _ => raise Fail "expected function type"
				      (* end case *))
			      in
				  A.ApplyExp (A.ApplyExp (mapPQ, workQ, mapResTy),
					      A.TupleExp [f, e1'], 
					      resTy)
			      end
		       (* end case *))
		   end
	      | (pes as [(p1, e1), (p2, e2)], NONE) =>  (* the two pbind, no predicate case *)
                  let val e' = trExp e
		      val te = TypeOf.exp e
		      val resTy = B.parrayTy te
		      val t1 = TypeOf.pat p1
		      val t2 = TypeOf.pat p2
		      val x1 = Var.new ("x1", t1)
		      val x2 = Var.new ("x2", t2)
		      val ce = A.CaseExp (A.TupleExp [A.VarExp (x1, []), A.VarExp (x2, [])],
					  [A.PatMatch (A.TuplePat [p1, p2], e')],
					  te)
		      val f = A.FunExp (x1, 
					A.FunExp (x2, ce, te), 
					A.FunTy (TypeOf.pat p2, te))		      
		      val map2PQ = A.VarExp (U.map2PQ, [t1, t2, te])
		      val mapResTy = (case TypeOf.exp map2PQ
				        of A.FunTy (_, range) => range
					 | _ => raise Fail "expected function type")
		  in
		      A.ApplyExp (A.ApplyExp (map2PQ, workQ, mapResTy),
				  A.TupleExp [f, trExp e1, trExp e2],
				  resTy)
		  end
(*
		      fun build ([], _, xs, ps, es) =
			    let val (xs, ps, es) = (rev xs, rev ps, rev es)
				val tupExp = A.TupleExp (map (fn x => A.VarExp (x, [])) xs)
				val tupPat = A.TuplePat ps
				val arg = Var.new ("arg", TypeOf.exp tupExp)
				val m = A.PatMatch (tupPat, e')
				val f = A.FunExp (arg, A.CaseExp (A.VarExp (arg, []), [m], t), t)
				val t1 = parrayElementType (TypeOf.exp e1)
				val t2 = parrayElementType (TypeOf.exp e2)
				val map2 = A.VarExp (U.map2PQ, [t1, t2, t])
				val mapResTy = 
				    (case TypeOf.exp map2
				       of A.FunTy (_, rty) => rty
					| _ => raise Fail "expected function type"
				      (* end case *)) 
			    in
				A.ApplyExp (A.ApplyExp (map2, workQ, mapResTy),
					    A.TupleExp [f, A.TupleExp es], 
					    B.parrayTy t)
			    end
			| build ((p,a)::tl, n, xs, ps, es) =
			    let val x = Var.new ("x" ^ Int.toString n, TypeOf.pat p)
			    in
				build (tl, n+1, x::xs, p::ps, trExp(a)::es)
			    end
		  in
		      build (pes, 1, [], [], [])
		  end
*)
	      | (pe::_, NONE) => (* the multiple pbind, no pred case *)
                                 (* FIXME this isn't built to deal with ranges yet *)
		                 (* FIXME magicalMap! *)
		  let val e' = trExp e
		      val t  = TypeOf.exp e
		      (* build : (pat * exp) list * int * var list * pat list * exp list -> exp *)
		      fun build ([], _, xs, ps, es) =
			    let val (xs, ps, es) = (rev xs, rev ps, rev es)
				val tupExp = A.TupleExp (map (fn x => A.VarExp (x, [])) xs)
				val tupPat = A.TuplePat ps
				val caseExp = A.CaseExp (tupExp, [A.PatMatch (tupPat, e')], t)
				val arg = Var.new ("arg", TypeOf.exp tupExp)
				val m = A.PatMatch (tupPat, caseExp)
				val f = A.FunExp (arg, A.CaseExp (A.VarExp (arg, []), [m], t), t)
				val mapP_k = raise Fail "todo" (* VariableArityMaps.fromTy (TypeOf.exp tupFrom) *)
			    in
				A.ApplyExp (mapP_k, 
					    A.TupleExp [f, A.TupleExp es], 
					    B.parrayTy t)
			    end
			| build ((p,e)::tl, n, xs, ps, es) =
			    let val x = Var.new ("x" ^ Int.toString n, TypeOf.pat p)
			    in
				build (tl, n+1, x::xs, p::ps, trExp(e)::es)
			    end
		  in
		      build (pes, 1, [], [], [])
		  end				
	      | _ => raise Fail "todo"
	  (* end case *))

  end

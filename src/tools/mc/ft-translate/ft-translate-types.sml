(* ft-translate-types.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure FTTranslateTypes : sig

  val tr : FTTranslateEnv.env * FTTypes.ty -> BOM.ty
  val trScheme : FTTranslateEnv.env * FTTypes.ty_scheme -> BOM.ty

  val trDataCon : FTTranslateEnv.env * FTTypes.dcon -> FTTranslateEnv.con_bind

(* convert parse-tree types to BOM types *)
  val cvtPrimTy : FTTranslateEnv.env * ProgramParseTree.PML2.BOMParseTree.ty -> BOM.ty
  val cvtPrimTys : FTTranslateEnv.env * ProgramParseTree.PML2.BOMParseTree.ty list -> BOM.ty list

(* record the BOM kind of the representation of an AST type constructor *)
  val setTycKind : FTTypes.tycon * BOMTy.kind -> unit

(* cached lookup of primitive BOM types from the basis *)
  val stringLenBOMTy : unit -> BOM.ty
  val stringBOMTy : unit -> BOM.ty

end = struct

    structure E     = FTTranslateEnv
    structure ATy   = Types (* AST types *)
    structure FTy   = FTTypes
    structure BTy   = BOMTy
    structure BTyc  = BOMTyCon
    structure BPT   = ProgramParseTree.PML2.BOMParseTree
    structure PTVar = ProgramParseTree.Var
    structure FR    = FTFlattenRep
    structure ME    = FTModuleEnv

    fun appi f = let
	  fun appf (_, []) = ()
	    | appf (i, x::xs) = (f(i, x); appf(i+1, xs))
	  in
	    fn l => appf (0, l)
	  end

  (* a property to track the mapping from AST type constructors to BOM kinds *)
    local
      fun propsOf (FTy.Tyc {props, ...}) = props
      fun newProp mkProp = PropList.newProp (propsOf, mkProp)
      val {getFn, setFn, ...} = newProp (fn _ => BTy.K_UNIFORM)
    in
      val getTycKind = getFn
      val setTycKind = setFn
    end (* local *)

    fun insertConst (env, dc, dc') = E.insertCon (env, dc, E.Const dc')
    fun insertDCon (env, dc, repTr, dc') = E.insertCon (env, dc, E.DCon(dc', repTr))

  (* return the BOM kind of the argument of an AST data constructor; this code
   * looks at the top-level structure of the type to determine the kind.
   *)
    fun bomKindOfArgTy (FTy.DCon {argTy, ...}) =
     (case argTy of
          SOME(FTy.FunTy _) => BTy.K_BOXED
	| SOME(FTy.TupleTy(_,[])) => BTy.K_UNBOXED (* unit type *)
	| SOME(FTy.TupleTy _) => BTy.K_BOXED
	| SOME(FTy.ConTy(_, tyc)) => getTycKind tyc
	| _ => BTy.K_UNIFORM
     (* end case *))

    fun tr (env, ty) = let
	  fun tr' ty = (case ty
		 of FTy.VarTy _ => BTy.T_Any
		  | FTy.ConTy(tyArgs, tyc) => (
		      case FTTranslateEnv.findTyc (env, tyc)
		       of SOME ty => ty
			| NONE => 
			  (case tyc
			    of FTy.Tyc{def=FTy.AbsTyc, ...} => 
			       (* look for the concrete type of the constructor *)
			       (case ME.getRealizationOfTyc tyc
				  of SOME (ME.TyCon tyc) => trTyc(env, tyc)
				   | SOME (ME.TyDef tys) => trScheme(env, tys)
				   | SOME (ME.BOMTyDef ty) => cvtPrimTy env ty
(* FIXME When parray is looked up, we get NONE. *)
				   | NONE => trTyc (env, tyc)
			         (* end case *))
			     | _ => trTyc (env, tyc)
			  (* end case *))
		      (* end case *))
		  | FTy.FunTy(ty1, ty2) => BTy.T_Fun([tr' ty1], [BTy.exhTy], [tr' ty2])
		  | FTy.TupleTy (_, []) => BTy.unitTy
		  | FTy.TupleTy (_, tys) => BTy.T_Tuple(false, List.map tr' tys)
		  | FTy.FlatArrayTy _ => raise Fail "todo"
		(* end case *))
	  in
	    tr' ty
	  end

    and trScheme (env, FTy.TyScheme(_, ty)) = tr (env, ty)

    and trTyc (env, tyc as FTy.Tyc {name, def, ...}) = (case def
	   of FTy.AbsTyc => raise Fail ("unknown abstract type " ^ Atom.toString name)
	    | FTy.DataTyc{cons, ...} => let
	      (* insert a placeholder representation for tyc to avoid infinite loops *)
		val _ = E.insertTyc (env, tyc, BTy.T_Any)
	      (* partition constructors into constants and constructor function lists *)
		val (consts, conFuns) =
		      List.partition
			(fn (dc as FTy.DCon{argTy=NONE, ...}) => true | _ => false)
			  (! cons)
	      (* create the datatype constructor *)
		val nConsts = List.length consts
		val dataTyc as BTy.DataTyc{rep, kind, ...} =
		      BOMTyCon.newDataTyc (Atom.toString name, nConsts)
		fun setRep (ty, k) = (rep := ty; kind := k; setTycKind(tyc, k))
	      (* assign representations for the constants *)
		val newDataCon = BTyc.newDataCon dataTyc
		fun mkNullaryDC (i, dc) = let
		      val dc' = newDataCon (FTDataCon.nameOf dc, BTy.Enum(Word.fromInt i), [])
		      val trRep = FR.ATOM(BTy.T_Enum(Word.fromInt(nConsts - 1)))
		      in
			insertConst (env, dc, dc')
		      end
		val _ = appi mkNullaryDC consts
	      (* assign representations for the constructor functions *)
		fun mkDC (dc, rep, repTr, tys) = let
		      val dc' = newDataCon (FTDataCon.nameOf dc, rep, tys)
		      in
			insertDCon (env, dc, repTr, dc')
		      end
		fun mkDC' (dc, rep, (repTr, tys)) = mkDC (dc, rep, repTr, tys)
		fun mkTaggedDC (i, dc) = mkDC' (dc, BTy.TaggedTuple(Word.fromInt i), trArgTy(env, dc))
		in
		  case (nConsts, conFuns)
		   of (_, []) => setRep (BTy.T_Enum(Word.fromInt nConsts - 0w1), BTy.K_UNBOXED)
		    | (0, [dc]) => (case trArgTy(env, dc)
			 of (repTr, [ty]) => (
			      setRep (ty, BOMTyUtil.kindOf ty);
			      mkDC (dc, BTy.Transparent, repTr, [ty]))
			  | (repTr, tys) => (
			      setRep (BTy.T_Tuple(false, tys), BTy.K_BOXED);
			      mkDC (dc, BTy.Tuple, repTr, tys))
			(* end case *))
		    | (_, [dc]) => (
			case bomKindOfArgTy dc
			 of BTy.K_BOXED => (case trArgTy(env, dc)
			       of (repTr, [ty]) => mkDC (dc, BTy.Transparent, repTr, [ty])
				| (repTr, tys) => mkDC (dc, BTy.Tuple, repTr, tys)
			      (* end case *))
			  | _ => let (* need to use singleton tuple to represent data constructor *)
			      val argTy = tr (env, valOf(FTDataCon.argTypeOf dc))
			      in
				mkDC (dc, BTy.Tuple, FR.ATOM argTy, [argTy])
			      end
			(* end case *);
			setRep (BTy.T_Any, BTy.K_UNIFORM))
		    | (0, [dc1, dc2]) => (case (bomKindOfArgTy dc1, bomKindOfArgTy dc2)
			 of (BTy.K_BOXED, BTy.K_UNBOXED) => (
			      mkDC' (dc1, BTy.Tuple, trArgTy(env, dc1));
			      mkDC' (dc2, BTy.Transparent, trArgTy(env, dc2));
			      setRep (BTy.T_Any, BTy.K_UNIFORM))
			  | (BTy.K_UNBOXED, BTy.K_BOXED) => (
			      mkDC' (dc1, BTy.Transparent, trArgTy(env, dc1));
			      mkDC' (dc2, BTy.Tuple, trArgTy(env, dc2));
			      setRep (BTy.T_Any, BTy.K_UNIFORM))
			  | _ => (
			      mkTaggedDC (0, dc1);
			      mkTaggedDC (1, dc2);
			      setRep (BTy.T_Any, BTy.K_BOXED))
			(* end case *))
		    | (0, _) => (
			appi mkTaggedDC conFuns;
			setRep (BTy.T_Any, BTy.K_BOXED))
		    | (_, _) =>  (
			appi mkTaggedDC conFuns;
			setRep (BTy.T_Any, BTy.K_UNIFORM))
		  (* end case *);
		  E.insertTyc (env, tyc, BTy.T_TyCon dataTyc);
		  BTy.T_TyCon dataTyc
		end
	  (* end case *))

  (* translate the argument type of a data constructor; for tuples of two, or more,
   * components, we flatten the representation.
   *)
    and trArgTy (env, dc) = let
	  val rep = FR.flattenRep (tr (env, valOf (FTDataCon.argTypeOf dc)))
	  in
	    (rep, FR.dstTys rep)
	  end

  (* convert parse-tree types to BOM types *)
    and cvtPrimTy env = let
	  fun cvtTys tys = cvtPrimTys(env, tys)
	  fun cvtTy ty = (case ty
	        of BPT.T_Mark {tree, span} => cvtTy tree
		 | BPT.T_Any => BTy.T_Any
		 | (BPT.T_Enum w) => BTy.T_Enum w
		 | (BPT.T_Raw rty) => BTy.T_Raw rty
		 | (BPT.T_Tuple(mut, tys)) => BTy.T_Tuple(mut, cvtTys tys)
		 | (BPT.T_Addr ty) => BTy.T_Addr(cvtTy ty)
		 | (BPT.T_Fun(argTys, exhTys, resTys)) =>
		     BTy.T_Fun(cvtTys argTys, cvtTys exhTys, cvtTys resTys)
		 | (BPT.T_Cont tys) => BTy.T_Cont(cvtTys tys)
		 | (BPT.T_CFun cproto) => BTy.T_CFun cproto
		 | (BPT.T_VProc) => BTy.T_VProc
		 | (BPT.T_TyCon tyc) => (
		     case E.findBOMTy tyc
		      of E.BTY_NONE => raise Fail("unbound BOM type constructor " ^ PTVar.toString tyc)
		       | E.BTY_TY ty => ty
		       | E.BTY_TYS tys => trScheme(env, tys)
		       | E.BTY_TYC tyc => tr(env, FTy.ConTy([], tyc))
	             (* end case *))
	         (* end case *))
          in
	    cvtTy
	  end

    and cvtPrimTys (env, tys) = List.map (cvtPrimTy env) tys

    val cvtPrimTy = fn (env, ty) => cvtPrimTy env ty

    fun trDataCon (env, dc) = (case E.findDCon(env, dc)
	     of SOME dc' => dc'
	      | NONE => if raise Fail "todo: Exn.isExn dc" (* Exn.isExn dc *)
		  then (case FTDataCon.argTypeOf dc
		     of NONE => let (* nullary exception constructor *)
			  val dc' = BTyc.newExnCon (FTDataCon.nameOf dc, [])
			  val result = E.ExnConst dc'
			  in
			    E.insertCon (env, dc, result);
			    result
			  end
		      | SOME ty => let
(* NOTE: we may want to use a flat representation for exn values! *)
			  val ty' = tr (env, ty)
			  val dc' = BTyc.newExnCon (FTDataCon.nameOf dc, [ty'])
			  val repTr = FR.TUPLE([ty'], [FR.ATOM ty'])
			  val result = E.DCon(dc', repTr)
			  in
			    E.insertCon (env, dc, result);
			    result
			  end
		    (* end case *))
		  else (
		    ignore (trTyc(env, FTDataCon.ownerOf dc));
		    valOf (E.findDCon(env, dc)))
	    (* end case *))

  (* cached lookup of primitive BOM types from the basis *)
    local
      fun cachedLookup name = let
	    val cache = ref NONE
	    fun lookup () = (case !cache
		   of NONE => let
			val id = BasisEnv.getBOMTyFromBasis [name]
			in
			  case FTTranslateEnv.findBOMTyDef id
			   of SOME ty => (cache := SOME ty; ty)
			    | NONE => raise Fail("Unable to locate " ^ name)
			  (* end case *)
			end
		    | SOME item => item
		  (* end case *))
	    in
	      lookup
	    end
    in
    val stringLenBOMTy = cachedLookup "string_len"
    val stringBOMTy = cachedLookup "ml_string"
    end (* local *)

  end
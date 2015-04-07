(* bom.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure BOM =
  struct

    datatype data_con = datatype BOMTy.data_con

    type ty = BOMTy.ty
    type hlop = HLOp.hlop

    type offset = IntInf.int

    datatype exp = E_Pt of (ProgPt.ppt * term)

    and term
      = E_Let of (var list * exp * exp)
      | E_Stmt of (var list * rhs * exp)
      | E_Fun of (lambda list * exp)
      | E_Cont of (lambda * exp)
      | E_If of (cond * exp * exp)
      | E_Case of (var * (pat * exp) list * exp option)
      | E_Typecase of (BOMTy.ty_var * (ty * exp) list * exp option)  (* only inside HLOp definitions *)
      | E_Apply of (var * var list * var list)
      | E_Throw of (var * var list)
      | E_Ret of var list
      | E_HLOp of (hlop * var list * var list)	(* application of high-level operator *)

    and rhs
      = E_Prim of prim
      | E_Alloc of (ty * var list)		(* allocation in local heap *)
      | E_DCon of (data_con * var list)		(* data constructor; the argument list is empty for *)
						(* nullary constructors *)
      | E_Select of (int * var)			(* select i'th field (zero-based) *)
      | E_Update of (int * var * var)		(* update i'th field (zero-based) *)
      | E_AddrOf of (int * var)			(* return address of i'th field (zero-based) *)
      | E_Cast of (ty * var)			(* deprecated *)
      | E_Promote of var			(* promotion of object to global heap *)
      | E_CCall of (var * var list)		(* foreign-function calls *)
      | E_HostVProc				(* gets the hosting VProc *)
      | E_VPLoad of (offset * var)		(* load a value from the given byte *)
						(* offset in the vproc structure *)
      | E_VPStore of (offset * var * var)	(* store a value at the given byte *)
						(* offset in the vproc structure *)
      | E_VPAddr of (offset * var)		(* address of given byte offset *)
						(* in the vproc structure *)
      | E_Const of const

    and lambda = FB of {	  	    (* function/continuation abstraction *)
	  f : var,				(* function name *)
	  params : var list,			(* parameters *)
	  exh : var list,			(* exception continuation *)
	  body : exp				(* function body *)
	}

    and pat			  	    (* simple, one-level, patterns *)
      = P_DCon of data_con * var list		(* data constructor; the argument *)
						(* list is empty for *)
						(* nullary constructors *)
      | P_Const of const

    and var_kind
      = VK_None
      | VK_Let of exp
      | VK_RHS of rhs
      | VK_Param
      | VK_Fun of lambda
      | VK_Cont of lambda
      | VK_CFun of c_fun

    withtype var = (var_kind, ty) VarRep.var_rep
         and cond = var Prim.cond
         and prim = var Prim.prim
	 and const = (Literal.literal * ty)
	 and c_fun = var CFunctions.c_fun

    fun varKindToString VK_None = "None"
      | varKindToString (VK_Let _) = "Let"
      | varKindToString (VK_RHS _) = "RHS"
      | varKindToString VK_Param = "Param"
      | varKindToString (VK_Fun _) = "Fun"
      | varKindToString (VK_Cont _) = "Cont"
      | varKindToString (VK_CFun _) = "CFun"

    structure Var = struct
    	local
	  structure V = VarFn (
	    struct
	      type kind = var_kind
	      type ty = ty
	      val defaultKind = VK_None
	      val kindToString = varKindToString
	      val tyToString = BOMTyUtil.toString
	    end)
	in
	open V
      (* application counts for functions *)
	local
	  val {clrFn, getFn, peekFn, ...} = newProp (fn _ => ref 0)
	in
	val appCntRef = getFn
	val appCntRmv = clrFn
	fun appCntOf v = (case peekFn v of NONE => 0 | (SOME ri) => !ri)
	fun combineAppUseCnts (x as VarRep.V{useCnt=ux, ...}, y as VarRep.V{useCnt=uy, ...}) = (
	      ux := !ux + !uy;
	      case peekFn y
	       of (SOME ry) => let
		    val rx = appCntRef x
		    in
		      rx := !rx + !ry
		    end
		| NONE => ()
	      (* end case *))
      (* string representation that includes counts *)
	val toString = fn x => (case peekFn x
	       of NONE => concat[toString x, "#", Int.toString(useCount x)]
		| SOME r => concat[
		      toString x, "#", Int.toString(useCount x),
		      ".", Int.toString(!r)
		    ]
	      (* end case *))
	end (* local val ... *)
      (* mapping from functions to the HLOp that they define *)
	val {clrFn = clrHLOp, peekFn = hlop, setFn = setHLOp, ...} =
	      newProp (fn _ => ((raise Fail "no HLOp") : hlop))
	fun isHLOp f = Option.isSome(hlop f)
	end (* local structure V = ... *)
      end 

    datatype program = PROGRAM of {
	name : string,
	externs : var CFunctions.c_fun list,
	hlops : var list,		    (* the names of the HLOps *)
(*
	rewrites : rewrite list,
*)
	body : lambda
      }

(* FIXME: need constructor functions *)

  (* mkExp : term -> exp *)
    fun mkExp t = E_Pt(ProgPt.new(), t)

    fun mkLet (lhs, rhs, exp) = (
    	  List.app (fn x => Var.setKind (x, VK_Let rhs)) lhs;
	  mkExp(E_Let(lhs, rhs, exp)))
    fun mkStmt (lhs, rhs, exp) = (
    	  List.app (fn x => Var.setKind (x, VK_RHS rhs)) lhs;
	  mkExp(E_Stmt(lhs, rhs, exp)))
    fun mkStmts ([], exp) = exp
      | mkStmts ((lhs, rhs)::r, exp) = mkStmt(lhs, rhs, mkStmts(r, exp))

    local
    fun setLambdaKind (lambda as FB{f, params, exh, ...}) = (
	  Var.setKind(f, VK_Fun lambda);
	  List.app (fn x => Var.setKind(x, VK_Param)) (params @ exh))
    in
    fun mkLambda {f, params, exh, body} = let
	  val l = FB{f=f, params=params, exh=exh, body=body}
	  in
	    setLambdaKind l;
	    l
	  end
    fun mkFun (fbs, e) = (
	  List.app setLambdaKind fbs;
	  mkExp(E_Fun(fbs, e)))
    end

    fun mkCont (lambda as FB{f, params, ...},e) = (
          Var.setKind (f, VK_Cont lambda);
	  List.app (fn x=> Var.setKind(x, VK_Param)) params;
	  mkExp(E_Cont(lambda, e)))
    fun mkIf arg = mkExp(E_If arg)

  (* mkCase : var * (pat * exp) list * exp option -> exp *)
    fun mkCase arg = mkExp(E_Case arg)

    fun mkApply arg = mkExp(E_Apply arg)
    fun mkThrow arg = mkExp(E_Throw arg)
    fun mkRet arg = mkExp(E_Ret arg)
    fun mkHLOp arg = mkExp(E_HLOp arg)

    fun mkCFun arg = let
	  val cf = CFunctions.CFun arg
	  in
	    Var.setKind(#var arg, VK_CFun cf);
	    cf
	  end

  (* mkProgram : string * var CFunctions.c_fun list * lambda -> program *)
    fun mkProgram (name, externs, hlops, body as FB{params, exh, ...}) = (
	  List.app (fn x => Var.setKind(x, VK_Param)) (params @ exh);
	  List.app
	    (fn (cf as CFunctions.CFun{var, ...}) => Var.setKind(var, VK_CFun cf))
	      externs;
	  PROGRAM{name = name, externs = externs, hlops = hlops, body = body})

  end
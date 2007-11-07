(* translate-env.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure TranslateEnv : sig

    type env

    val mkEnv : unit -> env

  (* data-constructor bindings *)
    datatype con_bind
      = Const of word * BOMTy.ty
      | DCon of BOMTy.data_con

  (* variable bindings *)
    datatype var_bind
      = Lambda of (BOMTy.ty -> BOM.lambda) (* used for primops and high-level ops *)
      | Var of BOM.var
      | EqOp			(* either "=" or "<>" *)

    val insertTyc	: (env * Types.tycon * BOMTy.ty) -> unit
    val insertCon	: (env * Types.dcon * con_bind) -> unit
    val insertFun	: (env * AST.var * (BOMTy.ty -> BOM.lambda)) -> env
    val insertVar	: (env * AST.var * BOM.var) -> env
    val newHandler	: env -> (BOM.var * env)

    val findTyc		: (env * Types.tycon) -> BOMTy.ty option
    val findDCon	: (env * Types.dcon) -> con_bind option
    val lookupVar	: (env * AST.var) -> var_bind
    val handlerOf	: env -> BOM.var

  (* output an environment *)
    val dump : (TextIO.outstream * env) -> unit

  end = struct

    structure TTbl = TyCon.Tbl
    structure DTbl = DataCon.Tbl
    structure VMap = Var.Map

    datatype con_bind
      = Const of word * BOMTy.ty
      | DCon of BOMTy.data_con

    datatype var_bind
      = Lambda of (BOMTy.ty -> BOM.lambda) (* used for primops and high-level ops *)
      | Var of BOM.var
      | EqOp			(* either "=" or "<>" *)

    datatype env = E of {
	tycEnv : BOM.ty TTbl.hash_table,
	dconEnv : con_bind DTbl.hash_table,
	varEnv : var_bind VMap.map,	(* map from AST variables to BOM variables *)
	exh : BOM.var			(* current exception handler *)
      }

    fun mkEnv () = let
	  val vEnv = List.foldl VMap.insert' VMap.empty [
		  (Basis.eq,	EqOp),
		  (Basis.neq,	EqOp)
		]
	  in
	    E{
		tycEnv = TTbl.mkTable (32, Fail "tyc table"),
		dconEnv = DTbl.mkTable (64, Fail "dcon table"),
		varEnv = vEnv,
		exh = BOM.Var.new ("*bogus*", BOMTy.T_Any)
	      }
	  end

    fun insertTyc (E{tycEnv, ...}, tyc, bty) = TTbl.insert tycEnv (tyc, bty)

    fun insertCon (E{dconEnv, ...}, dc, bind) = DTbl.insert dconEnv (dc, bind)

    fun insertFun (E{tycEnv, dconEnv, varEnv, exh}, x, lambda) = E{
	    tycEnv = tycEnv,
	    dconEnv = dconEnv,
	    varEnv = VMap.insert(varEnv, x, Lambda lambda),
	    exh = exh
	  }

    fun insertVar (E{tycEnv, dconEnv, varEnv, exh}, x, x') = E{
	    tycEnv = tycEnv,
	    dconEnv = dconEnv,
	    varEnv = VMap.insert(varEnv, x, Var x'),
	    exh = exh
	  }

    fun newHandler (E{tycEnv, dconEnv, varEnv, ...}) = let
	  val exh = BOM.Var.new("_exh", BOMTy.exhTy)
	  val env = E{
		  tycEnv = tycEnv,
		  dconEnv = dconEnv,
		  varEnv = varEnv,
		  exh = exh
		}
	  in
	    (exh, env)
	  end

    fun findTyc (E{tycEnv, ...}, tyc) = TTbl.find tycEnv tyc

    fun findDCon (E{dconEnv, ...}, dc) = DTbl.find dconEnv dc

    fun lookupVar (E{varEnv, ...}, x) = (case VMap.find(varEnv, x)
	   of SOME x' => x'
	    | NONE => raise Fail(concat["lookupVar(_, ", Var.toString x, ")"])
	  (* end case *))

  (* handlerOf : env -> B.var *)
    fun handlerOf (E{exh, ...}) = exh

  (* output an environment *)
    fun dump (outStrm, E{tycEnv, dconEnv, varEnv, ...}) = let
	  fun pr x = TextIO.output(outStrm, x)
	  fun prl xs = pr(String.concat xs)
	  fun prTyc (tyc, ty) = prl [
		  "    ", TyCon.toString tyc, " = ", BOMTyUtil.toString ty, "\n"
		]
	  fun prDcon (dc, Const(n, ty)) = prl [
		  "    ", DataCon.nameOf dc, " = ", Word.toString n, " : ",
		  BOMTyUtil.toString ty, "\n"
		]
	    | prDcon (dc, DCon dc') = prl [
		  "    ", DataCon.nameOf dc, " = ", BOMTyCon.dconName dc', "\n"
		]
	  fun prVar (x, bind) = let
		val x' = (case bind
		       of Var x' => x'
			| Lambda _ => raise Fail "prVar | Lambda" (* FIXME *)
		      (* end case *))
		in
		  prl [
		      "    ", Var.toString x, " : ", TypeUtil.schemeToString(Var.typeOf x),
		      " = ", BOM.Var.toString x', " : ",
		      BOMTyUtil.toString(BOM.Var.typeOf x'), "\n"
		    ]
		end
	  in
	    pr "***** Translation environment dump *****\n";
	    pr "  *** Type constructors:\n";
	    TTbl.appi prTyc tycEnv;
	    pr "  *** Data constructors:\n";
	    DTbl.appi prDcon dconEnv;
	    pr "  *** Variables:\n";
	    VMap.appi prVar varEnv;
	    pr "*****\n"
	  end

  end

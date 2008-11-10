(* translate-pval-cilk5.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * This module performs the translation [| e |] given below.

    [| let pval x = e1 in e2 end |]

 * =

   let
   val ivar = WorkStealingIVar.ivar(Cilk5WorkStealing.push)
   fun bodyFn selFn = [| e2 |][x -> selFn()]
   cont slowPathK () = bodyFn(fn () => WorkStealingIVar.get ivar)
   val _ = Cilk5WorkStealing.push slowPathK
   val x = [| e1 |]
   in
      if (Cilk5WorkStealing.pop())
	 then bodyFn(fn () => x)
      else ( WorkStealingIVar.put(ivar, x); Control.stop() )
   
 * 
 * - For the full technical discussion, see our Section 5 of our 2008 ICFP paper,
 *   A scheduling framework for general-purpose parallel languages.
 * - This implementation follows the Cilk5 approach to work stealing.
 *)

structure TranslatePValCilk5  : sig

  (* An AST to BOM translation of parrays to ropes. *)
    val tr : {
	  env : TranslateEnv.env,
	  trVar : (TranslateEnv.env * AST.var) -> (BOM.Var.var * TranslateEnv.env),
	  trExp : TranslateEnv.env * AST.exp * (BOM.Var.var -> BOM.exp) -> BOM.exp,
	  x : AST.var,
	  e1 : AST.exp,
	  e2 : AST.exp
	} -> BOM.exp

  end  = struct

    structure B   = BOM
    structure BTy = BOMTy
    structure BU  = BOMUtil
    structure BTy = BOMTy
    structure BV = BOM.Var
    structure E = TranslateEnv

  (* ivar support *)
    fun iVarTy env = E.findBOMTyByPath ["WorkStealingIVar", "ivar"]
    fun iGet () = E.findBOMHLOpByPath ["WorkStealingIVar", "get"]
    fun iPut () = E.findBOMHLOpByPath ["WorkStealingIVar", "put"]
    fun iVar () = E.findBOMHLOpByPath ["WorkStealingIVar", "ivar"]
    fun mkIVar (exh, spawnFn) = 
	  B.mkHLOp(iVar(), [spawnFn], [exh])
    fun mkIPut (exh, iv, x) =
	  B.mkHLOp(iPut(), [iv, x], [exh])
    fun mkIGet (exh, iv) =
	  B.mkHLOp(iGet(), [iv], [exh])
  (* deque support *)
    fun wsPush () = E.findBOMHLOpByPath ["Cilk5WorkStealing", "push-tl"]
    fun wsPop () = E.findBOMHLOpByPath ["Cilk5WorkStealing", "pop-tl"]
    fun mkWsPush (exh, kLocal) =
	  B.mkHLOp(wsPush(), [kLocal], [exh])
    fun mkWsPop exh =
	  B.mkHLOp(wsPop(), [], [exh])
  (* spawn function *)
    fun fiberTy env = E.findBOMTyByPath["PrimTypes", "fiber"]
    fun mkSpawnFn env = let
	  val (exh, _) = E.newHandler env
	  val spawnFn = BV.new("spawnFn", BTy.T_Fun([fiberTy env], [BTy.exhTy], []))
	  val k = BV.new("k", fiberTy env)
	  in
	     B.mkLambda{f=spawnFn, params=[k], exh=[exh], body=mkWsPush(exh, k)}
          end

    fun mkStop exh = 
	  B.mkHLOp(E.findBOMHLOpByPath ["Control", "stop"], [], [exh])

    fun unitVar () = BV.new("_unit", BTy.unitTy)

    fun tr {env, trExp, trVar, x, e1, e2} = let
	  val exh = E.handlerOf env
	  val ty1 = TranslateTypes.tr(env, TypeOf.exp e1)
	  val ty2 = TranslateTypes.tr(env, TypeOf.exp e2)
	  val spawnFnL as B.FB{f=spawnFn, ...} = mkSpawnFn env
	  val ivar = BV.new("ivar", iVarTy env)
	  val (x', env) = trVar(env, x)
	  val selFnAST = Var.new("selFn", AST.FunTy(Basis.unitTy, TypeOf.exp e1))
	  val (selFn, env) = trVar(env, selFnAST)
        (* e2' = e2[x -> selFn()] *)
	  val e2' = VarSubst.substForExp (VarSubst.idSubst x) 
					 (ASTUtil.mkApplyExp(AST.VarExp(selFnAST, []), [AST.TupleExp[]]))
					 e2
	  val bodyFn = BV.new("bodyFn", BTy.T_Fun([BV.typeOf selFn], [BTy.exhTy], [ty2]))
	  val (bodyExh, _) = E.newHandler env
	  val bodyFnL = 
	      B.mkLambda{f=bodyFn, params=[selFn], exh=[bodyExh], body=trExp(env, e2', fn v2 => B.mkRet[v2])}
	  val selFromIVar = BV.new("selFromIVar", BTy.T_Fun([BTy.unitTy], [BTy.exhTy], [ty1]))
	  val (selFromIVarExh, _) = E.newHandler env
	  val selFromIVarL = B.mkLambda{f=selFromIVar, params=[unitVar()], exh=[selFromIVarExh], body=mkIGet(exh, ivar)}
	  val slowPath = BV.new("slowPath", BTy.T_Cont[BTy.unitTy])
	  val slowPathL = 
	      B.mkLambda{f=slowPath, params=[unitVar()], exh=[], body=
                 B.mkApply(bodyFn, [selFromIVar], [exh])}
	  val goLocal = BV.new("goLocal", BOMTy.boolTy)
	  val selLocally = BV.new("selLocally", BTy.T_Fun([BTy.unitTy], [BTy.exhTy], [ty1]))
	  val (selLocallyExh, _) = E.newHandler env
          in
	     B.mkFun([spawnFnL],
	     B.mkLet([ivar], mkIVar(exh, spawnFn),
             B.mkFun([bodyFnL, selFromIVarL],
             B.mkCont(slowPathL,
             B.mkLet([], mkWsPush(exh, slowPath),
	     trExp(env, e1, fn x1 =>
             B.mkFun([B.mkLambda{f=selLocally, params=[unitVar()], exh=[selLocallyExh], body=B.mkRet[x1]}],
             B.mkLet([goLocal], mkWsPop exh,
		      B.mkIf(goLocal,
			     B.mkApply(bodyFn, [selLocally], [exh]),
			     B.mkLet([], mkIPut(exh, ivar, x1),
				     mkStop exh))))))))))
	  end

  end

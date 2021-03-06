(* print-bom.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure PrintBOMDebug = 
struct

    structure B = BOM
    structure BV = B.Var
    structure Ty = BOMTy

    datatype arg = MODULE of B.module | EXP of B.exp

	  fun pr s = print s
	  fun prl s = pr(String.concat s)
	  fun prIndent 0 = ()
	    | prIndent n = (pr "  "; prIndent(n-1))
	  fun indent i = prIndent i
	  fun prList' toS [] = ()
	    | prList' toS [x] = pr(toS x)
	    | prList' toS l = let
		fun prL [] = ()
		  | prL [x] = pr(toS x)
		  | prL (x::r) = (pr(toS x); pr ","; prL r)
		in
		  prL l
		end
	  fun prList toS [] = pr "()"
	    | prList toS [x] = pr(toS x)
	    | prList toS l = let
		fun prL [] = ()
		  | prL [x] = pr(toS x)
		  | prL (x::r) = (pr(toS x); pr ","; prL r)
		in
		  pr "("; prL l; pr ")"
		end
	  fun varBindToString x = String.concat[
		  BV.toString x, ":", BOMTyUtil.toString(BV.typeOf x)
		]
	  fun varUseToString x = BV.toString x
	  fun prLHS [] = pr "do "
	    | prLHS [x] = (pr "let "; pr(varBindToString x); pr " = ")
	    | prLHS xs = (pr "let "; prList varBindToString xs; pr " = ")
	  fun prExp (i, B.E_Pt(_, e)) = (
		indent i;
		case e
		 of B.E_Let(lhs, rhs, e) => (
		      prLHS lhs; pr "\n"; prExp(i+2, rhs);
		      prExp (i, e))
		  | B.E_Stmt(xs, rhs, e) => (
		      prLHS xs; prRHS rhs; pr "\n";
		      prExp (i, e))
		  | B.E_Fun(fb::fbs, e) => (
		      prLambda(i, "fun ", fb);
		      List.app (fn fb => (indent i; prLambda(i, "and ", fb))) fbs;
		      prExp (i, e))
		  | B.E_Fun([], e) => (
		      pr "<** empty function binding** >\n";
		      prExp (i, e))
		  | B.E_Cont(fb, e) => (prLambda(i, "cont ", fb); prExp (i, e))
		  | B.E_If(cond, e1, e2) => prIf(i, cond, e1, e2)
		  | B.E_Case(x, cases, dflt) => let
		      fun prCase ((pat, e), isFirst) = (
			    indent i;
			    if isFirst then pr " of " else pr "  | ";
			    case pat
			     of B.P_DCon(B.DCon{name, ...}, [arg]) => (
				  pr name; pr "("; pr(varBindToString arg); pr ")")
			      | B.P_DCon(B.DCon{name, ...}, args) => (
				  pr name;
				  prList varBindToString args)
			      | B.P_Const const => prConst const
			    (* end case *);
			    pr " =>\n";
			    prExp (i+2, e);
			    false)
		      in
			prl ["case ", varUseToString x, "\n"];
			ignore (List.foldl prCase true cases);
			case dflt
			 of NONE => ()
			  | SOME e => (indent(i+1); pr "default:\n"; prExp(i+2, e))
			(* end case *);
                        (indent (i+1); pr "end\n")
		      end
		  | B.E_Apply(f, args, []) => (
		      prl["apply ", varUseToString f, " ("];
		      prList' varUseToString args;
		      pr ")\n")
		  | B.E_Apply(f, args, rets) => (
		      prl["apply ", varUseToString f, " ("];
		      prList' varUseToString args;
		      pr " / ";
		      prList' varUseToString rets;
		      pr ")\n")
		  | B.E_Throw(k, args) => (
		      prl["throw ", varUseToString k, " "];
		      prList varUseToString args;
		      pr "\n")
		  | B.E_Ret xs => (
		      pr "return (";
		      prList varUseToString xs;
		      pr ")\n")
		  | B.E_HLOp(hlop, args, []) => (
		      pr(HLOp.toString hlop); pr " ";
		      prList varUseToString args;
		      pr "\n")
		  | B.E_HLOp(hlop, args, rets) => (
		      pr(HLOp.toString hlop); pr " (";
		      prList' varUseToString args; pr " / ";
		      prList' varUseToString rets; pr ")\n")
		(* end case *))
	  and prRHS (B.E_Const c) = prConst c
	    | prRHS (B.E_Cast(ty, y)) = prl["(", BOMTyUtil.toString ty, ")", varUseToString y]
	    | prRHS (B.E_Select(i, y)) = prl ["#", Int.toString i, "(", varUseToString y, ")"]
	    | prRHS (B.E_Update(i, y, z)) = prl [
		  "#", Int.toString i, "(", varUseToString y, ") := ", varUseToString z
		]
	    | prRHS (B.E_AddrOf(i, y)) = prl ["&", Int.toString i, "(", varUseToString y, ")"]
	    | prRHS (B.E_Alloc(ty, ys)) = let
		val mut = (case ty of BOMTy.T_Tuple(true, _) => "!" | _ => "")
		in
		  pr(concat["alloc ", mut, "("]); prList' varUseToString ys; pr ")"
		end
	    | prRHS (B.E_Promote y) = (pr "promote "; pr (varUseToString y))
	    | prRHS (B.E_Prim p) = pr (PrimUtil.fmt varUseToString p)
	    | prRHS (B.E_DCon(dc, args)) = (
		pr(BOMTyCon.dconName dc); pr "("; prList' varUseToString args; pr ")")
	    | prRHS (B.E_CCall(f, args)) = (
		prl ["ccall ", varUseToString f, " "];
		prList varUseToString args)
	    | prRHS (B.E_HostVProc) = pr "host_vproc()"
	    | prRHS (B.E_VPLoad(offset, vp)) = prl [
		  "vpload(", IntInf.toString offset, ", ", varUseToString vp, ")"
		]
	    | prRHS (B.E_VPStore(offset, vp, x)) = prl [
		  "vpstore(", IntInf.toString offset, ", ", varUseToString vp, ", ",
		  varUseToString x, ")"
		]
	    | prRHS (B.E_VPAddr(offset, vp)) = prl [
		  "vpaddr(", IntInf.toString offset, ", ", varUseToString vp, ")"
		]
	  and prConst (lit, ty) = prl [
		  Literal.toString lit, ":", BOMTyUtil.toString ty
		]
	  and prLambda (i, prefix, B.FB{f, params, exh, body}) = let
		fun prParams params = prList' varBindToString params
		in
		  prl [prefix, varUseToString f, " "];
		  pr "(";
		  case (params, exh)
		   of ([], []) => ()
		    | (_, []) => prParams params
		    | ([], _) => (pr "- / "; prParams exh)
		    | _ => (prParams params; pr " / "; prParams exh)
		  (* end case *);
		  case BV.typeOf f
		   of Ty.T_Fun(_, _, [ty]) => (pr ") : "; pr(BOMTyUtil.toString ty); pr " =\n")
		    | Ty.T_Fun(_, _, tys) => (
			pr ") -> (";
			pr (String.concatWith "," (List.map BOMTyUtil.toString tys));
			pr ") = \n")
		    | _ => pr ") =\n"
		  (* end case *);
		  prExp (i+2, body)
		end
	  and prIf (i, cond, e1, B.E_Pt(_, B.E_If(cond', e2, e3))) = (
		prl ["if ", condToString cond, " then\n"];
		prExp(i+1, e1);
		indent (i); pr "else "; prIf(i, cond', e2, e3))
	    | prIf (i, cond, e1, e2) = (
		prl ["if ", condToString cond, " then\n"];
		prExp(i+1, e1);
		indent (i); pr "else\n"; prExp(i+1, e2))
	  and condToString cond = CondUtil.fmt varUseToString cond
	  fun prExtern cf = (indent 1; prl [CFunctions.cfunToString cf, "\n"])

	  
  end

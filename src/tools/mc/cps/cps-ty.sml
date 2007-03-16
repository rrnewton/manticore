(* cps-ty.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure CPSTy =
  struct

    datatype raw_ty = datatype RawTypes.raw_ty

    datatype ty
      = T_Any			(* unknown type; uniform representation *)
      | T_Enum of Word.word	(* unsigned tagged integer; word is max value <= 2^31-1 *)
      | T_Raw of raw_ty		(* raw machine type *)
      | T_Wrap of raw_ty	(* boxed raw value *)
      | T_Tuple of ty list	(* heap-allocated tuple *)
      | T_Fun of ty list
      | T_Cont of ty list
      | T_CFun of CFunctions.c_proto

    val unitTy = T_Enum(0w0)
    val boolTy = T_Enum(0w1)	(* false = 0, true = 1 *)

    fun toString ty = let
	  fun tys2l ([], l) = l
	    | tys2l ([ty], l) = toString ty :: l
	    | tys2l (ty::tys, l) =
		toString ty ::
		  (List.foldr (fn (ty, l) => "," :: toString ty :: l) l tys)
	  in
	    case ty
	     of T_Any => "any"
	      | T_Enum w => concat["enum(0..", Word.fmt StringCvt.DEC w, ")"]
	      | T_Raw ty => RawTypes.toString ty
	      | T_Wrap ty => concat["wrap(", RawTypes.toString ty, ")"]
	      | T_Tuple tys => concat("(" :: tys2l(tys, [")"]))
	      | T_Fun tys => concat("fun(" :: tys2l(tys, [")"]))
	      | T_Cont tys => concat("cont(" :: tys2l(tys, [")"]))
	      | T_CFun cp => CFunctions.protoToString cp
	    (* end case *)
	  end

  end

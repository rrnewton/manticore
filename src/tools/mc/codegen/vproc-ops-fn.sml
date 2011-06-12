(* vproc-ops-fn.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Generate code for accessing and modifying fields in the vproc structure.
 *)

signature VPROC_OPS =
  sig

    structure MTy : MLRISC_TYPES
    structure VarDef : VAR_DEF

  (* this expression is a pointer to the host vproc structure. *)
    val genHostVP  : MTy.mlrisc_tree
    val genHostVP' : MTy.T.rexp

  (* load a value from a given offset off the vproc structure. *)
    val genVPLoad  : VarDef.var_def_tbl -> (MTy.T.ty * CFG.offset * CFG.var) -> MTy.mlrisc_tree
    val genVPLoad' : (MTy.T.ty * CFG.offset * MTy.T.rexp) -> MTy.T.rexp

  (* store a value at an offset from the vproc structure. *)
    val genVPStore  : VarDef.var_def_tbl -> (MTy.T.ty * CFG.offset * CFG.var * CFG.var) -> MTy.T.stm
    val genVPStore' : (MTy.T.ty * CFG.offset * MTy.T.rexp * MTy.T.rexp) -> MTy.T.stm

  (* compute an offset off the vproc structure. *)
    val genVPAddrOf  : VarDef.var_def_tbl -> (CFG.offset * CFG.var) -> MTy.mlrisc_tree
    val genVPAddrOf' : (CFG.offset * MTy.T.rexp) -> MTy.T.rexp

  end (* VPROC_OPS *)

functor VProcOpsFn (
    structure MTy : MLRISC_TYPES
    structure VarDef : VAR_DEF 
          where type MTy.mlrisc_kind = MTy.mlrisc_kind
          where type MTy.mlrisc_tree = MTy.mlrisc_tree
          where type MTy.mlrisc_reg = MTy.mlrisc_reg
          where type MTy.T.cond = MTy.T.cond
          where type MTy.T.fcond = MTy.T.fcond
          where type MTy.T.rounding_mode = MTy.T.rounding_mode
          where type MTy.T.div_rounding_mode = MTy.T.div_rounding_mode
          where type MTy.T.ext = MTy.T.ext
          where type MTy.T.stm = MTy.T.stm
          where type MTy.T.rexp = MTy.T.rexp
          where type MTy.T.rep = MTy.T.rep
          where type MTy.T.oper = MTy.T.oper
          where type MTy.T.fexp = MTy.T.fexp
          where type MTy.T.ccexp = MTy.T.ccexp
          where type MTy.T.mlrisc = MTy.T.mlrisc
    structure Regs : MANTICORE_REGS
    structure Spec : TARGET_SPEC
    structure Types : ARCH_TYPES
    structure MLTreeComp : MLTREECOMP 
  ) : VPROC_OPS = struct
  
    structure MTy = MTy
    structure VarDef = VarDef
    structure W = Word64
    structure Cells = MLTreeComp.I.C
    structure T = MTy.T
  
    val ty = MTy.wordTy
    val memory = ManticoreRegion.memory

    val genHostVP' = T.REG(ty, Regs.vprocPtrReg)

    val genHostVP = MTy.EXP(ty, genHostVP')
  
    fun genVPAddrOf' (offset, vp) = T.ADD(ty, vp, T.LI offset)

    fun genVPAddrOf varDefTbl (offset, vp) =
	  MTy.EXP (ty, genVPAddrOf' (offset, VarDef.defOf varDefTbl vp))

    fun genVPLoad' (ty, offset, vp) = T.LOAD(ty, genVPAddrOf' (offset, vp), memory)

    fun genVPLoad varDefTbl (ty, offset, vproc) =
	  MTy.EXP (ty, genVPLoad' (ty, offset, VarDef.defOf varDefTbl vproc))
  
    fun genVPStore' (ty, offset, vp, v) = T.STORE (ty, genVPAddrOf' (offset, vp), v, memory)
  
    fun genVPStore varDefTbl (ty, offset, vproc, v) =
	  genVPStore' (ty, offset, VarDef.defOf varDefTbl vproc, 
		    VarDef.defOf varDefTbl v)
  
  end (* VProcOpsFn *)

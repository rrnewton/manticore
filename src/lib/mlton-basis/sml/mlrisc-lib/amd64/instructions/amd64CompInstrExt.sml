(* amd64CompInstrExt.sml
 *
 * COPYRIGHT (c) 2007 The Fellowship of SML/NJ (http://smlnj.org)
 *
 * emit code for extensions to the amd64 instruction set.
 *)

signature AMD64COMP_INSTR_EXT = sig
  structure I : AMD64INSTR
  structure TS : MLTREE_STREAM (* where T = I.T *)
                 where type T.Basis.cond = I.T.Basis.cond
                   and type T.Basis.div_rounding_mode = I.T.Basis.div_rounding_mode
                   and type T.Basis.ext = I.T.Basis.ext
                   and type T.Basis.fcond = I.T.Basis.fcond
                   and type T.Basis.rounding_mode = I.T.Basis.rounding_mode
                   and type T.Constant.const = I.T.Constant.const
                   and type ('s,'r,'f,'c) T.Extension.ccx = ('s,'r,'f,'c) I.T.Extension.ccx
                   and type ('s,'r,'f,'c) T.Extension.fx = ('s,'r,'f,'c) I.T.Extension.fx
                   and type ('s,'r,'f,'c) T.Extension.rx = ('s,'r,'f,'c) I.T.Extension.rx
                   and type ('s,'r,'f,'c) T.Extension.sx = ('s,'r,'f,'c) I.T.Extension.sx
                   and type T.I.div_rounding_mode = I.T.I.div_rounding_mode
                   and type T.Region.region = I.T.Region.region
                   and type T.ccexp = I.T.ccexp
                   and type T.fexp = I.T.fexp
                   (* and type T.labexp = I.T.labexp *)
                   and type T.mlrisc = I.T.mlrisc
                   and type T.oper = I.T.oper
                   and type T.rep = I.T.rep
	           and type T.rexp = I.T.rexp
                   and type T.stm = I.T.stm
  structure CFG : CONTROL_FLOW_GRAPH (* where I = I and P = TS.S.P *)
                  where type I.addressing_mode = I.addressing_mode
                    and type I.ea = I.ea
                    and type I.instr = I.instr
                    and type I.instruction = I.instruction
                    and type I.operand = I.operand
                  where type P.Client.pseudo_op = TS.S.P.Client.pseudo_op
                    and type P.T.Basis.cond = TS.S.P.T.Basis.cond
                    and type P.T.Basis.div_rounding_mode = TS.S.P.T.Basis.div_rounding_mode
                    and type P.T.Basis.ext = TS.S.P.T.Basis.ext
                    and type P.T.Basis.fcond = TS.S.P.T.Basis.fcond
                    and type P.T.Basis.rounding_mode = TS.S.P.T.Basis.rounding_mode
                    and type P.T.Constant.const = TS.S.P.T.Constant.const
                    and type ('s,'r,'f,'c) P.T.Extension.ccx = ('s,'r,'f,'c) TS.S.P.T.Extension.ccx
                    and type ('s,'r,'f,'c) P.T.Extension.fx = ('s,'r,'f,'c) TS.S.P.T.Extension.fx
                    and type ('s,'r,'f,'c) P.T.Extension.rx = ('s,'r,'f,'c) TS.S.P.T.Extension.rx
                    and type ('s,'r,'f,'c) P.T.Extension.sx = ('s,'r,'f,'c) TS.S.P.T.Extension.sx
                    and type P.T.I.div_rounding_mode = TS.S.P.T.I.div_rounding_mode
                    and type P.T.Region.region = TS.S.P.T.Region.region
                    and type P.T.ccexp = TS.S.P.T.ccexp
                    and type P.T.fexp = TS.S.P.T.fexp
                    (* and type P.T.labexp = TS.S.P.T.labexp *)
                    and type P.T.mlrisc = TS.S.P.T.mlrisc
                    and type P.T.oper = TS.S.P.T.oper
                    and type P.T.rep = TS.S.P.T.rep
                    and type P.T.rexp = TS.S.P.T.rexp
                    and type P.T.stm = TS.S.P.T.stm

  type reducer = 
    (I.instruction, I.C.cellset, I.operand, I.addressing_mode, CFG.cfg) TS.reducer

  val compileSext : 
     reducer 
      -> {stm: (I.T.stm, I.T.rexp, I.T.fexp, I.T.ccexp) AMD64InstrExt.sext, 
	  an: I.T.an list} 
        -> unit
end


functor AMD64CompInstrExt
  ( structure I : AMD64INSTR
    structure TS  : MLTREE_STREAM (* where T = I.T *)
                    where type T.Basis.cond = I.T.Basis.cond
                      and type T.Basis.div_rounding_mode = I.T.Basis.div_rounding_mode
                      and type T.Basis.ext = I.T.Basis.ext
                      and type T.Basis.fcond = I.T.Basis.fcond
                      and type T.Basis.rounding_mode = I.T.Basis.rounding_mode
                      and type T.Constant.const = I.T.Constant.const
                      and type ('s,'r,'f,'c) T.Extension.ccx = ('s,'r,'f,'c) I.T.Extension.ccx
                      and type ('s,'r,'f,'c) T.Extension.fx = ('s,'r,'f,'c) I.T.Extension.fx
                      and type ('s,'r,'f,'c) T.Extension.rx = ('s,'r,'f,'c) I.T.Extension.rx
                      and type ('s,'r,'f,'c) T.Extension.sx = ('s,'r,'f,'c) I.T.Extension.sx
                      and type T.I.div_rounding_mode = I.T.I.div_rounding_mode
                      and type T.Region.region = I.T.Region.region
                      and type T.ccexp = I.T.ccexp
                      and type T.fexp = I.T.fexp
                      (* and type T.labexp = I.T.labexp *)
                      and type T.mlrisc = I.T.mlrisc
                      and type T.oper = I.T.oper
                      and type T.rep = I.T.rep
                      and type T.rexp = I.T.rexp
                      and type T.stm = I.T.stm
    structure CFG : CONTROL_FLOW_GRAPH (* where P = TS.S.P and I = I *)
                    where type P.Client.pseudo_op = TS.S.P.Client.pseudo_op
                      and type P.T.Basis.cond = TS.S.P.T.Basis.cond
                      and type P.T.Basis.div_rounding_mode = TS.S.P.T.Basis.div_rounding_mode
                      and type P.T.Basis.ext = TS.S.P.T.Basis.ext
                      and type P.T.Basis.fcond = TS.S.P.T.Basis.fcond
                      and type P.T.Basis.rounding_mode = TS.S.P.T.Basis.rounding_mode
                      and type P.T.Constant.const = TS.S.P.T.Constant.const
                      and type ('s,'r,'f,'c) P.T.Extension.ccx = ('s,'r,'f,'c) TS.S.P.T.Extension.ccx
                      and type ('s,'r,'f,'c) P.T.Extension.fx = ('s,'r,'f,'c) TS.S.P.T.Extension.fx
                      and type ('s,'r,'f,'c) P.T.Extension.rx = ('s,'r,'f,'c) TS.S.P.T.Extension.rx
                      and type ('s,'r,'f,'c) P.T.Extension.sx = ('s,'r,'f,'c) TS.S.P.T.Extension.sx
                      and type P.T.I.div_rounding_mode = TS.S.P.T.I.div_rounding_mode
                      and type P.T.Region.region = TS.S.P.T.Region.region
                      and type P.T.ccexp = TS.S.P.T.ccexp
                      and type P.T.fexp = TS.S.P.T.fexp
                      (* and type P.T.labexp = TS.S.P.T.labexp *)
                      and type P.T.mlrisc = TS.S.P.T.mlrisc
                      and type P.T.oper = TS.S.P.T.oper
                      and type P.T.rep = TS.S.P.T.rep
                      and type P.T.rexp = TS.S.P.T.rexp
                      and type P.T.stm = TS.S.P.T.stm
                    where type I.addressing_mode = I.addressing_mode
                      and type I.ea = I.ea
                      and type I.instr = I.instr
                      and type I.instruction = I.instruction
                      and type I.operand = I.operand
   ) : AMD64COMP_INSTR_EXT = 
struct
  structure CFG = CFG
  structure T = TS.T
  structure I = I
  structure C = I.C
  structure X = AMD64InstrExt
  structure TS = TS

  type stm = (T.stm, T.rexp, T.fexp, T.ccexp) X.sext

  type reducer = 
    (I.instruction, I.C.cellset, I.operand, I.addressing_mode, CFG.cfg) TS.reducer

  val rsp = C.rsp
  val rspOpnd = I.Direct(64,rsp)

  fun error msg = MLRiscErrorMsg.error("AMD64CompInstrExt", msg)

  val stackArea = I.Region.stack

  fun compileSext reducer {stm: stm, an:T.an list} = let
    val TS.REDUCER{operand, emit, reduceFexp, instrStream, reduceOperand,
                  ...} = reducer
    val TS.S.STREAM{emit=emitI, ...} = instrStream
    fun fstp(sz, fstpInstr, fexp) = 
      (case fexp
        of T.FREG(sz', f) =>
	    if sz <> sz' then error "fstp: sz"
	    else emitI(I.INSTR(fstpInstr(I.FDirect f)))
         | _ => error "fstp: fexp"
      (*esac*))
  in
    case stm
     of X.PUSHQ(rexp) => emit(I.pushq(operand rexp), an)
      | X.POP(rexp)   => emit(I.pop(operand rexp), an)
      | X.LEAVE	     => emit(I.leave, an)
      | X.RET(rexp)   => emit(I.ret(SOME(operand rexp)), an)
      | X.LOCK_XADDL (src, dst) => 
	   emit (I.xadd{
                 (* src must be in a register *)
                 lock=true,sz=I.I32,
                 src=I.Direct(32,reduceOperand(operand src)),
                 dst=operand dst},
	       an)
      | X.LOCK_XADDQ (src, dst) => 
	    emit (I.xadd{
		  (* src must be in a register *)
                  lock=true,sz=I.I64,
                  src=I.Direct(64,reduceOperand(operand src)),
                  dst=operand dst},
		  an)
      | X.LOCK_CMPXCHGL(src, dst) =>
	(* src must be in a register *)
	  emit(I.cmpxchg{
	      lock=true,sz=I.I32, 
	      src=I.Direct(32,reduceOperand(operand src)), 
	      dst=operand dst
	    }, an)
      | X.LOCK_CMPXCHGQ(src, dst) =>
	(* src must be in a register *)
	  emit(I.cmpxchg{
	      lock=true, sz=I.I64, 
	      src=I.Direct(64,reduceOperand(operand src)), 
	      dst=operand dst
	    }, an)
      | X.LOCK_XCHGL(src, dst) =>
	  emit(I.xchg{
	      lock=true,sz=I.I32, 
	      src=operand src,
	      dst=operand dst
	    }, an)
      | X.LOCK_XCHGQ(src, dst) =>
	  emit(I.xchg{
	      lock=true, sz=I.I64, 
	      src=operand src,
	      dst=operand dst
	    }, an)
      | X.PAUSE => emit(I.pause, an)
      | X.MFENCE => emit(I.mfence, an)
      | X.LFENCE => emit(I.lfence, an)
      | X.SFENCE => emit(I.sfence, an)
    (* end case *)
  end
end

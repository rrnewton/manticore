(* amd64-gen-fn.sml
 * 
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Glues together the AMD64-specific code with the code generator.  Also
 * specializes register spilling.
 *)

functor AMD64GenFn (
          structure Spec : TARGET_SPEC
) = struct

  structure C = AMD64Cells
  structure I = AMD64Instr

  structure AMD64Rewrite = AMD64Rewrite (AMD64Instr)
  structure AMD64FlowGraph = BuildFlowgraph (
                              structure Props = AMD64Props
                              structure Stream = AMD64Stream
			      structure CFG = AMD64CFG)

  structure AMD64SpillLoc = SpillLocFn (structure Frame=AMD64Frame)
  structure BlockPlacement = DefaultBlockPlacement (AMD64CFG)

  (* a function to get the frame annotation *)
  fun getFrameAn annotations = 
      (case #get AMD64SpillLoc.frameAn annotations
	of SOME frame => frame
	 | NONE => raise Fail "unable to get frame annotation"
      (* end case *))

  structure Emit = CFGEmit (
      structure CFG = AMD64CFG
      structure E = AMD64AsmEmit)
			       
  local
    datatype raPhase = SPILL_PROPAGATION | SPILL_COLORING
    datatype spillOperandKind = SPILL_LOC | CONST_VAL
    structure RASpill = RASpillWithRenaming (
	structure Asm = AMD64AsmEmit
	structure InsnProps = AMD64Props
	val max_dist = ref 4
	val keep_multiple_values = ref false)

    fun regLoc recordSpill (frame, loc) = 
	let val fsi = AMD64SpillLoc.frameSzInfo frame
	    val spillLoc = recordSpill (fsi, loc)
	in
	    I.Displace {
	    base = AMD64Regs.spReg, (* FIXME *)
	    disp = I.ImmedLabel (AMD64MLTree.CONST (AMD64Constant.StackLoc {
					       frame = fsi,
					       loc   = spillLoc
				})),
	    mem = ()
	    }
	end
    val gprLoc  = regLoc AMD64Frame.recordSpill
    val fprLoc  = regLoc AMD64Frame.recordFSpill
		  
    structure IntRA = struct
      val dedicated = AMD64Regs.dedicatedRegs
      val avail = AMD64Regs.availRegs
      val memRegs = []
      val phases = [SPILL_PROPAGATION,SPILL_COLORING]
      fun spillInit _ = ()
      fun spillLoc {info=frame, an, cell, id=loc} =
	  {opnd = gprLoc (frame, loc), kind = SPILL_LOC}
    end (* IntRA *)
    structure FloatRA = struct
      val avail     = []
      val dedicated = AMD64Regs.dedicatedFRegs (* empty *)
      val memRegs   = []
      val phases    = [SPILL_PROPAGATION]
      fun spillInit _ = ()
      fun spillLoc (frame, an, loc) = fprLoc (frame, loc)
      val fastMemRegs = []
      val fastPhases  = [SPILL_PROPAGATION,SPILL_COLORING]
    end (* FloatRA *)
  in
    structure RA = AMD64RA (
      structure I = AMD64Instr
      structure InsnProps = AMD64Props
      structure CFG = AMD64CFG
      structure Asm = AMD64AsmEmit
      structure SpillHeur = ChowHennessySpillHeur
      structure Spill = RASpill
      val fast_floating_point = ref false (* FIXME *)
      datatype raPhase = datatype raPhase
      datatype spillOperandKind = datatype spillOperandKind
      type spill_info = AMD64SpillLoc.frame
      fun beforeRA (Graph.GRAPH graph) = 
	  let val CFG.INFO{annotations, ...} = #graph_info graph
	  in
	      getFrameAn (!annotations)
	  end
      structure Int = IntRA
      structure Float = FloatRA)
  end (* local *)

  structure BackEnd : BACK_END = struct
    structure Spec = Spec
    structure ManticorePseudoOps = AMD64PseudoOps
    structure MLTreeComp = AMD64MLTreeComp
    structure MLTreeUtils = AMD64MLTreeUtils
    structure CFGGen = AMD64FlowGraph
    structure MTy = MLRiscTypesFn (
                     structure Spec = Spec
		     structure T = AMD64MLTree ) 


    structure Regs = AMD64Regs

    fun compileCFG (cfg as Graph.GRAPH graph) = 
	let val CFGGen.CFG.INFO{annotations, ...} = #graph_info graph
	in 
	    case (#get AMD64SpillLoc.frameAn) (!annotations)
	     of NONE => Emit.asmEmit (cfg, #nodes graph ())
	      | SOME frame => 
		let val cfg = RA.run cfg
		    val (cfg, blocks) = BlockPlacement.blockPlacement cfg
		in
		    Emit.asmEmit (cfg, blocks)
		end
	end (* compileCFG *)
  end (* BackEnd *)

  structure Gen = CodeGenFn (BackEnd)

end (* AMD64CG *)

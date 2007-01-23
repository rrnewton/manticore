(* amd64-const.sml
 * 
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 *)

structure AMD64Constant = struct

  datatype const = StackLoc of { frame : AMD64Frame.frame_sz_info,
				 loc : AMD64Frame.loc }

  fun toString _ = ""
  fun valueOf _ = 0
  fun hash _ = 0w0
  fun == _ = true

end (* AMD64Const *)

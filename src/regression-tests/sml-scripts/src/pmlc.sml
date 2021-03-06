(* pmlc.sml
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 *)

structure PMLC : COMPILER =
  struct
    val languageName = "pml"
    val c = ref "pmlc"
    fun getCompilerPath () = valOf (Utils.which (!c))
    fun setCompilerPath p = (c := p)
    val ext = "pml"
    fun mkExe infile = "a.out"
    fun mkCmd infile = String.concat [!c, " ", infile, " 2> /dev/null"]
    fun detritus infile = [OS.Path.base infile ^ ".s"]
  end


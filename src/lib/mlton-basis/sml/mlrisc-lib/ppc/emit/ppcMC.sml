(*
 * WARNING: This file was automatically generated by MDLGen (v3.0)
 * from the machine description file "ppc/ppc.mdl".
 * DO NOT EDIT this file directly
 *)


functor PPCMCEmitter(structure Instr : PPCINSTR
                     structure MLTreeEval : MLTREE_EVAL (* where T = Instr.T *)
                                            where type T.Basis.cond = Instr.T.Basis.cond
                                              and type T.Basis.div_rounding_mode = Instr.T.Basis.div_rounding_mode
                                              and type T.Basis.ext = Instr.T.Basis.ext
                                              and type T.Basis.fcond = Instr.T.Basis.fcond
                                              and type T.Basis.rounding_mode = Instr.T.Basis.rounding_mode
                                              and type T.Constant.const = Instr.T.Constant.const
                                              and type ('s,'r,'f,'c) T.Extension.ccx = ('s,'r,'f,'c) Instr.T.Extension.ccx
                                              and type ('s,'r,'f,'c) T.Extension.fx = ('s,'r,'f,'c) Instr.T.Extension.fx
                                              and type ('s,'r,'f,'c) T.Extension.rx = ('s,'r,'f,'c) Instr.T.Extension.rx
                                              and type ('s,'r,'f,'c) T.Extension.sx = ('s,'r,'f,'c) Instr.T.Extension.sx
                                              and type T.I.div_rounding_mode = Instr.T.I.div_rounding_mode
                                              and type T.Region.region = Instr.T.Region.region
                                              and type T.ccexp = Instr.T.ccexp
                                              and type T.fexp = Instr.T.fexp
                                              (* and type T.labexp = Instr.T.labexp *)
                                              and type T.mlrisc = Instr.T.mlrisc
                                              and type T.oper = Instr.T.oper
                                              and type T.rep = Instr.T.rep
                                              and type T.rexp = Instr.T.rexp
                                              and type T.stm = Instr.T.stm
                     structure Stream : INSTRUCTION_STREAM 
                     structure CodeString : CODE_STRING
                    ) : INSTRUCTION_EMITTER =
struct
   structure I = Instr
   structure C = I.C
   structure Constant = I.Constant
   structure T = I.T
   structure S = Stream
   structure P = S.P
   structure W = Word32
   
   (* PPC is big endian *)
   
   fun error msg = MLRiscErrorMsg.error("PPCMC",msg)
   fun makeStream _ =
   let infix && || << >> ~>>
       val op << = W.<<
       val op >> = W.>>
       val op ~>> = W.~>>
       val op || = W.orb
       val op && = W.andb
       val itow = W.fromInt
       fun emit_bool false = 0w0 : W.word
         | emit_bool true = 0w1 : W.word
       val emit_int = itow
       fun emit_word w = w
       fun emit_label l = itow(Label.addrOf l)
       fun emit_labexp le = itow(MLTreeEval.valueOf le)
       fun emit_const c = itow(Constant.valueOf c)
       val loc = ref 0
   
       (* emit a byte *)
       fun eByte b =
       let val i = !loc in loc := i + 1; CodeString.update(i,b) end
   
       (* emit the low order byte of a word *)
       (* note: fromLargeWord strips the high order bits! *)
       fun eByteW w =
       let val i = !loc
           val w = W.toLargeWord w
       in loc := i + 1; CodeString.update(i,Word8.fromLargeWord w) end
   
       fun doNothing _ = ()
       fun fail _ = raise Fail "MCEmitter"
       fun getAnnotations () = error "getAnnotations"
   
       fun pseudoOp pOp = P.emitValue{pOp=pOp, loc= !loc,emit=eByte}
   
       fun init n = (CodeString.init n; loc := 0)
   
   
   fun eWord32 w = 
       let val b8 = w
           val w = w >> 0wx8
           val b16 = w
           val w = w >> 0wx8
           val b24 = w
           val w = w >> 0wx8
           val b32 = w
       in 
          ( eByteW b32; 
            eByteW b24; 
            eByteW b16; 
            eByteW b8 )
       end
   fun emit_GP r = itow (CellsBasis.physicalRegisterNum r)
   and emit_FP r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CC r = itow (CellsBasis.physicalRegisterNum r)
   and emit_SPR r = itow (CellsBasis.physicalRegisterNum r)
   and emit_MEM r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CTRL r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CELLSET r = itow (CellsBasis.physicalRegisterNum r)
   fun emit_operand (I.RegOp GP) = emit_GP GP
     | emit_operand (I.ImmedOp int) = itow int
     | emit_operand (I.LabelOp labexp) = itow (MLTreeEval.valueOf labexp)
   and emit_fcmp (I.FCMPO) = (0wx20 : Word32.word)
     | emit_fcmp (I.FCMPU) = (0wx0 : Word32.word)
   and emit_unary (I.NEG) = (0wx68 : Word32.word)
     | emit_unary (I.EXTSB) = (0wx3BA : Word32.word)
     | emit_unary (I.EXTSH) = (0wx39A : Word32.word)
     | emit_unary (I.EXTSW) = (0wx3DA : Word32.word)
     | emit_unary (I.CNTLZW) = (0wx1A : Word32.word)
     | emit_unary (I.CNTLZD) = (0wx3A : Word32.word)
   and emit_funary (I.FMR) = (0wx3F, 0wx48)
     | emit_funary (I.FNEG) = (0wx3F, 0wx28)
     | emit_funary (I.FABS) = (0wx3F, 0wx108)
     | emit_funary (I.FNABS) = (0wx3F, 0wx88)
     | emit_funary (I.FSQRT) = (0wx3F, 0wx16)
     | emit_funary (I.FSQRTS) = (0wx3B, 0wx16)
     | emit_funary (I.FRSP) = (0wx3F, 0wxC)
     | emit_funary (I.FCTIW) = (0wx3F, 0wxE)
     | emit_funary (I.FCTIWZ) = (0wx3F, 0wxF)
     | emit_funary (I.FCTID) = (0wx3F, 0wx32E)
     | emit_funary (I.FCTIDZ) = (0wx3F, 0wx32F)
     | emit_funary (I.FCFID) = (0wx3F, 0wx34E)
   and emit_farith (I.FADD) = (0wx3F, 0wx15)
     | emit_farith (I.FSUB) = (0wx3F, 0wx14)
     | emit_farith (I.FMUL) = (0wx3F, 0wx19)
     | emit_farith (I.FDIV) = (0wx3F, 0wx12)
     | emit_farith (I.FADDS) = (0wx3B, 0wx15)
     | emit_farith (I.FSUBS) = (0wx3B, 0wx14)
     | emit_farith (I.FMULS) = (0wx3B, 0wx19)
     | emit_farith (I.FDIVS) = (0wx3B, 0wx12)
   and emit_farith3 (I.FMADD) = (0wx3F, 0wx1D)
     | emit_farith3 (I.FMADDS) = (0wx3B, 0wx1D)
     | emit_farith3 (I.FMSUB) = (0wx3F, 0wx1C)
     | emit_farith3 (I.FMSUBS) = (0wx3B, 0wx1C)
     | emit_farith3 (I.FNMADD) = (0wx3F, 0wx1F)
     | emit_farith3 (I.FNMADDS) = (0wx3B, 0wx1F)
     | emit_farith3 (I.FNMSUB) = (0wx3F, 0wx1E)
     | emit_farith3 (I.FNMSUBS) = (0wx3B, 0wx1E)
     | emit_farith3 (I.FSEL) = (0wx3F, 0wx17)
   and emit_bo (I.TRUE) = (0wxC : Word32.word)
     | emit_bo (I.FALSE) = (0wx4 : Word32.word)
     | emit_bo (I.ALWAYS) = (0wx14 : Word32.word)
     | emit_bo (I.COUNTER{eqZero, cond}) = 
       (case cond of
         NONE => (if eqZero
            then 0wx12
            else 0wx10)
       | SOME cc => 
         (case (eqZero, cc) of
           (false, false) => 0wx0
         | (false, true) => 0wx8
         | (true, false) => 0wx2
         | (true, true) => 0wxA
         )
       )
   and emit_arith (I.ADD) = (0wx10A : Word32.word)
     | emit_arith (I.SUBF) = (0wx28 : Word32.word)
     | emit_arith (I.MULLW) = (0wxEB : Word32.word)
     | emit_arith (I.MULLD) = (0wxE9 : Word32.word)
     | emit_arith (I.MULHW) = (0wx4B : Word32.word)
     | emit_arith (I.MULHWU) = (0wxB : Word32.word)
     | emit_arith (I.DIVW) = (0wx1EB : Word32.word)
     | emit_arith (I.DIVD) = (0wx1E9 : Word32.word)
     | emit_arith (I.DIVWU) = (0wx1CB : Word32.word)
     | emit_arith (I.DIVDU) = (0wx1C9 : Word32.word)
     | emit_arith (I.AND) = (0wx1C : Word32.word)
     | emit_arith (I.OR) = (0wx1BC : Word32.word)
     | emit_arith (I.XOR) = (0wx13C : Word32.word)
     | emit_arith (I.NAND) = (0wx1DC : Word32.word)
     | emit_arith (I.NOR) = (0wx7C : Word32.word)
     | emit_arith (I.EQV) = (0wx11C : Word32.word)
     | emit_arith (I.ANDC) = (0wx3C : Word32.word)
     | emit_arith (I.ORC) = (0wx19C : Word32.word)
     | emit_arith (I.SLW) = (0wx18 : Word32.word)
     | emit_arith (I.SLD) = (0wx1B : Word32.word)
     | emit_arith (I.SRW) = (0wx218 : Word32.word)
     | emit_arith (I.SRD) = (0wx21B : Word32.word)
     | emit_arith (I.SRAW) = (0wx318 : Word32.word)
     | emit_arith (I.SRAD) = (0wx31A : Word32.word)
   and emit_arithi (I.ADDI) = (0wxE : Word32.word)
     | emit_arithi (I.ADDIS) = (0wxF : Word32.word)
     | emit_arithi (I.SUBFIC) = (0wx8 : Word32.word)
     | emit_arithi (I.MULLI) = (0wx7 : Word32.word)
     | emit_arithi (I.ANDI_Rc) = (0wx1C : Word32.word)
     | emit_arithi (I.ANDIS_Rc) = (0wx1D : Word32.word)
     | emit_arithi (I.ORI) = (0wx18 : Word32.word)
     | emit_arithi (I.ORIS) = (0wx19 : Word32.word)
     | emit_arithi (I.XORI) = (0wx1A : Word32.word)
     | emit_arithi (I.XORIS) = (0wx1B : Word32.word)
     | emit_arithi (I.SRAWI) = error "SRAWI"
     | emit_arithi (I.SRADI) = error "SRADI"
   and emit_ccarith (I.CRAND) = (0wx101 : Word32.word)
     | emit_ccarith (I.CROR) = (0wx1C1 : Word32.word)
     | emit_ccarith (I.CRXOR) = (0wxC1 : Word32.word)
     | emit_ccarith (I.CRNAND) = (0wxE1 : Word32.word)
     | emit_ccarith (I.CRNOR) = (0wx21 : Word32.word)
     | emit_ccarith (I.CREQV) = (0wx121 : Word32.word)
     | emit_ccarith (I.CRANDC) = (0wx81 : Word32.word)
     | emit_ccarith (I.CRORC) = (0wx1A1 : Word32.word)
   fun x_form {opcd, rt, ra, rb, xo, rc} = 
       let val rc = emit_bool rc
       in eWord32 ((opcd << 0wx1A) + ((rt << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((xo << 0wx1) + rc)))))
       end
   and xl_form {opcd, bt, ba, bb, xo, lk} = 
       let val lk = emit_bool lk
       in eWord32 ((opcd << 0wx1A) + ((bt << 0wx15) + ((ba << 0wx10) + ((bb << 0wxB) + ((xo << 0wx1) + lk)))))
       end
   and m_form {opcd, rs, ra, rb, mb, me, rc} = 
       let val rc = emit_bool rc
       in eWord32 ((opcd << 0wx1A) + ((rs << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((mb << 0wx6) + ((me << 0wx1) + rc))))))
       end
   and a_form {opcd, frt, fra, frb, frc, xo, rc} = 
       let val rc = emit_bool rc
       in eWord32 ((opcd << 0wx1A) + ((frt << 0wx15) + ((fra << 0wx10) + ((frb << 0wxB) + ((frc << 0wx6) + ((xo << 0wx1) + rc))))))
       end
   and loadx {rt, ra, rb, xop} = 
       let val rt = emit_GP rt
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((rt << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((xop << 0wx1) + 0wx7C000000))))
       end
   and loadd {opcd, rt, ra, d} = 
       let val rt = emit_GP rt
           val ra = emit_GP ra
           val d = emit_operand d
       in eWord32 ((opcd << 0wx1A) + ((rt << 0wx15) + ((ra << 0wx10) + (d && 0wxFFFF))))
       end
   and loadde {opcd, rt, ra, de, xop} = 
       let val rt = emit_GP rt
           val ra = emit_GP ra
           val de = emit_operand de
       in eWord32 ((opcd << 0wx1A) + ((rt << 0wx15) + ((ra << 0wx10) + (((de && 0wxFFF) << 0wx4) + xop))))
       end
   and load {ld, rt, ra, d} = 
       (case (d, ld) of
         (I.RegOp rb, I.LBZ) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx57}
       | (I.RegOp rb, I.LBZE) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx5F}
       | (I.RegOp rb, I.LHZ) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx117}
       | (I.RegOp rb, I.LHZE) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx11F}
       | (I.RegOp rb, I.LHA) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx157}
       | (I.RegOp rb, I.LHAE) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx15F}
       | (I.RegOp rb, I.LWZ) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx17}
       | (I.RegOp rb, I.LWZE) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx1F}
       | (I.RegOp rb, I.LDE) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx31F}
       | (d, I.LBZ) => loadd {opcd=0wx22, rt=rt, ra=ra, d=d}
       | (de, I.LBZE) => loadde {opcd=0wx3A, rt=rt, ra=ra, de=de, xop=0wx0}
       | (d, I.LHZ) => loadd {opcd=0wx28, rt=rt, ra=ra, d=d}
       | (de, I.LHZE) => loadde {opcd=0wx3A, rt=rt, ra=ra, de=de, xop=0wx2}
       | (d, I.LHA) => loadd {opcd=0wx2A, rt=rt, ra=ra, d=d}
       | (de, I.LHAE) => loadde {opcd=0wx3A, rt=rt, ra=ra, de=de, xop=0wx4}
       | (d, I.LWZ) => loadd {opcd=0wx20, rt=rt, ra=ra, d=d}
       | (de, I.LWZE) => loadde {opcd=0wx3A, rt=rt, ra=ra, de=de, xop=0wx6}
       | (de, I.LDE) => loadde {opcd=0wx3E, rt=rt, ra=ra, de=de, xop=0wx0}
       | (I.RegOp rb, I.LHAU) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx177}
       | (I.RegOp rb, I.LHZU) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx137}
       | (I.RegOp rb, I.LWZU) => loadx {rt=rt, ra=ra, rb=rb, xop=0wx37}
       | (d, I.LHZU) => loadd {opcd=0wx29, rt=rt, ra=ra, d=d}
       | (d, I.LWZU) => loadd {opcd=0wx21, rt=rt, ra=ra, d=d}
       )
   and floadx {ft, ra, rb, xop} = 
       let val ft = emit_FP ft
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((ft << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((xop << 0wx1) + 0wx7C000000))))
       end
   and floadd {opcd, ft, ra, d} = 
       let val ft = emit_FP ft
           val ra = emit_GP ra
           val d = emit_operand d
       in eWord32 ((opcd << 0wx1A) + ((ft << 0wx15) + ((ra << 0wx10) + (d && 0wxFFFF))))
       end
   and floadde {opcd, ft, ra, de, xop} = 
       let val ft = emit_FP ft
           val ra = emit_GP ra
           val de = emit_operand de
       in eWord32 ((opcd << 0wx1A) + ((ft << 0wx15) + ((ra << 0wx10) + (((de && 0wxFFF) << 0wx4) + xop))))
       end
   and fload {ld, ft, ra, d} = 
       (case (d, ld) of
         (I.RegOp rb, I.LFS) => floadx {ft=ft, ra=ra, rb=rb, xop=0wx217}
       | (I.RegOp rb, I.LFSE) => floadx {ft=ft, ra=ra, rb=rb, xop=0wx21F}
       | (I.RegOp rb, I.LFD) => floadx {ft=ft, ra=ra, rb=rb, xop=0wx257}
       | (I.RegOp rb, I.LFDE) => floadx {ft=ft, ra=ra, rb=rb, xop=0wx25F}
       | (I.RegOp rb, I.LFDU) => floadx {ft=ft, ra=ra, rb=rb, xop=0wx277}
       | (d, I.LFS) => floadd {ft=ft, ra=ra, d=d, opcd=0wx30}
       | (de, I.LFSE) => floadde {ft=ft, ra=ra, de=de, opcd=0wx3E, xop=0wx4}
       | (d, I.LFD) => floadd {ft=ft, ra=ra, d=d, opcd=0wx32}
       | (de, I.LFDE) => floadde {ft=ft, ra=ra, de=de, opcd=0wx3E, xop=0wx6}
       | (d, I.LFDU) => floadd {ft=ft, ra=ra, d=d, opcd=0wx33}
       )
   and storex {rs, ra, rb, xop} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((xop << 0wx1) + 0wx7C000000))))
       end
   and stored {opcd, rs, ra, d} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val d = emit_operand d
       in eWord32 ((opcd << 0wx1A) + ((rs << 0wx15) + ((ra << 0wx10) + (d && 0wxFFFF))))
       end
   and storede {opcd, rs, ra, de, xop} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val de = emit_operand de
       in eWord32 ((opcd << 0wx1A) + ((rs << 0wx15) + ((ra << 0wx10) + (((de && 0wxFFF) << 0wx4) + xop))))
       end
   and store {st, rs, ra, d} = 
       (case (d, st) of
         (I.RegOp rb, I.STB) => storex {rs=rs, ra=ra, rb=rb, xop=0wxD7}
       | (I.RegOp rb, I.STBE) => storex {rs=rs, ra=ra, rb=rb, xop=0wxDF}
       | (I.RegOp rb, I.STH) => storex {rs=rs, ra=ra, rb=rb, xop=0wx197}
       | (I.RegOp rb, I.STHE) => storex {rs=rs, ra=ra, rb=rb, xop=0wx19F}
       | (I.RegOp rb, I.STW) => storex {rs=rs, ra=ra, rb=rb, xop=0wx97}
       | (I.RegOp rb, I.STWE) => storex {rs=rs, ra=ra, rb=rb, xop=0wx9F}
       | (I.RegOp rb, I.STDE) => storex {rs=rs, ra=ra, rb=rb, xop=0wx39F}
       | (d, I.STB) => stored {rs=rs, ra=ra, d=d, opcd=0wx26}
       | (de, I.STBE) => storede {rs=rs, ra=ra, de=de, opcd=0wx3A, xop=0wx8}
       | (d, I.STH) => stored {rs=rs, ra=ra, d=d, opcd=0wx2C}
       | (de, I.STHE) => storede {rs=rs, ra=ra, de=de, opcd=0wx3A, xop=0wxA}
       | (d, I.STW) => stored {rs=rs, ra=ra, d=d, opcd=0wx24}
       | (de, I.STWE) => storede {rs=rs, ra=ra, de=de, opcd=0wx3A, xop=0wxE}
       | (de, I.STDE) => storede {rs=rs, ra=ra, de=de, opcd=0wx3E, xop=0wx8}
       )
   and fstorex {fs, ra, rb, xop} = 
       let val fs = emit_FP fs
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((fs << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((xop << 0wx1) + 0wx7C000000))))
       end
   and fstored {opcd, fs, ra, d} = 
       let val fs = emit_FP fs
           val ra = emit_GP ra
           val d = emit_operand d
       in eWord32 ((opcd << 0wx1A) + ((fs << 0wx15) + ((ra << 0wx10) + (d && 0wxFFFF))))
       end
   and fstorede {opcd, fs, ra, de, xop} = 
       let val fs = emit_FP fs
           val ra = emit_GP ra
           val de = emit_operand de
       in eWord32 ((opcd << 0wx1A) + ((fs << 0wx15) + ((ra << 0wx10) + (((de && 0wxFFF) << 0wx4) + xop))))
       end
   and fstore {st, fs, ra, d} = 
       (case (d, st) of
         (I.RegOp rb, I.STFS) => fstorex {fs=fs, ra=ra, rb=rb, xop=0wx297}
       | (I.RegOp rb, I.STFSE) => fstorex {fs=fs, ra=ra, rb=rb, xop=0wx29F}
       | (I.RegOp rb, I.STFD) => fstorex {fs=fs, ra=ra, rb=rb, xop=0wx2D7}
       | (I.RegOp rb, I.STFDE) => fstorex {fs=fs, ra=ra, rb=rb, xop=0wx2F7}
       | (d, I.STFS) => fstored {fs=fs, ra=ra, d=d, opcd=0wx34}
       | (de, I.STFSE) => fstorede {fs=fs, ra=ra, de=de, opcd=0wx3E, xop=0wxC}
       | (d, I.STFD) => fstored {fs=fs, ra=ra, d=d, opcd=0wx36}
       | (de, I.STFDE) => fstorede {fs=fs, ra=ra, de=de, opcd=0wx3E, xop=0wxE}
       )
   and unary' {ra, rt, OE, oper, Rc} = 
       let val ra = emit_GP ra
           val rt = emit_GP rt
           val OE = emit_bool OE
           val oper = emit_unary oper
           val Rc = emit_bool Rc
       in eWord32 ((ra << 0wx15) + ((rt << 0wx10) + ((OE << 0wxA) + ((oper << 0wx1) + (Rc + 0wx7C000000)))))
       end
   and unary {ra, rt, oper, OE, Rc} = 
       (case oper of
         I.NEG => unary' {ra=rt, rt=ra, oper=oper, OE=OE, Rc=Rc}
       | _ => unary' {ra=ra, rt=rt, oper=oper, OE=OE, Rc=Rc}
       )
   and arith' {rt, ra, rb, OE, oper, Rc} = 
       let val rt = emit_GP rt
           val ra = emit_GP ra
           val rb = emit_GP rb
           val OE = emit_bool OE
           val oper = emit_arith oper
           val Rc = emit_bool Rc
       in eWord32 ((rt << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + ((OE << 0wxA) + ((oper << 0wx1) + (Rc + 0wx7C000000))))))
       end
   and arithi' {oper, rt, ra, im} = 
       let val oper = emit_arithi oper
           val rt = emit_GP rt
           val ra = emit_GP ra
           val im = emit_operand im
       in eWord32 ((oper << 0wx1A) + ((rt << 0wx15) + ((ra << 0wx10) + (im && 0wxFFFF))))
       end
   and srawi {rs, ra, sh} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val sh = emit_operand sh
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + (((sh && 0wx1F) << 0wxB) + 0wx7C000670)))
       end
   and sradi' {rs, ra, sh, sh2} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((sh2 << 0wx1) + 0wx7C000674))))
       end
   and sradi {rs, ra, sh} = 
       let val sh = emit_operand sh
       in sradi' {rs=rs, ra=ra, sh=(sh && 0wx1F), sh2=((sh << 0wx5) && 0wx1)}
       end
   and arith {oper, rt, ra, rb, OE, Rc} = 
       (case oper of
         I.ADD => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.SUBF => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.MULLW => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.MULLD => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.MULHW => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.MULHWU => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.DIVW => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.DIVD => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.DIVWU => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | I.DIVDU => arith' {oper=oper, rt=rt, ra=ra, rb=rb, OE=OE, Rc=Rc}
       | _ => arith' {oper=oper, rt=ra, ra=rt, rb=rb, OE=OE, Rc=Rc}
       )
   and arithi {oper, rt, ra, im} = 
       (case oper of
         I.ADDI => arithi' {oper=oper, rt=rt, ra=ra, im=im}
       | I.ADDIS => arithi' {oper=oper, rt=rt, ra=ra, im=im}
       | I.SUBFIC => arithi' {oper=oper, rt=rt, ra=ra, im=im}
       | I.MULLI => arithi' {oper=oper, rt=rt, ra=ra, im=im}
       | I.SRAWI => srawi {rs=ra, ra=rt, sh=im}
       | I.SRADI => sradi {rs=ra, ra=rt, sh=im}
       | _ => arithi' {oper=oper, rt=ra, ra=rt, im=im}
       )
   and Cmpl {bf, l, ra, rb} = 
       let val bf = emit_CC bf
           val l = emit_bool l
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((bf << 0wx17) + ((l << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C000040))))
       end
   and Cmpli {bf, l, ra, ui} = 
       let val bf = emit_CC bf
           val l = emit_bool l
           val ra = emit_GP ra
           val ui = emit_operand ui
       in eWord32 ((bf << 0wx17) + ((l << 0wx15) + ((ra << 0wx10) + ((ui && 0wxFFFF) + 0wx28000000))))
       end
   and Cmp {bf, l, ra, rb} = 
       let val bf = emit_CC bf
           val l = emit_bool l
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((bf << 0wx17) + ((l << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C000000))))
       end
   and Cmpi {bf, l, ra, si} = 
       let val bf = emit_CC bf
           val l = emit_bool l
           val ra = emit_GP ra
           val si = emit_operand si
       in eWord32 ((bf << 0wx17) + ((l << 0wx15) + ((ra << 0wx10) + ((si && 0wxFFFF) + 0wx2C000000))))
       end
   and compare {cmp, bf, l, ra, rb} = 
       (case (cmp, rb) of
         (I.CMP, I.RegOp rb) => Cmp {bf=bf, l=l, ra=ra, rb=rb}
       | (I.CMPL, I.RegOp rb) => Cmpl {bf=bf, l=l, ra=ra, rb=rb}
       | (I.CMP, si) => Cmpi {bf=bf, l=l, ra=ra, si=si}
       | (I.CMPL, ui) => Cmpli {bf=bf, l=l, ra=ra, ui=ui}
       )
   and fcmp {bf, fa, fb, cmp} = 
       let val bf = emit_CC bf
           val fa = emit_FP fa
           val fb = emit_FP fb
           val cmp = emit_fcmp cmp
       in eWord32 ((bf << 0wx17) + ((fa << 0wx10) + ((fb << 0wxB) + ((cmp << 0wx1) + 0wxFC000000))))
       end
   and funary {oper, ft, fb, Rc} = 
       let val oper = emit_funary oper
           val ft = emit_FP ft
           val fb = emit_FP fb
       in 
          let 
(*#line 455.12 "ppc/ppc.mdl"*)
              val (opcd, xo) = oper
          in 
             (case oper of
               (0wx3F, 0wx16) => a_form {opcd=opcd, frt=ft, fra=0wx0, frb=fb, 
                  frc=0wx0, xo=xo, rc=Rc}
             | (0wx3B, 0wx16) => a_form {opcd=opcd, frt=ft, fra=0wx0, frb=fb, 
                  frc=0wx0, xo=xo, rc=Rc}
             | _ => x_form {opcd=opcd, rt=ft, ra=0wx0, rb=fb, xo=xo, rc=Rc}
             )
          end
       end
   and farith {oper, ft, fa, fb, Rc} = 
       let val ft = emit_FP ft
           val fa = emit_FP fa
           val fb = emit_FP fb
       in 
          let 
(*#line 468.12 "ppc/ppc.mdl"*)
              val (opcd, xo) = emit_farith oper
          in 
             (case oper of
               I.FMUL => a_form {opcd=opcd, frt=ft, fra=fa, frb=0wx0, frc=fb, xo=xo, rc=Rc}
             | I.FMULS => a_form {opcd=opcd, frt=ft, fra=fa, frb=0wx0, frc=fb, xo=xo, rc=Rc}
             | _ => a_form {opcd=opcd, frt=ft, fra=fa, frb=fb, frc=0wx0, xo=xo, 
                  rc=Rc}
             )
          end
       end
   and farith3 {oper, ft, fa, fc, fb, Rc} = 
       let val oper = emit_farith3 oper
           val ft = emit_FP ft
           val fa = emit_FP fa
           val fc = emit_FP fc
           val fb = emit_FP fb
       in 
          let 
(*#line 477.12 "ppc/ppc.mdl"*)
              val (opcd, xo) = oper
          in a_form {opcd=opcd, frt=ft, fra=fa, frb=fb, frc=fc, xo=xo, rc=Rc}
          end
       end
   and cr_bit {cc} = 
       let 
(*#line 482.12 "ppc/ppc.mdl"*)
           val (cr, bit) = cc
       in ((emit_CC cr) << 0wx2) + (itow 
          (case bit of
            I.LT => 0
          | I.GT => 1
          | I.EQ => 2
          | I.SO => 3
          | I.FL => 0
          | I.FG => 1
          | I.FE => 2
          | I.FU => 3
          | I.FX => 0
          | I.FEX => 1
          | I.VX => 2
          | I.OX => 3
          ))
       end
   and ccarith {oper, bt, ba, bb} = 
       let val oper = emit_ccarith oper
       in xl_form {opcd=0wx13, bt=cr_bit {cc=bt}, ba=cr_bit {cc=ba}, bb=cr_bit {cc=bb}, 
             xo=oper, lk=false}
       end
   and twr {to, ra, rb} = 
       let val to = emit_int to
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((to << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C000008)))
       end
   and twi {to, ra, si} = 
       let val to = emit_int to
           val ra = emit_GP ra
           val si = emit_operand si
       in eWord32 ((to << 0wx15) + ((ra << 0wx10) + ((si && 0wxFFFF) + 0wxC000000)))
       end
   and tw {to, ra, si} = 
       (case si of
         I.RegOp rb => twr {to=to, ra=ra, rb=rb}
       | _ => twi {to=to, ra=ra, si=si}
       )
   and tdr {to, ra, rb} = 
       let val to = emit_int to
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((to << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C000088)))
       end
   and tdi {to, ra, si} = 
       let val to = emit_int to
           val ra = emit_GP ra
           val si = emit_operand si
       in eWord32 ((to << 0wx15) + ((ra << 0wx10) + ((si && 0wxFFFF) + 0wx8000000)))
       end
   and td {to, ra, si} = 
       (case si of
         I.RegOp rb => tdr {to=to, ra=ra, rb=rb}
       | _ => tdi {to=to, ra=ra, si=si}
       )
   and mcrf {bf, bfa} = 
       let val bf = emit_CC bf
           val bfa = emit_CC bfa
       in eWord32 ((bf << 0wx17) + ((bfa << 0wx12) + 0wx4C000000))
       end
   and mtspr' {rs, spr} = 
       let val rs = emit_GP rs
       in eWord32 ((rs << 0wx15) + ((spr << 0wxB) + 0wx7C0003A6))
       end
   and mtspr {rs, spr} = 
       let val spr = emit_SPR spr
       in mtspr' {rs=rs, spr=((spr && 0wx1F) << 0wx5) + ((spr << 0wx5) && 0wx1F)}
       end
   and mfspr' {rt, spr} = 
       let val rt = emit_GP rt
       in eWord32 ((rt << 0wx15) + ((spr << 0wxB) + 0wx7C0002A6))
       end
   and mfspr {rt, spr} = 
       let val spr = emit_SPR spr
       in mfspr' {rt=rt, spr=((spr && 0wx1F) << 0wx5) + ((spr << 0wx5) && 0wx1F)}
       end
   and b {li, aa, lk} = 
       let val aa = emit_bool aa
           val lk = emit_bool lk
       in eWord32 (((li && 0wxFFFFFF) << 0wx2) + ((aa << 0wx1) + (lk + 0wx48000000)))
       end
   and be {li, aa, lk} = 
       let val aa = emit_bool aa
           val lk = emit_bool lk
       in eWord32 (((li && 0wxFFFFFF) << 0wx2) + ((aa << 0wx1) + (lk + 0wx58000000)))
       end
   and bc {bo, bi, bd, aa, lk} = 
       let val bo = emit_bo bo
           val aa = emit_bool aa
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (((bd && 0wx3FFF) << 0wx2) + ((aa << 0wx1) + (lk + 0wx40000000)))))
       end
   and bce {bo, bi, bd, aa, lk} = 
       let val bo = emit_bo bo
           val aa = emit_bool aa
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (((bd && 0wx3FFF) << 0wx2) + ((aa << 0wx1) + (lk + 0wx40000000)))))
       end
   and bclr {bo, bi, lk} = 
       let val bo = emit_bo bo
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (lk + 0wx4C000020)))
       end
   and bclre {bo, bi, lk} = 
       let val bo = emit_bo bo
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (lk + 0wx4C000022)))
       end
   and bcctr {bo, bi, lk} = 
       let val bo = emit_bo bo
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (lk + 0wx4C000420)))
       end
   and bcctre {bo, bi, lk} = 
       let val bo = emit_bo bo
           val lk = emit_bool lk
       in eWord32 ((bo << 0wx15) + ((bi << 0wx10) + (lk + 0wx4C000422)))
       end
   and rlwnm {rs, ra, sh, mb, me} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val sh = emit_GP sh
           val mb = emit_int mb
           val me = emit_int me
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((me << 0wx1) + 0wx5C000000)))))
       end
   and rlwinm {rs, ra, sh, mb, me} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
           val me = emit_int me
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((me << 0wx1) + 0wx54000000)))))
       end
   and rldcl {rs, ra, sh, mb} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val sh = emit_GP sh
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + 0wx78000010))))
       end
   and rldicl {rs, ra, sh, mb, sh2} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((sh2 << 0wx1) + 0wx78000000)))))
       end
   and rldcr {rs, ra, sh, mb} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val sh = emit_GP sh
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + 0wx78000012))))
       end
   and rldicr {rs, ra, sh, mb, sh2} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((sh2 << 0wx1) + 0wx78000004)))))
       end
   and rldic {rs, ra, sh, mb, sh2} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((sh2 << 0wx1) + 0wx78000008)))))
       end
   and rlwimi {rs, ra, sh, mb, me} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
           val me = emit_int me
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((me << 0wx1) + 0wx50000000)))))
       end
   and rldimi {rs, ra, sh, mb, sh2} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val mb = emit_int mb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((sh << 0wxB) + ((mb << 0wx6) + ((sh2 << 0wx1) + 0wx7800000C)))))
       end
   and rotate {oper, ra, rs, sh, mb, me} = 
       (case (oper, me) of
         (I.RLWNM, SOME me) => rlwnm {ra=ra, rs=rs, sh=sh, mb=mb, me=me}
       | (I.RLDCL, _) => rldcl {ra=ra, rs=rs, sh=sh, mb=mb}
       | (I.RLDCR, _) => rldcr {ra=ra, rs=rs, sh=sh, mb=mb}
       | _ => error "rotate"
       )
   and rotatei {oper, ra, rs, sh, mb, me} = 
       let val sh = emit_operand sh
       in 
          (case (oper, me) of
            (I.RLWINM, SOME me) => rlwinm {ra=ra, rs=rs, sh=sh, mb=mb, me=me}
          | (I.RLWIMI, SOME me) => rlwimi {ra=ra, rs=rs, sh=sh, mb=mb, me=me}
          | (I.RLDICL, _) => rldicl {ra=ra, rs=rs, sh=(sh && 0wx1F), sh2=((sh << 0wx5) && 0wx1), 
               mb=mb}
          | (I.RLDICR, _) => rldicr {ra=ra, rs=rs, sh=(sh && 0wx1F), sh2=((sh << 0wx5) && 0wx1), 
               mb=mb}
          | (I.RLDIC, _) => rldic {ra=ra, rs=rs, sh=(sh && 0wx1F), sh2=((sh << 0wx5) && 0wx1), 
               mb=mb}
          | (I.RLDIMI, _) => rldimi {ra=ra, rs=rs, sh=(sh && 0wx1F), sh2=((sh << 0wx5) && 0wx1), 
               mb=mb}
          | _ => error "rotatei"
          )
       end
   and lwarx {rt, ra, rb} = 
       let val rt = emit_GP rt
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((rt << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C000028)))
       end
   and stwcx {rs, ra, rb} = 
       let val rs = emit_GP rs
           val ra = emit_GP ra
           val rb = emit_GP rb
       in eWord32 ((rs << 0wx15) + ((ra << 0wx10) + ((rb << 0wxB) + 0wx7C00012D)))
       end

(*#line 578.7 "ppc/ppc.mdl"*)
   fun relative (I.LabelOp lexp) = (itow ((MLTreeEval.valueOf lexp) - ( ! loc))) ~>> 0wx2
     | relative _ = error "relative"
       fun emitter instr =
       let
   fun emitInstr (I.L{ld, rt, ra, d, mem}) = load {ld=ld, rt=rt, ra=ra, d=d}
     | emitInstr (I.LF{ld, ft, ra, d, mem}) = fload {ld=ld, ft=ft, ra=ra, d=d}
     | emitInstr (I.ST{st, rs, ra, d, mem}) = store {st=st, rs=rs, ra=ra, d=d}
     | emitInstr (I.STF{st, fs, ra, d, mem}) = fstore {st=st, fs=fs, ra=ra, 
          d=d}
     | emitInstr (I.UNARY{oper, rt, ra, Rc, OE}) = unary {oper=oper, rt=rt, 
          ra=ra, OE=OE, Rc=Rc}
     | emitInstr (I.ARITH{oper, rt, ra, rb, Rc, OE}) = arith {oper=oper, rt=rt, 
          ra=ra, rb=rb, OE=OE, Rc=Rc}
     | emitInstr (I.ARITHI{oper, rt, ra, im}) = arithi {oper=oper, rt=rt, ra=ra, 
          im=im}
     | emitInstr (I.ROTATE{oper, ra, rs, sh, mb, me}) = rotate {oper=oper, 
          ra=ra, rs=rs, sh=sh, mb=mb, me=me}
     | emitInstr (I.ROTATEI{oper, ra, rs, sh, mb, me}) = rotatei {oper=oper, 
          ra=ra, rs=rs, sh=sh, mb=mb, me=me}
     | emitInstr (I.COMPARE{cmp, l, bf, ra, rb}) = compare {cmp=cmp, bf=bf, 
          l=l, ra=ra, rb=rb}
     | emitInstr (I.FCOMPARE{cmp, bf, fa, fb}) = fcmp {cmp=cmp, bf=bf, fa=fa, 
          fb=fb}
     | emitInstr (I.FUNARY{oper, ft, fb, Rc}) = funary {oper=oper, ft=ft, fb=fb, 
          Rc=Rc}
     | emitInstr (I.FARITH{oper, ft, fa, fb, Rc}) = farith {oper=oper, ft=ft, 
          fa=fa, fb=fb, Rc=Rc}
     | emitInstr (I.FARITH3{oper, ft, fa, fb, fc, Rc}) = farith3 {oper=oper, 
          ft=ft, fa=fa, fb=fb, fc=fc, Rc=Rc}
     | emitInstr (I.CCARITH{oper, bt, ba, bb}) = ccarith {oper=oper, bt=bt, 
          ba=ba, bb=bb}
     | emitInstr (I.MCRF{bf, bfa}) = mcrf {bf=bf, bfa=bfa}
     | emitInstr (I.MTSPR{rs, spr}) = mtspr {rs=rs, spr=spr}
     | emitInstr (I.MFSPR{rt, spr}) = mfspr {rt=rt, spr=spr}
     | emitInstr (I.LWARX{rt, ra, rb}) = lwarx {rt=rt, ra=ra, rb=rb}
     | emitInstr (I.STWCX{rs, ra, rb}) = stwcx {rs=rs, ra=ra, rb=rb}
     | emitInstr (I.TW{to, ra, si}) = tw {to=to, ra=ra, si=si}
     | emitInstr (I.TD{to, ra, si}) = td {to=to, ra=ra, si=si}
     | emitInstr (I.BC{bo, bf, bit, addr, LK, fall}) = bc {bo=bo, bi=cr_bit {cc=(bf, 
          bit)}, bd=relative addr, aa=false, lk=LK}
     | emitInstr (I.BCLR{bo, bf, bit, LK, labels}) = bclr {bo=bo, bi=cr_bit {cc=(bf, 
          bit)}, lk=LK}
     | emitInstr (I.B{addr, LK}) = b {li=relative addr, aa=false, lk=LK}
     | emitInstr (I.CALL{def, use, cutsTo, mem}) = bclr {bo=I.ALWAYS, bi=0wx0, 
          lk=true}
     | emitInstr (I.SOURCE{}) = ()
     | emitInstr (I.SINK{}) = ()
     | emitInstr (I.PHI{}) = ()
       in
           emitInstr instr
       end
   
   fun emitInstruction(I.ANNOTATION{i, ...}) = emitInstruction(i)
     | emitInstruction(I.INSTR(i)) = emitter(i)
     | emitInstruction(I.LIVE _)  = ()
     | emitInstruction(I.KILL _)  = ()
   | emitInstruction _ = error "emitInstruction"
   
   in  S.STREAM{beginCluster=init,
                pseudoOp=pseudoOp,
                emit=emitInstruction,
                endCluster=fail,
                defineLabel=doNothing,
                entryLabel=doNothing,
                comment=doNothing,
                exitBlock=doNothing,
                annotation=doNothing,
                getAnnotations=getAnnotations
               }
   end
end


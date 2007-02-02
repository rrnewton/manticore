/* manticore-regs.h
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Lists the "root" GC registers.  IMPORTANT: this file must agree with
 * ../codegen/amd64/amd64-regs.sml
 */

#ifndef _MANTICORE_REGS_H
#define _MANTICORE_REGS_H

enum {
  RAX = 0, RBX, RCX, RDX, RBP, RSI, RDI, RSP, R8, R9, R10, R11, R12, R13, R14, R15,
  NUM_GPRS
};

#endif

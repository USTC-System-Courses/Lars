import 'dart:core';

import 'package:binary/binary.dart';
import 'package:lars/Lars/Uint32_ext.dart';

import 'exception.dart';

enum Ins_type {
  NULL,
  NOP,
  ADDW,
  SUBW,
  SLT,
  SLTU,
  NOR,
  AND,
  OR,
  XOR,
  SLLW,
  SRLW,
  SRAW,
  MULW,
  MULHW,
  MULHWU,
  DIVW,
  MODW,
  DIVWU,
  MODWU,
  SLLIW,
  SRLIW,
  SRAIW,
  SLTI,
  SLTUI,
  ADDIW,
  ANDI,
  ORI,
  XORI,
  LU12IW,
  PCADDU12I,
  LDB,
  LDH,
  LDW,
  STB,
  STH,
  STW,
  LDBU,
  LDHU,
  JIRL,
  B,
  BL,
  BEQ,
  BNE,
  BLT,
  BGE,
  BLTU,
  BGEU,
  BREAK,
  HALT,
  LIW,
  LALOCAL,
}

Set<Ins_type> without_rd = {
      Ins_type.NOP,
      Ins_type.B,
      Ins_type.BL,
      Ins_type.BREAK,
      Ins_type.HALT,
    },
    without_rj = {
      Ins_type.NOP,
      Ins_type.B,
      Ins_type.BL,
      Ins_type.LU12IW,
      Ins_type.PCADDU12I,
      Ins_type.BREAK,
      Ins_type.HALT,
      Ins_type.LIW,
      Ins_type.LALOCAL,
    },
    without_rk = {
      Ins_type.NOP,
      Ins_type.B,
      Ins_type.BL,
      Ins_type.LU12IW,
      Ins_type.PCADDU12I,
      Ins_type.JIRL,
      Ins_type.BEQ,
      Ins_type.BNE,
      Ins_type.BLT,
      Ins_type.BGE,
      Ins_type.BLTU,
      Ins_type.BGEU,
      Ins_type.SLLIW,
      Ins_type.SRLIW,
      Ins_type.SRAIW,
      Ins_type.SLTI,
      Ins_type.SLTUI,
      Ins_type.ADDIW,
      Ins_type.ANDI,
      Ins_type.ORI,
      Ins_type.XORI,
      Ins_type.LDB,
      Ins_type.LDH,
      Ins_type.LDW,
      Ins_type.STB,
      Ins_type.STH,
      Ins_type.STW,
      Ins_type.LDBU,
      Ins_type.LDHU,
      Ins_type.BREAK,
      Ins_type.HALT,
      Ins_type.LIW,
      Ins_type.LALOCAL,
    },
    with_ui5 = {
      Ins_type.SLLIW,
      Ins_type.SRLIW,
      Ins_type.SRAIW,
    },
    with_ui12 = {
      Ins_type.ANDI,
      Ins_type.ORI,
      Ins_type.XORI,
    },
    with_si12 = {
      Ins_type.SLTI,
      Ins_type.SLTUI,
      Ins_type.ADDIW,
      Ins_type.LDB,
      Ins_type.LDH,
      Ins_type.LDW,
      Ins_type.STB,
      Ins_type.STH,
      Ins_type.STW,
      Ins_type.LDBU,
      Ins_type.LDHU,
    },
    with_si16 = {Ins_type.JIRL},
    with_si20 = {
      Ins_type.LU12IW,
      Ins_type.PCADDU12I,
    },
    with_label16 = {
      Ins_type.BEQ,
      Ins_type.BNE,
      Ins_type.BLT,
      Ins_type.BGE,
      Ins_type.BLTU,
      Ins_type.BGEU,
    },
    with_label26 = {
      Ins_type.B,
      Ins_type.BL,
    },
    with_label32 = {
      Ins_type.LALOCAL,
    },
    with_LDST = {
      Ins_type.LDB,
      Ins_type.LDH,
      Ins_type.LDW,
      Ins_type.STB,
      Ins_type.STH,
      Ins_type.STW,
      Ins_type.LDBU,
      Ins_type.LDHU,
    };
Set<Ins_type> with_label =
    (with_label16.toList() + with_label26.toList() + with_label32.toList())
        .toSet();
Set<Ins_type> with_imm =
    (with_si12.toList() + with_si16.toList() + with_si20.toList() + with_ui5.toList() + with_ui12.toList()).toSet();

enum analyze_mode {
  DATA,
  TEXT,
}

enum Sign_type {
  TEXT,
  DATA,
  WORD,
  BYTE,
  HALF,
  SPACE,
}

String opString =
    r"\b(nop|add\.w|sub\.w|slt|sltu|nor|and|or|xor|sll\.w|srl\.w|sra\.w|mul\.w|mulh\.w|mulhu\.w|div\.w|mod\.w|divu\.w|modu\.w|slli\.w|srli\.w|srai\.w|slti|sltui|addi\.w|andi|ori|xori|lu12i\.w|pcaddu12i|ld\.b|ld\.h|ld\.w|st\.b|st\.h|st\.w|ld\.bu|ld\.hu|jirl|b|bl|beq|bne|blt|bge|bltu|bgeu|break|halt|li\.w|la\.local)\b";
String signString =
    r"(\.)(text|data|word|byte|half|space)|((^|\s+)([a-zA-Z_][a-zA-Z0-9_]*):)";
// String labelString = r"(^|\s+)([a-zA-Z_][a-zA-Z0-9_]*):";
String regString =
    r"((\s+)(\$?)([Rr][0-9]+|zero|ra|tp|sp|a[0-7]|t[0-8]|fp|s[0-9]|ZERO|RA|TP|SP|A[0-7]|T[0-8]|FP|S[0-9])\b)";
// String immString = r"(\s+)?(0x)?[0-9]+\b";

String opcheckString =
    r"^((NOP)|(ADD\.W)|(SUB\.W)|(SLT)|(SLTU)|(NOR)|(AND)|(OR)|(XOR)|(SLL\.W)|(SRL\.W)|(SRA\.W)|(MUL\.W)|(MULH\.W)|(MULHU\.W)|(DIV\.W)|(MOD\.W)|(DIVU\.W)|(MODU\.W)|(SLLI\.W)|(SRLI\.W)|(SRAI\.W)|(SLTI)|(SLTUI)|(ADDI\.W)|(ANDI)|(ORI)|(XORI)|(LU12I\.W)|(PCADDU12I)|(LD\.B)|(LD\.H)|(LD\.W)|(ST\.B)|(ST\.H)|(ST\.W)|(LD\.BU)|(LD\.HU)|(JIRL)|(B)|(BL)|(BEQ)|(BNE)|(BLT)|(BGE)|(BLTU)|(BGEU)|(BREAK)|(HALT)|(LI\.W)|(LA\.LOCAL))$";

Ins_type get_inst_type(Uint32 ins){
    if(ins.getBit(31) == 1)
        return Ins_type.HALT;
    if(ins.getBit(30) == 1)
        switch(ins.bitRange(31, 26).toInt()){
            case 0x13: return Ins_type.JIRL;
            case 0x14: return Ins_type.B;
            case 0x15: return Ins_type.BL;
            case 0x16: return Ins_type.BEQ;
            case 0x17: return Ins_type.BNE;
            case 0x18: return Ins_type.BLT;
            case 0x19: return Ins_type.BGE;
            case 0x1A: return Ins_type.BLTU;
            case 0x1B: return Ins_type.BGEU;
            default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
        }
    else if (ins.getBit(29) == 1) 
        switch(ins.bitRange(31, 22).toInt()){
            case 0xA0: return Ins_type.LDB;
            case 0xA1: return Ins_type.LDH;
            case 0xA2: return Ins_type.LDW;
            case 0xA4: return Ins_type.STB;
            case 0xA5: return Ins_type.STH;
            case 0xA6: return Ins_type.STW;
            case 0xA8: return Ins_type.LDBU;
            case 0xA9: return Ins_type.LDHU;
            default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
        }
    else if (ins.getBit(28) == 1)
        switch(ins.bitRange(31, 25).toInt()){
            case 0x0A: return Ins_type.LU12IW;
            case 0x0E: return Ins_type.PCADDU12I;
            default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
        }
    else if (ins.getBit(25) == 1)
        switch(ins.bitRange(31, 22).toInt()){
            case 0x08: return Ins_type.SLTI;
            case 0x09: return Ins_type.SLTUI;
            case 0x0A: if(ins.bitRange(21, 0) == 0) return Ins_type.NOP; else return Ins_type.ADDIW;
            case 0x0D: return Ins_type.ANDI;
            case 0x0E: return Ins_type.ORI;
            case 0x0F: return Ins_type.XORI;
            default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
        }
    else
        switch(ins.bitRange(31, 15).toInt()){
            case 0x20: return Ins_type.ADDW;
            case 0x22: return Ins_type.SUBW;
            case 0x24: return Ins_type.SLT;
            case 0x25: return Ins_type.SLTU;
            case 0x28: return Ins_type.NOR;
            case 0x29: return Ins_type.AND;
            case 0x2A: return Ins_type.OR;
            case 0x2B: return Ins_type.XOR;
            case 0x2E: return Ins_type.SLLW;
            case 0x2F: return Ins_type.SRLW;
            case 0x30: return Ins_type.SRAW;
            case 0x38: return Ins_type.MULW;
            case 0x39: return Ins_type.MULHW;
            case 0x3A: return Ins_type.MULHWU;
            case 0x40: return Ins_type.DIVW;
            case 0x41: return Ins_type.MODW;
            case 0x42: return Ins_type.DIVWU;
            case 0x43: return Ins_type.MODWU;
            case 0x54: return Ins_type.BREAK;
            case 0x81: return Ins_type.SLLIW;
            case 0x89: return Ins_type.SRLIW;
            case 0x91: return Ins_type.SRAIW;
            case 0: return Ins_type.NULL;
            default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
        }
}
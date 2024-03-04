import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
Map<String, String> register_rename_table = {
    r"ZERO": r"R0", r"RA": r"R1", r"TP": r"R2", r"SP": r"R3",
    r"A0": r"R4", r"A1": r"R5", r"A2": r"R6", r"A3": r"R7",
    r"A4": r"R8", r"A5": r"R9", r"A6": r"R10", r"A7": r"R11",
    r"T0": r"R12", r"T1": r"R13", r"T2": r"R14", r"T3": r"R15",
    r"T4": r"R16", r"T5": r"R17", r"T6": r"R18", r"T7": r"R19",
    r"S0": r"R20", r"S1": r"R21", r"S2": r"R22", r"S3": r"R23",
    r"S4": r"R24", r"S5": r"R25", r"S6": r"R26", r"S7": r"R27",
    r"S8": r"R28", r"S9": r"R29", r"S10": r"R30", r"S11": r"R31",
};

Map<Ins_type, Uint32> opcode_table = {
    Ins_type.NOP:           Uint32_t(0x0A << 20),
    Ins_type.ADDW:          Uint32_t(0x00100 << 12),
    Ins_type.SUBW:          Uint32_t(0x00110 << 12),
    Ins_type.SLT:           Uint32_t(0x00120 << 12),
    Ins_type.SLTU:          Uint32_t(0x00128 << 12),
    Ins_type.NOR:           Uint32_t(0x00140 << 12),
    Ins_type.AND:           Uint32_t(0x00148 << 12),
    Ins_type.OR:            Uint32_t(0x00150 << 12),
    Ins_type.XOR:           Uint32_t(0x00158 << 12),
    Ins_type.SLLW:          Uint32_t(0x00170 << 12),
    Ins_type.SRLW:          Uint32_t(0x00178 << 12),
    Ins_type.SRAW:          Uint32_t(0x00180 << 12),
    Ins_type.MULW:          Uint32_t(0x001C0 << 12),
    Ins_type.MULHW:         Uint32_t(0x001C8 << 12),
    Ins_type.MULHWU:        Uint32_t(0x001D0 << 12),
    Ins_type.DIVW:          Uint32_t(0x00200 << 12),
    Ins_type.MODW:          Uint32_t(0x00208 << 12),
    Ins_type.DIVWU:         Uint32_t(0x00210 << 12),
    Ins_type.MODWU:         Uint32_t(0x00218 << 12),
    Ins_type.SLLIW:         Uint32_t(0x00408 << 12),
    Ins_type.SRLIW:         Uint32_t(0x00448 << 12),
    Ins_type.SRAIW:         Uint32_t(0x00488 << 12),
    Ins_type.SLTI:          Uint32_t(0x08 << 22),
    Ins_type.SLTUI:         Uint32_t(0x09 << 22),
    Ins_type.ADDIW:         Uint32_t(0x0A << 22),
    Ins_type.ANDI:          Uint32_t(0x0D << 22),
    Ins_type.ORI:           Uint32_t(0x0E << 22),
    Ins_type.XORI:          Uint32_t(0x0F << 22),
    Ins_type.LU12IW:        Uint32_t(0x0C << 25),
    Ins_type.PCADDU12I:     Uint32_t(0x0E << 25),
    Ins_type.LDB:           Uint32_t(0xA0 << 22),
    Ins_type.LDH:           Uint32_t(0xA1 << 22),
    Ins_type.LDW:           Uint32_t(0xA2 << 22),
    Ins_type.STB:           Uint32_t(0xA4 << 22),
    Ins_type.STH:           Uint32_t(0xA5 << 22),
    Ins_type.STW:           Uint32_t(0xA6 << 22),
    Ins_type.LDBU:          Uint32_t(0xA8 << 22),
    Ins_type.LDHU:          Uint32_t(0xA9 << 22),
    Ins_type.JIRL:          Uint32_t(0x13 << 26),
    Ins_type.B:             Uint32_t(0x14 << 26),
    Ins_type.BL:            Uint32_t(0x15 << 26),
    Ins_type.BEQ:           Uint32_t(0x16 << 26),
    Ins_type.BNE:           Uint32_t(0x17 << 26),
    Ins_type.BLT:           Uint32_t(0x18 << 26),
    Ins_type.BGE:           Uint32_t(0x19 << 26),
    Ins_type.BLTU:          Uint32_t(0x1A << 26),
    Ins_type.BGEU:          Uint32_t(0x1B << 26),
    Ins_type.BREAK:         Uint32_t(0x54 << 15),
};

List<String> register_name = [
    r"ZERO", r"RA", r"TP", r"SP",
    r"A0", r"A1", r"A2", r"A3",
    r"A4", r"A5", r"A6", r"A7",
    r"T0", r"T1", r"T2", r"T3",
    r"T4", r"T5", r"T6", r"T7",
    r"S0", r"S1", r"S2", r"S3",
    r"S4", r"S5", r"S6", r"S7",
    r"S8", r"S9", r"S10", r"S11",
];




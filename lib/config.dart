enum Ins_type{
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
    LIW,
    LALOCAL,
}

List<Ins_type> without_rd = [
    Ins_type.NOP,
    Ins_type.B,
    Ins_type.BL,
    Ins_type.BREAK,
],
without_rj = [
    Ins_type.NOP,
    Ins_type.B,
    Ins_type.BL,
    Ins_type.LU12IW,
    Ins_type.PCADDU12I,
    Ins_type.BREAK,
    Ins_type.LIW,
    Ins_type.LALOCAL,
],
without_rk = [
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
    Ins_type.LIW,
    Ins_type.LALOCAL,
],
with_ui5 = [
    Ins_type.SLLIW,
    Ins_type.SRLIW,
    Ins_type.SRAIW,
],
with_ui12 = [
    Ins_type.ANDI,
    Ins_type.ORI,
    Ins_type.XORI,
],
with_si12 = [
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
],
with_si20 = [
    Ins_type.LU12IW,
    Ins_type.PCADDU12I,
],
with_label16 = [
    Ins_type.BEQ,
    Ins_type.BNE,
    Ins_type.BLT,
    Ins_type.BGE,
    Ins_type.BLTU,
    Ins_type.BGEU,
],
with_label26 = [
    Ins_type.B,
    Ins_type.BL,
],
with_label32 = [
    Ins_type.LALOCAL,
],
// with_imm32 = [
//     Ins_type.LIW,
// ],

// is_macro_inst = [
//     Ins_type.LIW,
// ],

with_LDST = [
    Ins_type.LDB,
    Ins_type.LDH,
    Ins_type.LDW,
    Ins_type.STB,
    Ins_type.STH,
    Ins_type.STW,
    Ins_type.LDBU,
    Ins_type.LDHU,
],
with_label = with_label16 + with_label26 + with_label32;

enum analyze_mode{
    DATA,
    TEXT,
}

enum Sign_type{
    TEXT,
    DATA,
    WORD,
    BYTE,
    HALF,
    SPACE,
}

String opString = r"(^|\s+)(add\.w|sub\.w|slt|sltu|nor|and|or|xor|sll\.w|srl\.w|sra.w|mul.w|mulh\.w|mulhu\.w|div\.w|mod\.w|divu\.w|modu\.w|slli\.w|srli\.w|srai\.w|slti|sltiu|addi\.w|andi|ori|xori|lu12i\.w|pcaddu12i|ld\.b|ld\.h|ld\.w|st\.b|st\.h|st\.w|ld\.bu|ld\.hu|jirl|b|bl|beq|bne|blt|bge|bltu|bgeu|break|li\.w|la\.local)(\s+|$)";
String regString = r"\$?([Rr][0-9]+|zero|ra|tp|sp|a[0-7]|t[0-8]|fp|s[0-9])";
String immString = r"[0-9]+";

String opcheckString = r"ADD\.W|SUB\.W|SLT|SLTU|NOR|AND|OR|XOR|SLL\.W|SRL\.W|SRA.W|MUL.W|MULH\.W|MULHU\.W|DIV\.W|MOD\.W|DIVU\.W|MODU\.W|SLLI\.W|SRLI\.W|SRAI\.W|SLTI|SLTIU|ADDI\.W|ANDI|ORI|XORI|LU12I\.W|PCADDU12I|LD\.B|LD\.H|LD\.W|ST\.B|ST\.H|ST\.W|LD\.BU|LD\.HU|JIRL|B|BL|BEQ|BNE|BLT|BGE|BLTU|BGEU|BREAK|LI\.W|LA\.LOCAL";


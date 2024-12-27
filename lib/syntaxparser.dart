import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './exception.dart';
import 'arch.dart';

class SyntaxPackage {
  bool is_empty = false;
  bool is_code = false;
  Uint32 machine_code = Uint32(0);
  Ins_type type = Ins_type.NOP;

  bool is_label = false;
  bool has_label = false;
  String label = "";

  bool is_sign = false;
  Sign_type sign_type = Sign_type.TEXT;
  Uint32 sign_item = Uint32(0);

  // li.w la.local
  bool is_double = false;
  Uint32 machine_code_2 = Uint32(0);
  Ins_type type_2 = Ins_type.NOP;
  bool has_label_2 = false;
  String label_2 = "";

  // for debug
  String sentence = "";
  String sentence_ori = "";
  String sentence_2 = "";
  String sentence_2_ori = "";

  SyntaxPackage(String s) {
    sentence_ori = s;
  }
  void clear() {
    is_empty = false;
    is_code = false;

    is_label = false;
    has_label = false;

    is_sign = false;

    is_double = false;
    has_label_2 = false;
  }
}

class SyntaxParser {
  // 预编译的正则表达式
  static final RegExp _commentRegex = RegExp(r'#.*');
  static final RegExp _commaRegex = RegExp(r',');
  static final RegExp _tabRegex = RegExp(r'\t');
  static final RegExp _multiSpaceRegex = RegExp(r' +');
  static final RegExp _registerPrefixRegex = RegExp(r'\$');
  static final RegExp _dotRegex = RegExp(r'\.');

  // 静态常量表
  static final Map<String, String> _registerRenameTable = register_rename_table;
  static final Map<Ins_type, Uint32> _opcodeTable = opcode_table;

  late String s;
  late String s_regular;
  late List<String> s_regular_spilt;
  late Uint32 rd;
  late Uint32 rj;
  late Uint32 rk;

  final SyntaxPackage package;

  SyntaxParser() : package = SyntaxPackage("");

  String _regularize(String input) {
    return input
        .replaceAll(_commentRegex, '')
        .replaceAll(_commaRegex, ' ')
        .replaceAll(_tabRegex, ' ')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim()
        .toUpperCase();
  }

  String _renameRegister(String reg) => _registerRenameTable[reg] ?? reg;

  Uint32 _parseOpcode(Ins_type type) => _opcodeTable[type] ?? Uint32.zero;

  void _genLiw() {
    var imm = Uint32.zero;
    try {
      imm = Uint32_t(int.parse(s_regular_spilt[2]));
    } catch (e) {
      throw SentenceException(Exception_type.INVALID_IMM, s_regular);
    }

    if (imm.bitRange(31, 12) != Uint32.zero) {
      var imm1 = imm.bitRange(31, 12);
      package.machine_code =
          (Uint32_t(0x0A << 25) | (imm1 << Uint32_t(5)) | rd);
      package.sentence =
          "LU12I.W ${s_regular_spilt[1]}, 0x${imm1.toSignedInt().toRadixString(16)}";
      package.type = Ins_type.LU12IW;

      if (imm.bitRange(11, 0) == Uint32.zero) return;

      var imm2 = imm.bitRange(11, 0);
      package.machine_code_2 = (Uint32_t(0x0E << 22) |
          (imm2 << Uint32_t(10)) |
          rd << Uint32_t(5) |
          rd);
      package.sentence_2 =
          "ORI ${s_regular_spilt[1]}, ${s_regular_spilt[1]}, 0x${imm2.toInt().toRadixString(16)}";
      package.type_2 = Ins_type.ORI;
      package.is_double = true;
    } else {
      var imm2 = imm.bitRange(11, 0);
      package.machine_code = (Uint32_t(0x0E << 22) |
          (imm2 << Uint32_t(10)) |
          Uint32.zero << Uint32_t(5) |
          rd);
      package.sentence =
          "ORI ${s_regular_spilt[1]}, \$R0, 0x${imm2.toInt().toRadixString(16)}";
      package.type = Ins_type.ORI;
    }
  }

  void _genLalocal() {
    package.machine_code = (Uint32_t(0x0A << 25) | rd);
    package.sentence = "LU12I.W ${s_regular_spilt[1]}, ";
    package.type = Ins_type.LU12IW;

    package.machine_code_2 = (Uint32_t(0x0E << 22) | rd << Uint32_t(5) | rd);
    package.sentence_2 = "ORI ${s_regular_spilt[1]}, ${s_regular_spilt[1]}, ";
    package.type_2 = Ins_type.ORI;
    package.is_double = true;
  }

  Uint32 _parseReg(Ins_type type) {
    Uint32 result = Uint32_t(0);

    if (!without_rd.contains(type)) {
      int rdPos = with_label16.contains(type) ? 2 : 1;
      String rdStr = _renameRegister(
              s_regular_spilt[rdPos].replaceAll(_registerPrefixRegex, ''))
          .substring(1);

      try {
        rd = Uint32_t(int.parse(rdStr));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
      }

      if (rd > Uint32_t(31)) {
        throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
      }
      result |= rd;
    }

    if (!without_rj.contains(type)) {
      int rjPos = with_label16.contains(type) ? 1 : 2;
      String rjStr = _renameRegister(
              s_regular_spilt[rjPos].replaceAll(_registerPrefixRegex, ''))
          .substring(1);

      try {
        rj = Uint32_t(int.parse(rjStr));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
      }

      if (rj > Uint32_t(31)) {
        throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
      }
      result |= rj << Uint32_t(5);
    }

    if (!without_rk.contains(type)) {
      String rkStr = _renameRegister(
              s_regular_spilt[3].replaceAll(_registerPrefixRegex, ''))
          .substring(1);

      try {
        rk = Uint32_t(int.parse(rkStr));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
      }

      if (rk > Uint32_t(31)) {
        throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
      }
      result |= rk << Uint32_t(10);
    }

    return result;
  }

  Uint32 _parseImm(Ins_type type) {
    Uint32 imm = Uint32_t(0);

    if (with_ui5.contains(type)) {
      try {
        imm = Uint32_t(int.parse(s_regular_spilt[3]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s_regular);
      }
      if (imm > Uint32_t(31)) {
        throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
      }
      return (imm << Uint32_t(10)).bitRange(14, 0);
    }

    if (with_ui12.contains(type)) {
      try {
        imm = Uint32_t(int.parse(s_regular_spilt[3]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s_regular);
      }
      if (imm > Uint32_t(4095)) {
        throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
      }
      return (imm << Uint32_t(10)).bitRange(21, 0);
    }

    if (with_si12.contains(type)) {
      try {
        imm = Uint32_t(int.parse(s_regular_spilt[3]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s_regular);
      }
      if (imm.toSignedInt() > 2047 || imm.toSignedInt() < -2048) {
        throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
      }
      return (imm << Uint32_t(10)).bitRange(21, 0);
    }

    if (with_si16.contains(type)) {
      try {
        imm = Uint32_t(int.parse(s_regular_spilt[3]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s_regular);
      }
      if (imm.toSignedInt() > 32767 ||
          imm.toSignedInt() < -32768 ||
          imm.bitRange(1, 0) != Uint32.zero) {
        throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
      }
      return (imm << Uint32_t(8)).bitRange(25, 0);
    }

    if (with_si20.contains(type)) {
      try {
        imm = Uint32_t(int.parse(s_regular_spilt[2]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s_regular);
      }
      if (imm.toSignedInt() > 1048575 || imm.toSignedInt() < -1048576) {
        throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
      }
      return (imm << Uint32_t(5)).bitRange(24, 0);
    }

    return Uint32.zero;
  }

  SyntaxPackage Parse(String input) {
    package.clear();
    s = input;
    s_regular = _regularize(s);

    if (s_regular.isEmpty) {
      package.is_empty = true;
      return package;
    }

    s_regular_spilt = s_regular.split(' ');
    package.sentence_ori = s;
    package.sentence = s_regular;

    if (s_regular[0] == '.') {
      return _parseSign();
    }

    if (s_regular[s_regular.length - 1] == ':') {
      return _parseLabel();
    }

    return _parseInstruction();
  }

  SyntaxPackage _parseSign() {
    package.is_sign = true;
    package.label = s_regular_spilt[0].substring(1);

    if (!Sign_type.values
        .map((e) => e.toString().split(".")[1])
        .contains(package.label)) {
      throw SentenceException(Exception_type.INVALID_SEGMENT, s);
    }

    package.sign_type = Sign_type.values.byName(package.label);

    if (s_regular_spilt.length > 1) {
      try {
        package.sign_item = Uint32_t(int.parse(s_regular_spilt[1]));
      } catch (e) {
        throw SentenceException(Exception_type.INVALID_IMM, s);
      }
    }

    return package;
  }

  SyntaxPackage _parseLabel() {
    package.is_label = true;
    package.label = s_regular_spilt[0];
    return package;
  }

  SyntaxPackage _parseInstruction() {
    package.is_code = true;

    if (!RegExp(opcheckString).hasMatch(s_regular_spilt[0])) {
      throw SentenceException(Exception_type.UNKNOWN_INST, s);
    }

    var opcode = s_regular_spilt[0].replaceAll(_dotRegex, "");
    var type = Ins_type.values.byName(opcode);
    package.type = type;

    package.machine_code =
        _parseOpcode(type) | _parseReg(type) | _parseImm(type);

    if (with_label.contains(type)) {
      package.has_label = true;
      package.label = s_regular_spilt[s_regular_spilt.length - 1];
    }

    if (type == Ins_type.LIW) {
      _genLiw();
    } else if (type == Ins_type.LALOCAL) {
      _genLalocal();
    }

    return package;
  }
}

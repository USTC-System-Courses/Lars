/// LARS - LA32R Assembler and Runtime Simulator - Assembler Module
///
/// High-performance assembler implementation for LA32R instruction set
///
/// Copyright (c) 2024 LARS Team
/// Licensed under MIT License

import 'Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'dart:collection';
import 'config.dart';
import 'memory.dart';
import 'label.dart';
import 'exception.dart';
import 'syntaxparser.dart';

class Assembler {
  // 使用 final 提高性能
  final List<String> inst_input;
  final List<SentenceBack> _inst = [];
  final Label _label = Label();
  final Map<Uint32, SentenceBack> inst_rec = HashMap<Uint32, SentenceBack>();
  final SyntaxParser lp = SyntaxParser();

  // 常量定义，避免重复计算
  static final Uint32 TEXT_BASE = Uint32_t(0x1c000000);
  static final Uint32 DATA_BASE = Uint32_t(0x1c800000);

  Assembler(this.inst_input) {
    var text_build = TEXT_BASE;
    var data_build = DATA_BASE;
    var build = text_build;
    var mode = analyze_mode.TEXT;

    // 第一遍：处理标签和基本指令
    for (final element in inst_input) {
      final pkg = lp.Parse(element);
      if (pkg.is_empty) continue;

      // 处理指令标记
      if (pkg.is_sign) {
        switch (pkg.sign_type) {
          case Sign_type.TEXT:
            if (mode == analyze_mode.DATA) {
              data_build = build;
              build = text_build;
            }
            mode = analyze_mode.TEXT;
            break;
          case Sign_type.DATA:
            if (mode == analyze_mode.TEXT) {
              text_build = build;
              build = data_build;
            }
            mode = analyze_mode.DATA;
            break;
          case Sign_type.BYTE:
            memory.write(build, pkg.sign_item, size: 1);
            build = build.add(1);
            break;
          case Sign_type.HALF:
            memory.write(build, pkg.sign_item, size: 2);
            build = build.add(2);
            break;
          case Sign_type.WORD:
            memory.write(build, pkg.sign_item, size: 4);
            build = build.add(4);
            break;
          case Sign_type.SPACE:
            final size = pkg.sign_item.toInt();
            memory.writeBlock(build, size);
            build = build.add(size);
            break;
        }
        continue;
      }

      // 处理标签
      if (pkg.is_label) {
        _label.add(pkg.label, build);
        continue;
      }

      // 处理代码
      if (pkg.is_code) {
        _inst.add(SentenceBack(pkg, false));
        build = build.add(4);
        if (pkg.is_double) {
          _inst.add(SentenceBack(pkg, true));
          build = build.add(4);
        }
      }
    }

    // 更新内存边界
    if (mode == analyze_mode.TEXT) {
      memory.text_upper = build;
      memory.data_upper = data_build;
    } else {
      memory.data_upper = build;
      memory.text_upper = text_build;
    }

    build = TEXT_BASE;
    // 第二遍：解析标签并生成机器码
    for (final element in _inst) {
      if (element.has_label) {
        final addr = _label.find(element.label);
        if (!addr_range_check(element.type, addr, build)) {
          throw SentenceException(
              Exception_type.LABEL_TOO_FAR, element.sentence_ori);
        }
        final pc_offset = addr - build;

        if (with_label16.contains(element.type) ||
            element.type == Ins_type.JIRL) {
          element.machine_code |=
              Uint32_t(pc_offset.bitRange(17, 2)) << Uint32_t(10);
        } else if (with_label26.contains(element.type)) {
          element.machine_code |=
              Uint32_t(pc_offset.bitRange(17, 2)) << Uint32_t(10);
          element.machine_code |= Uint32_t(pc_offset.bitRange(27, 18));
        } else {
          if (element.type == Ins_type.LU12IW) {
            element.machine_code |= addr.bitRange(31, 12) << Uint32_t(5);
            element.sentence +=
                '0x' + addr.bitRange(31, 12).toInt().toRadixString(16);
          } else {
            element.machine_code |= addr.bitRange(11, 0) << Uint32_t(10);
            element.sentence +=
                '0x' + addr.bitRange(11, 0).toInt().toRadixString(16);
          }
        }
      }

      // 优化：直接写入机器码
      final machineCode = int.parse(element.print(), radix: 2);
      memory.write(build, Uint32_t(machineCode));
      inst_rec[build] = element;
      build = build.add(4);
    }
  }

  bool addr_range_check(Ins_type type, Uint32 addr, Uint32 build) {
    final diff = build - addr;

    // 优化：使用位运算进行范围检查
    if (with_label16.contains(type)) {
      return diff > -(1 << 15) && diff < (1 << 15) - 1;
    }
    if (type == Ins_type.JIRL) {
      return diff > -(1 << 17) && diff < (1 << 17) - 1;
    }
    if (with_label26.contains(type)) {
      return diff > -(1 << 25) && diff < (1 << 25) - 1;
    }
    return true;
  }
}

class SentenceBack {
  String sentence_ori = '';
  String sentence = '';
  Uint32 machine_code = Uint32_t(0);
  Ins_type type = Ins_type.NULL;
  bool is_code = false;
  bool is_label = false;
  bool has_label = false;
  String label = '';
  bool is_sign = false;
  Uint32 sign_item = Uint32_t(0);
  Sign_type sign_type = Sign_type.TEXT;

  SentenceBack(SyntaxPackage l, bool use2) {
    if (!use2) {
      sentence_ori = l.sentence_ori;
      sentence = l.sentence;
      machine_code = l.machine_code;
      type = l.type;
      is_code = l.is_code;
      is_label = l.is_label;
      has_label = l.has_label;
      label = l.label;
      is_sign = l.is_sign;
      sign_item = l.sign_item;
      sign_type = l.sign_type;
    } else {
      sentence_ori = l.sentence_2_ori;
      sentence = l.sentence_2;
      machine_code = l.machine_code_2;
      type = l.type_2;
      is_code = l.is_code;
      is_label = l.is_label;
      has_label = l.has_label;
      label = l.label;
      is_sign = l.is_sign;
      sign_item = l.sign_item;
      sign_type = l.sign_type;
    }
  }
  String print() {
    return machine_code.toBinaryPadded();
  }
}

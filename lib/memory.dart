/// LARS - LA32R Assembler and Runtime Simulator - Memory Module
///
/// Simulates computer memory operations with efficient read/write capabilities
/// and memory dump functions for instruction and data segments.
///
/// Features:
/// - Fast memory access using typed data
/// - Configurable memory segments
/// - Memory boundary checking
/// - Support for different data widths
/// - Memory dump in COE and PDU formats
///
/// Copyright (c) 2024 LARS Team
/// Licensed under MIT License

import 'package:binary/binary.dart';
import './Uint32_ext.dart';
import 'dart:typed_data';

class Memory {
  final Uint32 CONFIG_PMEM_BASE = Uint32(0x1c000000);
  final Uint32 CONFIG_PMEM_SIZE = Uint32(0x08000000); // 128Mb

  late final Uint8List _memory;

  Uint32 text_upper = Uint32.zero;
  Uint32 data_upper = Uint32.zero;

  Memory() {
    _memory = Uint8List(CONFIG_PMEM_SIZE.toInt());
  }

  bool in_pmem(Uint32 addr) {
    return addr >= CONFIG_PMEM_BASE &&
        addr < (CONFIG_PMEM_BASE + CONFIG_PMEM_SIZE);
  }

  int _getOffset(Uint32 addr) {
    return (addr - CONFIG_PMEM_BASE).toInt();
  }

  void write(Uint32 w_addr, Uint32 w_data, {int size = 4}) {
    if (!in_pmem(w_addr)) return;

    final offset = _getOffset(w_addr);
    final bytes = ByteData(4)..setUint32(0, w_data.toInt(), Endian.little);

    for (var i = 0; i < size; i++) {
      _memory[offset + i] = bytes.getUint8(i);
    }
  }

  Uint32 read(Uint32 r_addr, {int size = 4}) {
    if (!in_pmem(r_addr)) return Uint32.zero;
    if (size > 4) return Uint32.zero;

    final offset = _getOffset(r_addr);

    final bytes = ByteData(4);
    for (var i = 0; i < size; i++) {
      bytes.setUint8(i, _memory[offset + i]);
    }

    return Uint32(bytes.getUint32(0, Endian.little));
  }

  int operator [](Uint32 r_addr) {
    if (!in_pmem(r_addr)) return 0;
    return read(r_addr).toInt();
  }

  String DumpInstCoe() {
    final buffer = StringBuffer()
      ..writeln("memory_initialization_radix=16;")
      ..writeln("memory_initialization_vector=");

    for (Uint32 i = CONFIG_PMEM_BASE; i < text_upper; i = i.add(4)) {
      buffer.writeln("${read(i).toInt().toRadixString(16).padLeft(8, '0')},");
    }

    return buffer.toString();
  }

  String DumpInstPdu() {
    String res = "";
    for (Uint32 i = CONFIG_PMEM_BASE; i < text_upper; i = i.add(4)) {
      res += read(i).toInt().toRadixString(16).padLeft(8, '0');
      res += "\n";
    }
    res += '\n';
    return res;
  }

  String DumpDataCoe() {
    String res =
        "memory_initialization_radix=16;\nmemory_initialization_vector=\n";
    for (Uint32 i = Uint32_t(0x1c800000); i < data_upper; i = i.add(4)) {
      res += read(i).toInt().toRadixString(16).padLeft(8, '0') + ",\n";
    }
    return res;
  }

  String DumpDataPdu() {
    String res = "";
    for (Uint32 i = CONFIG_PMEM_BASE; i < text_upper; i = i.add(4)) {
      res += read(i).toInt().toRadixString(16).padLeft(8, '0');
      res += "\n";
    }
    res += '\n';
    return res;
  }

  /// 批量写入0值
  void writeBlock(Uint32 addr, int size) {
    for (var i = 0; i < size; i++) {
      write(addr + Uint32_t(i), Uint32_t(0), size: 1);
    }
  }
}

Memory memory = Memory();

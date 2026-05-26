import 'utils.dart';
import 'names.dart' as lipes_names;

const int _wordMask = 0xffffffff;

int _u32(int value) => value & _wordMask;

enum DemoOpcode { nop, add, sub, addi, load, store, beq, halt }

class DemoInstruction {
  final DemoOpcode opcode;
  final int rd;
  final int rs1;
  final int rs2;
  final int imm;
  final String label;

  const DemoInstruction._(
    this.opcode, {
    this.rd = 0,
    this.rs1 = 0,
    this.rs2 = 0,
    this.imm = 0,
    this.label = '',
  });

  const DemoInstruction.nop() : this._(DemoOpcode.nop);

  const DemoInstruction.halt() : this._(DemoOpcode.halt);

  const DemoInstruction.add(int rd, int rs1, int rs2)
      : this._(DemoOpcode.add, rd: rd, rs1: rs1, rs2: rs2);

  const DemoInstruction.sub(int rd, int rs1, int rs2)
      : this._(DemoOpcode.sub, rd: rd, rs1: rs1, rs2: rs2);

  const DemoInstruction.addi(int rd, int rs1, int imm)
      : this._(DemoOpcode.addi, rd: rd, rs1: rs1, imm: imm);

  const DemoInstruction.load(int rd, int base, int offset)
      : this._(DemoOpcode.load, rd: rd, rs1: base, imm: offset);

  const DemoInstruction.store(int src, int base, int offset)
      : this._(DemoOpcode.store, rs1: base, rs2: src, imm: offset);

  const DemoInstruction.beq(int rs1, int rs2, int offsetWords)
      : this._(DemoOpcode.beq, rs1: rs1, rs2: rs2, imm: offsetWords);

  bool get isNop => opcode == DemoOpcode.nop;
  bool get isHalt => opcode == DemoOpcode.halt;
  bool get readsRs1 =>
      opcode == DemoOpcode.add ||
      opcode == DemoOpcode.sub ||
      opcode == DemoOpcode.addi ||
      opcode == DemoOpcode.load ||
      opcode == DemoOpcode.store ||
      opcode == DemoOpcode.beq;
  bool get readsRs2 =>
      opcode == DemoOpcode.add ||
      opcode == DemoOpcode.sub ||
      opcode == DemoOpcode.store ||
      opcode == DemoOpcode.beq;
  bool get writesRd =>
      opcode == DemoOpcode.add ||
      opcode == DemoOpcode.sub ||
      opcode == DemoOpcode.addi ||
      opcode == DemoOpcode.load;
  bool get isLoad => opcode == DemoOpcode.load;
  bool get isStore => opcode == DemoOpcode.store;
  bool get isBranch => opcode == DemoOpcode.beq;

  @override
  String toString() {
    switch (opcode) {
      case DemoOpcode.nop:
        return 'nop';
      case DemoOpcode.halt:
        return 'halt';
      case DemoOpcode.add:
        return 'add r$rd, r$rs1, r$rs2';
      case DemoOpcode.sub:
        return 'sub r$rd, r$rs1, r$rs2';
      case DemoOpcode.addi:
        return 'addi r$rd, r$rs1, $imm';
      case DemoOpcode.load:
        return 'load r$rd, $imm(r$rs1)';
      case DemoOpcode.store:
        return 'store r$rs2, $imm(r$rs1)';
      case DemoOpcode.beq:
        final sign = imm >= 0 ? '+' : '';
        return 'beq r$rs1, r$rs2, ${sign}${imm}w';
    }
  }
}

class _IfIdReg {
  final bool valid;
  final int pc;
  final DemoInstruction inst;

  const _IfIdReg({
    required this.valid,
    required this.pc,
    required this.inst,
  });

  const _IfIdReg.empty()
      : valid = false,
        pc = 0,
        inst = const DemoInstruction.nop();

  Map<String, int> toSignals(String prefix) => {
        '$prefix.valid': valid ? 1 : 0,
        '$prefix.pc': pc,
        '$prefix.opcode': inst.opcode.index,
        '$prefix.rd': inst.rd,
        '$prefix.rs1': inst.rs1,
        '$prefix.rs2': inst.rs2,
        '$prefix.imm': inst.imm,
      };
}

class _IdExReg {
  final bool valid;
  final int pc;
  final DemoInstruction inst;
  final int rs1Value;
  final int rs2Value;

  const _IdExReg({
    required this.valid,
    required this.pc,
    required this.inst,
    required this.rs1Value,
    required this.rs2Value,
  });

  const _IdExReg.empty()
      : valid = false,
        pc = 0,
        inst = const DemoInstruction.nop(),
        rs1Value = 0,
        rs2Value = 0;

  bool get memRead => valid && inst.opcode == DemoOpcode.load;
  bool get memWrite => valid && inst.opcode == DemoOpcode.store;
  bool get regWrite => valid && inst.writesRd && inst.rd != 0;

  Map<String, int> toSignals(String prefix) => {
        '$prefix.valid': valid ? 1 : 0,
        '$prefix.pc': pc,
        '$prefix.opcode': inst.opcode.index,
        '$prefix.rd': inst.rd,
        '$prefix.rs1': inst.rs1,
        '$prefix.rs2': inst.rs2,
        '$prefix.imm': inst.imm,
        '$prefix.rs1_value': rs1Value,
        '$prefix.rs2_value': rs2Value,
        '$prefix.mem_read': memRead ? 1 : 0,
        '$prefix.mem_write': memWrite ? 1 : 0,
        '$prefix.reg_write': regWrite ? 1 : 0,
      };
}

class _ExMemReg {
  final bool valid;
  final int pc;
  final DemoInstruction inst;
  final int aluResult;
  final int storeValue;
  final bool branchTaken;
  final int branchTarget;

  const _ExMemReg({
    required this.valid,
    required this.pc,
    required this.inst,
    required this.aluResult,
    required this.storeValue,
    required this.branchTaken,
    required this.branchTarget,
  });

  const _ExMemReg.empty()
      : valid = false,
        pc = 0,
        inst = const DemoInstruction.nop(),
        aluResult = 0,
        storeValue = 0,
        branchTaken = false,
        branchTarget = 0;

  bool get memRead => valid && inst.opcode == DemoOpcode.load;
  bool get memWrite => valid && inst.opcode == DemoOpcode.store;
  bool get regWrite => valid && inst.writesRd && inst.rd != 0;

  Map<String, int> toSignals(String prefix) => {
        '$prefix.valid': valid ? 1 : 0,
        '$prefix.pc': pc,
        '$prefix.opcode': inst.opcode.index,
        '$prefix.rd': inst.rd,
        '$prefix.alu_result': aluResult,
        '$prefix.store_value': storeValue,
        '$prefix.branch_taken': branchTaken ? 1 : 0,
        '$prefix.branch_target': branchTarget,
        '$prefix.mem_read': memRead ? 1 : 0,
        '$prefix.mem_write': memWrite ? 1 : 0,
        '$prefix.reg_write': regWrite ? 1 : 0,
      };
}

class _MemWbReg {
  final bool valid;
  final int pc;
  final DemoInstruction inst;
  final int aluResult;
  final int memData;

  const _MemWbReg({
    required this.valid,
    required this.pc,
    required this.inst,
    required this.aluResult,
    required this.memData,
  });

  const _MemWbReg.empty()
      : valid = false,
        pc = 0,
        inst = const DemoInstruction.nop(),
        aluResult = 0,
        memData = 0;

  bool get regWrite => valid && inst.writesRd && inst.rd != 0;
  int get writeBackValue => inst.isLoad ? memData : aluResult;

  Map<String, int> toSignals(String prefix) => {
        '$prefix.valid': valid ? 1 : 0,
        '$prefix.pc': pc,
        '$prefix.opcode': inst.opcode.index,
        '$prefix.rd': inst.rd,
        '$prefix.alu_result': aluResult,
        '$prefix.mem_data': memData,
        '$prefix.wb_data': writeBackValue,
        '$prefix.reg_write': regWrite ? 1 : 0,
      };
}

class SimplePipelineSnapshot {
  final int cycle;
  final Map<String, Map<String, String>> stages;
  final Map<String, ModuleIoSnapshot> modules;
  final Map<String, int> wires;
  final Map<String, int> pipelineRegisters;
  final List<int> registers;
  final Map<int, int> dataMemory;

  const SimplePipelineSnapshot({
    required this.cycle,
    required this.stages,
    required this.modules,
    required this.wires,
    required this.pipelineRegisters,
    required this.registers,
    required this.dataMemory,
  });

  String format({bool showZeroRegisters = true}) {
    final buffer = StringBuffer()..writeln('Cycle $cycle');
    for (final entry in stages.entries) {
      buffer.writeln('${entry.key}:');
      for (final signal in entry.value.entries) {
        buffer.writeln('  ${signal.key}: ${signal.value}');
      }
    }
    buffer.writeln('Modules:');
    for (final module in modules.entries) {
      buffer.writeln('  ${module.key}:');
      buffer.writeln('    inputs:');
      for (final signal in module.value.inputs.entries) {
        buffer.writeln('      ${signal.key}: ${_formatValue(signal.value)}');
      }
      buffer.writeln('    outputs:');
      for (final signal in module.value.outputs.entries) {
        buffer.writeln('      ${signal.key}: ${_formatValue(signal.value)}');
      }
    }
    buffer.writeln('Wires:');
    for (final entry in wires.entries) {
      buffer.writeln('  ${entry.key}: ${_formatValue(entry.value)}');
    }
    buffer.writeln('Pipeline registers:');
    for (final entry in pipelineRegisters.entries) {
      buffer.writeln('  ${entry.key}: ${_formatValue(entry.value)}');
    }
    buffer.writeln('Register file:');
    for (var i = 0; i < registers.length; i++) {
      if (!showZeroRegisters && registers[i] == 0) continue;
      buffer.writeln('  r$i: ${_formatValue(registers[i])}');
    }
    if (dataMemory.isNotEmpty) {
      buffer.writeln('Data memory:');
      for (final entry in dataMemory.entries) {
        buffer.writeln(
            '  [${_formatValue(entry.key)}]: ${_formatValue(entry.value)}');
      }
    }
    return buffer.toString().trimRight();
  }
}

class ModuleIoSnapshot {
  final Map<String, int> inputs;
  final Map<String, int> outputs;

  const ModuleIoSnapshot({
    required this.inputs,
    required this.outputs,
  });
}

class SimplePipelineCpu {
  final Context context = Context();
  final List<DemoInstruction> instructionMemory;
  final Map<int, int> initialDataMemory;
  final Map<int, int> dataMemory;
  final List<int> registers = List.filled(32, 0);
  final Map<String, Wire> wires = {};
  final List<SimplePipelineSnapshot> trace = [];

  int pc = 0;
  int cycle = 0;
  bool fetchStopped = false;

  _IfIdReg _ifId = const _IfIdReg.empty();
  _IdExReg _idEx = const _IdExReg.empty();
  _ExMemReg _exMem = const _ExMemReg.empty();
  _MemWbReg _memWb = const _MemWbReg.empty();

  SimplePipelineCpu({
    required List<DemoInstruction> program,
    Map<int, int> initialDataMemory = const {},
  })  : instructionMemory = List.unmodifiable(program),
        initialDataMemory = Map.unmodifiable(initialDataMemory),
        dataMemory = Map<int, int>.from(initialDataMemory);

  factory SimplePipelineCpu.demo() => SimplePipelineCpu(
        program: const [
          DemoInstruction.addi(1, 0, 5),
          DemoInstruction.addi(2, 0, 7),
          DemoInstruction.add(3, 1, 2),
          DemoInstruction.store(3, 0, 0),
          DemoInstruction.load(4, 0, 0),
          DemoInstruction.add(5, 4, 1),
          DemoInstruction.halt(),
        ],
      );

  bool get isDone =>
      fetchStopped &&
      !_ifId.valid &&
      !_idEx.valid &&
      !_exMem.valid &&
      !_memWb.valid;

  SimplePipelineSnapshot? get lastSnapshot => trace.isEmpty ? null : trace.last;

  void reset() {
    pc = 0;
    cycle = 0;
    fetchStopped = false;
    registers.fillRange(0, registers.length, 0);
    dataMemory
      ..clear()
      ..addAll(initialDataMemory);
    wires.clear();
    trace.clear();
    _ifId = const _IfIdReg.empty();
    _idEx = const _IdExReg.empty();
    _exMem = const _ExMemReg.empty();
    _memWb = const _MemWbReg.empty();
  }

  List<SimplePipelineSnapshot> run({int maxCycles = 100}) {
    while (!isDone && cycle < maxCycles) {
      step();
    }
    return List.unmodifiable(trace);
  }

  SimplePipelineSnapshot step() {
    if (isDone) {
      return lastSnapshot ?? _snapshot(const {}, const {}, const {});
    }

    cycle++;
    wires.clear();

    final stageDetails = <String, Map<String, String>>{};
    final moduleDetails = <String, ModuleIoSnapshot>{};

    final wbValue = _memWb.writeBackValue;
    _setWire('WB.valid_WB', _memWb.valid ? 1 : 0, width: 1);
    _setWire('WB.rd_WB', _memWb.inst.rd, width: 5);
    _setWire('WB.rf_we_WB', _memWb.regWrite ? 1 : 0, width: 1);
    _setWire('WB.rf_wdata_WB', wbValue);
    if (_memWb.regWrite) {
      registers[_memWb.inst.rd] = _u32(wbValue);
    }
    registers[0] = 0;
    moduleDetails['WB_Mux'] = ModuleIoSnapshot(
      inputs: {
        'alu_result_WB': _memWb.aluResult,
        'pipe_rdata_WB': _memWb.memData,
        'mem_to_reg_WB': _memWb.inst.isLoad ? 1 : 0,
      },
      outputs: {'rf_wdata_WB': wbValue},
    );
    moduleDetails['RegFile.write'] = ModuleIoSnapshot(
      inputs: {
        'rd_WB': _memWb.inst.rd,
        'rf_we_WB': _memWb.regWrite ? 1 : 0,
        'rf_wdata_WB': wbValue,
      },
      outputs: {'reg_r${_memWb.inst.rd}': registers[_memWb.inst.rd]},
    );
    stageDetails['WB'] = {
      'inst': _describe(_memWb.valid, _memWb.inst),
      'rf_we': '${_memWb.regWrite ? 1 : 0}',
      'rd': 'r${_memWb.inst.rd}',
      'write_data': _formatValue(wbValue),
    };

    final memReadData = _exMem.memRead ? dataMemory[_exMem.aluResult] ?? 0 : 0;
    if (_exMem.memWrite) {
      dataMemory[_exMem.aluResult] = _u32(_exMem.storeValue);
    }
    final nextMemWb = _MemWbReg(
      valid: _exMem.valid && !_exMem.inst.isStore && !_exMem.inst.isBranch,
      pc: _exMem.pc,
      inst: _exMem.inst,
      aluResult: _u32(_exMem.aluResult),
      memData: _u32(memReadData),
    );
    moduleDetails['Data_Memory'] = ModuleIoSnapshot(
      inputs: {
        'mem_addr': _exMem.aluResult,
        'mem_wdata': _exMem.storeValue,
        'mem_we': _exMem.memWrite ? 1 : 0,
        'mem_re': _exMem.memRead ? 1 : 0,
      },
      outputs: {'mem_rdata': memReadData},
    );
    moduleDetails['Seg_reg_MEM_WB'] = ModuleIoSnapshot(
      inputs: {
        'rd_MEM': _exMem.inst.rd,
        'rf_we_MEM': _exMem.regWrite ? 1 : 0,
        'alu_result_MEM': _exMem.aluResult,
        'pipe_rdata_MEM': memReadData,
      },
      outputs: {
        'rd_WB': nextMemWb.inst.rd,
        'rf_we_WB': nextMemWb.regWrite ? 1 : 0,
        'alu_result_WB': nextMemWb.aluResult,
        'pipe_rdata_WB': nextMemWb.memData,
      },
    );
    _setWire('MEM.valid_MEM', _exMem.valid ? 1 : 0, width: 1);
    _setWire('MEM.mem_addr_MEM', _exMem.aluResult);
    _setWire('MEM.mem_wdata_MEM', _exMem.storeValue);
    _setWire('MEM.mem_rdata_MEM', memReadData);
    _setWire('MEM.mem_we_MEM', _exMem.memWrite ? 1 : 0, width: 1);
    stageDetails['MEM'] = {
      'inst': _describe(_exMem.valid, _exMem.inst),
      'addr': _formatValue(_exMem.aluResult),
      'write_data': _formatValue(_exMem.storeValue),
      'read_data': _formatValue(memReadData),
      'mem_we': '${_exMem.memWrite ? 1 : 0}',
    };

    final forwardedA = _forward(_idEx.inst.rs1, _idEx.rs1Value);
    final forwardedB = _forward(_idEx.inst.rs2, _idEx.rs2Value);
    final exResult = _execute(_idEx.inst, forwardedA, forwardedB, _idEx.pc);
    final aluSrc2 = _idEx.inst.opcode == DemoOpcode.addi ||
            _idEx.inst.opcode == DemoOpcode.load ||
            _idEx.inst.opcode == DemoOpcode.store
        ? _idEx.inst.imm
        : forwardedB;
    final nextExMem = _ExMemReg(
      valid: _idEx.valid,
      pc: _idEx.pc,
      inst: _idEx.inst,
      aluResult: _u32(exResult.aluResult),
      storeValue: _u32(forwardedB),
      branchTaken: exResult.branchTaken,
      branchTarget: exResult.branchTarget,
    );
    moduleDetails['Forward'] = ModuleIoSnapshot(
      inputs: {
        'rf_we_mem': _exMem.regWrite ? 1 : 0,
        'rf_we_wb': _memWb.regWrite ? 1 : 0,
        'rf_wa_mem': _exMem.inst.rd,
        'rf_wa_wb': _memWb.inst.rd,
        'rf_wd_mem': _exMem.aluResult,
        'rf_wd_wb': _memWb.writeBackValue,
        'rf_ra0_ex': _idEx.inst.rs1,
        'rf_ra1_ex': _idEx.inst.rs2,
        'rj_EX': _idEx.inst.rs1,
        'rk_EX': _idEx.inst.rs2,
        'rj_rdata_EX': _idEx.rs1Value,
        'rk_rdata_EX': _idEx.rs2Value,
        'rd_MEM': _exMem.inst.rd,
        'rf_we_MEM': _exMem.regWrite ? 1 : 0,
        'rd_WB': _memWb.inst.rd,
        'rf_we_WB': _memWb.regWrite ? 1 : 0,
      },
      outputs: {
        'rf_rd0_fe': forwardedA != _idEx.rs1Value ? 1 : 0,
        'rf_rd1_fe': forwardedB != _idEx.rs2Value ? 1 : 0,
        'rf_rd0_fd': forwardedA,
        'rf_rd1_fd': forwardedB,
        'rj_fwd_data': forwardedA,
        'rk_fwd_data': forwardedB,
      },
    );
    moduleDetails['ALU_src_Mux'] = ModuleIoSnapshot(
      inputs: {
        'rj_fwd_data': forwardedA,
        'rk_fwd_data': forwardedB,
        'imm_EX': _idEx.inst.imm,
        'src2_is_imm_EX': aluSrc2 == _idEx.inst.imm ? 1 : 0,
      },
      outputs: {
        'alu_src1': forwardedA,
        'alu_src2': aluSrc2,
      },
    );
    moduleDetails['ALU'] = ModuleIoSnapshot(
      inputs: {
        'alu_src1': forwardedA,
        'alu_src2': aluSrc2,
        'alu_op': _idEx.inst.opcode.index,
      },
      outputs: {'alu_result_EX': exResult.aluResult},
    );
    moduleDetails['Branch'] = ModuleIoSnapshot(
      inputs: {
        'pc_EX': _idEx.pc,
        'rj_fwd_data': forwardedA,
        'rk_fwd_data': forwardedB,
        'imm_EX': _idEx.inst.imm,
        'br_type_EX': _idEx.inst.isBranch ? 1 : 0,
      },
      outputs: {
        'br_en_EX': exResult.branchTaken ? 1 : 0,
        'jump_target_EX': exResult.branchTarget,
      },
    );
    moduleDetails['Seg_reg_EX_MEM'] = ModuleIoSnapshot(
      inputs: {
        'rk_fwd_data': forwardedB,
        'alu_result_EX': exResult.aluResult,
        'mem_read_EX': _idEx.memRead ? 1 : 0,
        'mem_write_EX': _idEx.memWrite ? 1 : 0,
        'rd_EX': _idEx.inst.rd,
        'rf_we_EX': _idEx.regWrite ? 1 : 0,
      },
      outputs: {
        'rd_MEM': nextExMem.inst.rd,
        'rf_we_MEM': nextExMem.regWrite ? 1 : 0,
        'alu_result_MEM': nextExMem.aluResult,
        'rk_rdata_MEM': nextExMem.storeValue,
      },
    );
    _setWire('EX.valid_EX', _idEx.valid ? 1 : 0, width: 1);
    _setWire('EX.alu_src1_EX', forwardedA);
    _setWire('EX.alu_src2_EX', aluSrc2);
    _setWire('EX.alu_result_EX', exResult.aluResult);
    _setWire('EX.br_en_EX', exResult.branchTaken ? 1 : 0, width: 1);
    _setWire('EX.jump_target_EX', exResult.branchTarget);
    stageDetails['EX'] = {
      'inst': _describe(_idEx.valid, _idEx.inst),
      'src1': _formatValue(forwardedA),
      'src2': _formatValue(aluSrc2),
      'alu_result': _formatValue(exResult.aluResult),
      'branch_taken': '${exResult.branchTaken ? 1 : 0}',
      'branch_target': _formatValue(exResult.branchTarget),
    };

    final loadUseStall = _hasLoadUseHazard(_ifId.inst);
    _setWire('ID.load_use_stall_ID', loadUseStall ? 1 : 0, width: 1);
    _setWire('ID.IF_ID_stall', loadUseStall ? 1 : 0, width: 1);
    _setWire('ID.ID_EX_flush', (loadUseStall || exResult.branchTaken) ? 1 : 0,
        width: 1);
    final nextIdEx = loadUseStall || exResult.branchTaken || !_ifId.valid
        ? const _IdExReg.empty()
        : _IdExReg(
            valid: true,
            pc: _ifId.pc,
            inst: _ifId.inst,
            rs1Value: registers[_ifId.inst.rs1],
            rs2Value: registers[_ifId.inst.rs2],
          );
    _setWire('ID.pc_ID', _ifId.pc);
    _setWire('ID.rs1_ID', _ifId.inst.rs1, width: 5);
    _setWire('ID.rs2_ID', _ifId.inst.rs2, width: 5);
    _setWire('ID.rd_ID', _ifId.inst.rd, width: 5);
    _setWire('ID.rj_rdata_ID', registers[_ifId.inst.rs1]);
    _setWire('ID.rk_rdata_ID', registers[_ifId.inst.rs2]);
    moduleDetails['Inst_Decoder'] = ModuleIoSnapshot(
      inputs: {
        'inst_opcode_ID': _ifId.inst.opcode.index,
        'inst_rd_ID': _ifId.inst.rd,
        'inst_rs1_ID': _ifId.inst.rs1,
        'inst_rs2_ID': _ifId.inst.rs2,
        'inst_imm_ID': _ifId.inst.imm,
      },
      outputs: {
        'rj_ID': _ifId.inst.rs1,
        'rk_ID': _ifId.inst.rs2,
        'rd_ID': _ifId.inst.rd,
        'imm_ID': _ifId.inst.imm,
        'rf_we_ID': _ifId.inst.writesRd ? 1 : 0,
        'mem_read_ID': _ifId.inst.isLoad ? 1 : 0,
        'mem_write_ID': _ifId.inst.isStore ? 1 : 0,
        'br_type_ID': _ifId.inst.isBranch ? 1 : 0,
      },
    );
    moduleDetails['RegFile.read'] = ModuleIoSnapshot(
      inputs: {
        'rj_ID': _ifId.inst.rs1,
        'rk_ID': _ifId.inst.rs2,
      },
      outputs: {
        'rj_rdata_ID': registers[_ifId.inst.rs1],
        'rk_rdata_ID': registers[_ifId.inst.rs2],
      },
    );
    moduleDetails['Hazard'] = ModuleIoSnapshot(
      inputs: {
        'rf_wa_ex': _idEx.inst.rd,
        'rf_ra0_id': _ifId.inst.rs1,
        'rf_ra1_id': _ifId.inst.rs2,
        'mem_read_ex': _idEx.memRead ? 1 : 0,
        'br_en_ex': exResult.branchTaken ? 1 : 0,
        'rd_EX': _idEx.inst.rd,
        'mem_read_EX': _idEx.memRead ? 1 : 0,
        'rj_ID': _ifId.inst.rs1,
        'rk_ID': _ifId.inst.rs2,
        'br_en_EX': exResult.branchTaken ? 1 : 0,
      },
      outputs: {
        'pc_en': loadUseStall ? 0 : 1,
        'pc_stall': loadUseStall ? 1 : 0,
        'IF_ID_stall': loadUseStall ? 1 : 0,
        'IF_ID_flush': exResult.branchTaken ? 1 : 0,
        'ID_EX_flush': (loadUseStall || exResult.branchTaken) ? 1 : 0,
      },
    );
    moduleDetails['Seg_reg_ID_EX'] = ModuleIoSnapshot(
      inputs: {
        'ID_EX_flush': (loadUseStall || exResult.branchTaken) ? 1 : 0,
        'pc_ID': _ifId.pc,
        'rj_rdata_ID': registers[_ifId.inst.rs1],
        'rk_rdata_ID': registers[_ifId.inst.rs2],
        'rd_ID': _ifId.inst.rd,
        'rf_we_ID': _ifId.inst.writesRd ? 1 : 0,
      },
      outputs: {
        'pc_EX': nextIdEx.pc,
        'rj_rdata_EX': nextIdEx.rs1Value,
        'rk_rdata_EX': nextIdEx.rs2Value,
        'rd_EX': nextIdEx.inst.rd,
        'rf_we_EX': nextIdEx.regWrite ? 1 : 0,
      },
    );
    stageDetails['ID'] = {
      'inst': _describe(_ifId.valid, _ifId.inst),
      'rs1': 'r${_ifId.inst.rs1}=${_formatValue(registers[_ifId.inst.rs1])}',
      'rs2': 'r${_ifId.inst.rs2}=${_formatValue(registers[_ifId.inst.rs2])}',
      'rd': 'r${_ifId.inst.rd}',
      'stall': '${loadUseStall ? 1 : 0}',
    };

    final fetchResult =
        _fetch(loadUseStall, exResult.branchTaken, exResult.branchTarget);
    final nextIfId = fetchResult.nextIfId;
    moduleDetails['PC_plus'] = ModuleIoSnapshot(
      inputs: {'pc_IF': pc},
      outputs: {'pc_plus_4': pc + 4},
    );
    moduleDetails['NPC_Mux'] = ModuleIoSnapshot(
      inputs: {
        'jump_target_EX': exResult.branchTarget,
        'pc_plus_4': pc + 4,
        'br_en_EX': exResult.branchTaken ? 1 : 0,
      },
      outputs: {'npc': fetchResult.nextPc},
    );
    moduleDetails['PC'] = ModuleIoSnapshot(
      inputs: {
        'npc': fetchResult.nextPc,
        'pc_stall': loadUseStall ? 1 : 0,
      },
      outputs: {'pc_IF': loadUseStall ? pc : fetchResult.nextPc},
    );
    moduleDetails['Inst_Memory'] = ModuleIoSnapshot(
      inputs: {'pc_IF': pc},
      outputs: {'inst_opcode_IF': fetchResult.fetchedInst.opcode.index},
    );
    moduleDetails['Seg_reg_IF_ID'] = ModuleIoSnapshot(
      inputs: {
        'IF_ID_stall': loadUseStall ? 1 : 0,
        'IF_ID_flush': exResult.branchTaken ? 1 : 0,
        'pc_IF': pc,
        'inst_opcode_IF': fetchResult.fetchedInst.opcode.index,
      },
      outputs: {
        'pc_ID': nextIfId.pc,
        'inst_opcode_ID': nextIfId.inst.opcode.index,
      },
    );
    _setWire('IF.pc_IF', pc);
    _setWire('IF.pc_plus_4_IF', pc + 4);
    _setWire('IF.npc_IF', fetchResult.nextPc);
    _setWire('IF.inst_opcode_IF', fetchResult.fetchedInst.opcode.index);
    _setWire('IF.pc_stall', loadUseStall ? 1 : 0, width: 1);
    _setWire('IF.IF_ID_flush', exResult.branchTaken ? 1 : 0, width: 1);
    stageDetails['IF'] = {
      'inst': _describe(fetchResult.nextIfId.valid, fetchResult.fetchedInst),
      'pc': _formatValue(pc),
      'next_pc': _formatValue(fetchResult.nextPc),
      'stalled': '${loadUseStall ? 1 : 0}',
      'flushed': '${exResult.branchTaken ? 1 : 0}',
    };

    _addConfiguredModuleSnapshots(
      moduleDetails,
      values: {
        'pc_IF': pc,
        'npc': fetchResult.nextPc,
        'pc_stall': loadUseStall ? 1 : 0,
        'pc_plus_4': pc + 4,
        'jump_target_EX': exResult.branchTarget,
        'br_en_EX': exResult.branchTaken ? 1 : 0,
        'br_en': exResult.branchTaken ? 1 : 0,
        'IF_ID_stall': loadUseStall ? 1 : 0,
        'IF_ID_flush': exResult.branchTaken ? 1 : 0,
        'ID_EX_flush': (loadUseStall || exResult.branchTaken) ? 1 : 0,
        'inst_IF': fetchResult.fetchedInst.opcode.index,
        'inst_ID': _ifId.inst.opcode.index,
        'src1_sel_ID': _ifId.inst.isBranch ? 1 : 0,
        'src2_sel_ID': _ifId.inst.opcode == DemoOpcode.addi ||
                _ifId.inst.opcode == DemoOpcode.load ||
                _ifId.inst.opcode == DemoOpcode.store
            ? 1
            : 0,
        'imm_ID': _ifId.inst.imm,
        'rj_ID': _ifId.inst.rs1,
        'rk_ID': _ifId.inst.rs2,
        'rd_ID': _ifId.inst.rd,
        'rf_we_ID': _ifId.inst.writesRd ? 1 : 0,
        'br_type_ID': _ifId.inst.isBranch ? 1 : 0,
        'mem_type_ID': _ifId.inst.isLoad ? 1 : (_ifId.inst.isStore ? 2 : 0),
        'alu_op_ID': _ifId.inst.opcode.index,
        'rd_WB': _memWb.inst.rd,
        'rf_we_WB': _memWb.regWrite ? 1 : 0,
        'rf_wdata_WB': wbValue,
        'rj_rdata_ID': registers[_ifId.inst.rs1],
        'rk_rdata_ID': registers[_ifId.inst.rs2],
        'rj_EX': nextIdEx.inst.rs1,
        'rk_EX': nextIdEx.inst.rs2,
        'br_type_EX': nextIdEx.inst.isBranch ? 1 : 0,
        'imm_EX': nextIdEx.inst.imm,
        'pc_EX': nextIdEx.pc,
        'rj_rdata_EX': nextIdEx.rs1Value,
        'rk_rdata_EX': nextIdEx.rs2Value,
        'src1_sel_EX': nextIdEx.inst.isBranch ? 1 : 0,
        'src2_sel_EX': nextIdEx.inst.opcode == DemoOpcode.addi ||
                nextIdEx.inst.opcode == DemoOpcode.load ||
                nextIdEx.inst.opcode == DemoOpcode.store
            ? 1
            : 0,
        'alu_op_EX': nextIdEx.inst.opcode.index,
        'mem_type_EX': nextIdEx.memRead ? 1 : (nextIdEx.memWrite ? 2 : 0),
        'rd_EX': nextIdEx.inst.rd,
        'rf_we_EX': nextIdEx.regWrite ? 1 : 0,
        'rj_fwd_data': forwardedA,
        'rk_fwd_data': forwardedB,
        'fwd_rj_data': forwardedA,
        'fwd_rk_data': forwardedB,
        'fwd_rj_en': forwardedA != _idEx.rs1Value ? 1 : 0,
        'fwd_rk_en': forwardedB != _idEx.rs2Value ? 1 : 0,
        'alu_src1': forwardedA,
        'alu_src2': aluSrc2,
        '4': 4,
        'br_ex_EX': exResult.branchTaken ? 1 : 0,
        'alu_result_EX': exResult.aluResult,
        'rd_MEM': nextExMem.inst.rd,
        'rf_we_MEM': nextExMem.regWrite ? 1 : 0,
        'alu_result_MEM': nextExMem.aluResult,
        'rk_rdata_MEM': nextExMem.storeValue,
        'mem_type_MEM': nextExMem.memRead ? 1 : (nextExMem.memWrite ? 2 : 0),
        'mem_rdata': memReadData,
        'pipe_rdata_MEM': memReadData,
        'mem_wdata': nextExMem.storeValue,
        'mem_addr': nextExMem.aluResult,
        'mem_we': nextExMem.memWrite ? 1 : 0,
        'pipe_rdata_WB': nextMemWb.memData,
        'alu_result_WB': nextMemWb.aluResult,
        'mem_type_WB': nextMemWb.inst.isLoad ? 1 : 0,
      },
    );

    pc = fetchResult.nextPc;
    _ifId = nextIfId;
    _idEx = nextIdEx;
    _exMem = nextExMem;
    _memWb = nextMemWb;

    final snapshot = _snapshot(stageDetails, moduleDetails, _pipelineSignals());
    trace.add(snapshot);
    return snapshot;
  }

  void _addConfiguredModuleSnapshots(
    Map<String, ModuleIoSnapshot> modules, {
    required Map<String, int> values,
  }) {
    void add(String name, Map<String, dynamic> ports) {
      modules[name] = ModuleIoSnapshot(
        inputs: _ports(ports, 'input', values),
        outputs: _ports(ports, 'output', values),
      );
    }

    add('PC_plus', lipes_names.config.PC_plus);
    add('NPC_Mux', lipes_names.config.NPC_Mux);
    add('PC', lipes_names.config.PC);
    add('Seg_reg_IF_ID', lipes_names.config.Seg_reg_IF_ID);
    add('Inst_Decoder', lipes_names.config.Inst_Decoder);
    add('Reg_File', lipes_names.config.Reg_File);
    add('Seg_reg_ID_EX', lipes_names.config.Seg_reg_ID_EX);
    add('FWD_rj', lipes_names.config.FWD_rj);
    add('FWD_rk', lipes_names.config.FWD_rk);
    add('ALU_src1_Mux', lipes_names.config.ALU_src1_Mux);
    add('ALU_src2_Mux', lipes_names.config.ALU_src2_Mux);
    add('Branch', lipes_names.config.Branch);
    add('ALU', lipes_names.config.ALU);
    add('Seg_reg_EX_MEM', lipes_names.config.Seg_reg_EX_MEM);
    add('Memory_Control', lipes_names.config.Memory_Control);
    add('Seg_reg_MEM_WB', lipes_names.config.Seg_reg_MEM_WB);
    add('WB_Mux', lipes_names.config.WB_Mux);
    add('Hazard', lipes_names.config.Hazard);
    add('Forward', lipes_names.config.Forward);
    add('Inst_Memory', lipes_names.config.Inst_Memory);
    add('Data_Memory', lipes_names.config.Data_Memory);
  }

  Map<String, int> _ports(
    Map<String, dynamic> ports,
    String direction,
    Map<String, int> values,
  ) {
    final names = (ports[direction] as List).cast<String>();
    return {
      for (final name in names) name: values[name] ?? 0,
    };
  }

  String dumpLastStep({bool showZeroRegisters = true}) {
    return (lastSnapshot ?? step())
        .format(showZeroRegisters: showZeroRegisters);
  }

  String dumpTrace({bool showZeroRegisters = false}) {
    return trace
        .map(
            (snapshot) => snapshot.format(showZeroRegisters: showZeroRegisters))
        .join('\n\n');
  }

  _FetchResult _fetch(bool stall, bool branchTaken, int branchTarget) {
    if (stall) {
      return _FetchResult(_ifId, pc, _ifId.inst);
    }
    if (branchTaken) {
      return _FetchResult(
          const _IfIdReg.empty(), branchTarget, const DemoInstruction.nop());
    }
    if (fetchStopped) {
      return _FetchResult(
          const _IfIdReg.empty(), pc, const DemoInstruction.nop());
    }

    final index = pc ~/ 4;
    final fetched = index >= 0 && index < instructionMemory.length
        ? instructionMemory[index]
        : const DemoInstruction.halt();
    final nextPc = pc + 4;
    if (fetched.isHalt) {
      fetchStopped = true;
    }
    return _FetchResult(
      _IfIdReg(valid: !fetched.isNop, pc: pc, inst: fetched),
      nextPc,
      fetched,
    );
  }

  bool _hasLoadUseHazard(DemoInstruction idInst) {
    if (!_ifId.valid || !_idEx.memRead || !_idEx.inst.writesRd) return false;
    final loadRd = _idEx.inst.rd;
    if (loadRd == 0) return false;
    return (idInst.readsRs1 && idInst.rs1 == loadRd) ||
        (idInst.readsRs2 && idInst.rs2 == loadRd);
  }

  int _forward(int sourceRegister, int originalValue) {
    if (sourceRegister == 0) return 0;
    if (_exMem.regWrite &&
        !_exMem.memRead &&
        _exMem.inst.rd == sourceRegister) {
      return _exMem.aluResult;
    }
    if (_memWb.regWrite && _memWb.inst.rd == sourceRegister) {
      return _memWb.writeBackValue;
    }
    return originalValue;
  }

  _ExecuteResult _execute(DemoInstruction inst, int a, int b, int instPc) {
    switch (inst.opcode) {
      case DemoOpcode.nop:
      case DemoOpcode.halt:
        return const _ExecuteResult(0, false, 0);
      case DemoOpcode.add:
        return _ExecuteResult(_u32(a + b), false, 0);
      case DemoOpcode.sub:
        return _ExecuteResult(_u32(a - b), false, 0);
      case DemoOpcode.addi:
        return _ExecuteResult(_u32(a + inst.imm), false, 0);
      case DemoOpcode.load:
      case DemoOpcode.store:
        return _ExecuteResult(_u32(a + inst.imm), false, 0);
      case DemoOpcode.beq:
        final taken = a == b;
        return _ExecuteResult(0, taken, instPc + inst.imm * 4);
    }
  }

  void _setWire(String name, int value, {int width = 32}) {
    final normalized = width == 32 ? _u32(value) : value & ((1 << width) - 1);
    final wire = wires.putIfAbsent(
      name,
      () => Wire(context, name: name, width: width),
    );
    wire.setValue(Value.fromInt(context, normalized, width));
  }

  Map<String, int> _wireValues() => {
        for (final entry in wires.entries) entry.key: entry.value.getValue(),
      };

  Map<String, int> _pipelineSignals() => {
        ..._ifId.toSignals('IF_ID'),
        ..._idEx.toSignals('ID_EX'),
        ..._exMem.toSignals('EX_MEM'),
        ..._memWb.toSignals('MEM_WB'),
      };

  SimplePipelineSnapshot _snapshot(
    Map<String, Map<String, String>> stages,
    Map<String, ModuleIoSnapshot> modules,
    Map<String, int> pipelineRegisters,
  ) {
    return SimplePipelineSnapshot(
      cycle: cycle,
      stages: Map.unmodifiable(stages),
      modules: Map.unmodifiable(modules),
      wires: Map.unmodifiable(_wireValues()),
      pipelineRegisters: Map.unmodifiable(pipelineRegisters),
      registers: List.unmodifiable(registers),
      dataMemory: Map.unmodifiable(Map.fromEntries(
        dataMemory.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      )),
    );
  }
}

class _FetchResult {
  final _IfIdReg nextIfId;
  final int nextPc;
  final DemoInstruction fetchedInst;

  const _FetchResult(this.nextIfId, this.nextPc, this.fetchedInst);
}

class _ExecuteResult {
  final int aluResult;
  final bool branchTaken;
  final int branchTarget;

  const _ExecuteResult(this.aluResult, this.branchTaken, this.branchTarget);
}

String _describe(bool valid, DemoInstruction inst) =>
    valid ? inst.toString() : 'bubble';

String _formatValue(int value) {
  final unsigned = _u32(value);
  return '0x${unsigned.toRadixString(16).padLeft(8, '0')} ($value)';
}

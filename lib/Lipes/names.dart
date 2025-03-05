class config {
  static const PC_plus = {'input': ['pc_IF'], 'output': ['pc_plus_4']};
  static const NPC_Mux = {'input': ['jump_target_EX', 'pc_plus_4', 'br_en_EX'], 'output': ['npc']};
  static const PC = {'input': ['npc', 'pc_stall'], 'output': ['pc_IF']};
  static const Seg_reg_IF_ID = {'input': ['IF_ID_stall', 'IF_ID_flush', 'pc_IF', 'inst_IF'], 'output': ['pc_ID', 'inst_ID']};
  static const Inst_Decoder = {'input': ['inst_ID'], 'output': ['src1_sel_ID', 'src2_sel_ID', 'imm_ID', 'rj_ID', 'rk_ID', 'rd_ID', 'rf_we_ID', 'br_type_ID', 'mem_type_ID', 'alu_op_ID']};
  static const Reg_File = {'input': ['rj_ID', 'rk_ID', 'rd_WB', 'rf_we_WB', 'rf_wdata_WB'], 'output': ['rj_rdata_ID', 'rk_rdata_ID']};
  static const Seg_reg_ID_EX = {'input': ['ID_EX_flush', 'pc_ID', 'src1_sel_ID', 'src2_sel_ID', 'imm_ID', 'rj_rdata_ID', 'rk_rdata_ID', 'rd_ID', 'rf_we_ID', 'br_type_ID', 'mem_type_ID', 'alu_op_ID'], 'output': ['rj_EX', 'rk_EX', 'br_type_EX', 'imm_EX', 'pc_EX', 'rj_rdata_EX', 'rk_rdata_EX', 'src1_sel_EX', 'src2_sel_EX', 'alu_op_EX', 'mem_type_EX', 'rd_EX', 'rf_we_EX']};
  static const FWD_rj = {'input': ['rj_rdata_EX', 'fwd_rj_data', 'fwd_rj_en'], 'output': ['rj_fwd_data']};
  static const FWD_rk = {'input': ['rk_rdata_EX', 'fwd_rk_data', 'fwd_rk_en'], 'output': ['rk_fwd_data']};
  static const ALU_src1_Mux = {'input': ['rj_fwd_data', 'pc_EX', 'src1_sel_EX'], 'output': ['alu_src1']};
  static const ALU_src2_Mux = {'input': ['rk_fwd_data', 'imm_EX', '4', 'src2_sel_EX'], 'output': ['alu_src2']};
  static const Branch = {'input': ['pc_EX', 'rj_fwd_data', 'rk_fwd_data', 'imm_EX', 'br_type_EX'], 'output': ['br_ex_EX', 'jump_target_EX']};
  static const ALU = {'input': ['alu_src1', 'alu_src2', 'alu_op_EX'], 'output': ['alu_result_EX']};
  static const Seg_reg_EX_MEM = {'input': ['rk_fwd_data', 'alu_result_EX', 'mem_type_EX', 'rd_EX', 'rf_we_EX'], 'output': ['rd_MEM', 'rf_we_MEM', 'alu_result_MEM', 'rk_rdata_MEM', 'mem_type_MEM']};
  static const Memory_Control = {'input': ['mem_type_MEM', 'rk_rdata_MEM', 'alu_result_MEM', 'mem_rdata'], 'output': ['pipe_rdata_MEM', 'mem_wdata', 'mem_addr', 'mem_we']};
  static const Seg_reg_MEM_WB = {'input': ['rd_MEM', 'rf_we_MEM', 'alu_result_MEM', 'pipe_rdata_MEM', 'mem_type_MEM'], 'output': ['rd_WB', 'rf_we_WB', 'alu_result_WB', 'pipe_rdata_WB', 'mem_type_WB']};
  static const WB_Mux = {'input': ['alu_result_WB', 'pipe_rdata_WB', 'mem_type_WB'], 'output': ['rf_wdata_WB']};
  static const Hazard = {'input': ['rd_EX', 'rj_ID', 'rk_ID', 'mem_type_EX', 'br_en'], 'output': ['pc_stall', 'IF_ID_stall', 'IF_ID_flush', 'ID_EX_flush']};
  static const Forward = {'input': ['rj_EX', 'rk_EX', 'rf_we_MEM', 'rd_MEM', 'rf_we_WB', 'rd_WB', 'alu_result_MEM', 'pipe_rdata_WB'], 'output': ['fwd_rj_data', 'fwd_rj_en', 'fwd_rk_data', 'fwd_rk_en']};
  static const Inst_Memory = {'input': ['pc_IF'], 'output': ['inst_IF']};
  static const Data_Memory = {'input': ['mem_wdata', 'mem_addr', 'mem_we'], 'output': ['mem_rdata']};
}

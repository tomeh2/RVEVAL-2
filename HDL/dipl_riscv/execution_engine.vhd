--===============================================================================
--MIT License

--Copyright (c) 2022 Tomislav Harmina

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.
--===============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use WORK.PKG_EE.ALL;
use WORK.PKG_CPU.ALL;
use WORK.PKG_SCHED.ALL;
use WORK.PKG_AXI.ALL;

-- 1) Individual EU pipeline registers should not halt when only the EU is busy, but when the first register after the scheduler is full 
-- (to avoid waiting with empty pipeline regs when they could be filled in the meantime) (perf. improvement)

entity execution_engine is
    port(
        cdb_out : out cdb_type;
    
        next_uop : in uop_decoded_type;

        dcache_read_addr : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        dcache_read_data : in std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        dcache_read_valid : out std_logic;
        dcache_read_ready : in std_logic;
        dcache_read_hit : in std_logic;
        dcache_read_miss : in std_logic;
        
        dcache_write_addr : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        dcache_write_data : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        dcache_write_size : out std_logic_vector(1 downto 0);
        dcache_write_cacheop : out std_logic_vector(1 downto 0);
        dcache_write_valid : out std_logic;
        dcache_write_ready : in std_logic;
        dcache_write_hit : in std_logic;
        dcache_write_miss : in std_logic;
        
        dcache_loaded_cacheline_tag : in std_logic_vector(DCACHE_TAG_SIZE - 1 downto 0);
        dcache_loaded_cacheline_tag_valid : in std_logic;

        fifo_ready : in std_logic;
        fifo_read_en : out std_logic;
        
        fe_branch_mask : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        fe_branch_predicted_pc : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        fe_branch_prediction : in std_logic;
        
        perfcntr_br_targ_mispred : in std_logic;
        perfcntr_bc_empty : in std_logic;
        perfcntr_icache_stall : in std_logic;
        
        perfcntr_fifo_full : in std_logic;
        
        perf_commit_ready : out std_logic;
        
        reset : in std_logic;
        clk : in std_logic
    );
end execution_engine;

architecture Structural of execution_engine is
    -- ========== PIPELINE REGISTERS ==========
    -- The second _x (where x is a number) indicates what scheduler output port the pipeline register is attached to. This allows us to control the pipeline
    -- registers of each scheduler output port independently.
    
    signal pipeline_reg_1 : execution_engine_pipeline_register_1_type;
    signal pipeline_reg_1_next : execution_engine_pipeline_register_1_type;
    signal pipeline_reg_1_we : std_logic;
    
    signal pipeline_reg_2_0 : execution_engine_pipeline_register_2_0_type;
    signal pipeline_reg_2_0_next : execution_engine_pipeline_register_2_0_type;
    signal pipeline_reg_2_0_we : std_logic;
    
    signal pipeline_reg_2_1 : execution_engine_pipeline_register_2_1_type;
    signal pipeline_reg_2_1_next : execution_engine_pipeline_register_2_1_type;
    signal pipeline_reg_2_1_we : std_logic;
    
    signal pipeline_reg_3_0 : execution_engine_pipeline_register_3_0_type;
    signal pipeline_reg_3_0_next : execution_engine_pipeline_register_3_0_type;
    signal pipeline_reg_3_0_we : std_logic;
    
    signal pipeline_reg_3_1 : execution_engine_pipeline_register_3_1_type;
    signal pipeline_reg_3_1_next : execution_engine_pipeline_register_3_1_type;
    signal pipeline_reg_3_1_we : std_logic;
    
    signal pipeline_reg_4_0 : execution_engine_pipeline_register_4_0_type;
    signal pipeline_reg_4_0_next : execution_engine_pipeline_register_4_0_type;
    signal pipeline_reg_4_0_we : std_logic;
    
    signal pipeline_reg_4_1 : execution_engine_pipeline_register_4_1_type;
    signal pipeline_reg_4_1_next : execution_engine_pipeline_register_4_1_type;
    signal pipeline_reg_4_1_we : std_logic;

    -- ========================================
    
    -- ========== BRANCH PREDICTION TABLE ==========
    signal bpt_branch_predicted_outcome : std_logic;
    signal bpt_branch_predicted_target_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    -- =============================================
    
    -- ========== REGISTER RENAMING SIGNALS ==========
    signal rf_phys_dest_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    signal rf_phys_src_reg_1_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    signal rf_phys_src_reg_1_addr_valid : std_logic;
    signal rf_phys_src_reg_2_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    signal rf_phys_src_reg_2_addr_valid : std_logic;
    
    signal freed_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    
    signal raa_get_en : std_logic;
    signal raa_put_en : std_logic;
    
    signal raa_empty : std_logic;
    -- ===============================================
    
    -- ========== REGISTER FILE SIGNALS ==========
    signal rf_rd_data_1 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal rf_rd_data_2 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal rf_rd_data_3 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal rf_rd_data_4 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
    signal rf_write_en : std_logic;
    -- ===========================================

    -- ========== SCHEDULER CONTROL SIGNALS ==========
    signal sched_full : std_logic;
    -- ===============================================
    
    -- ========== RESERVATION STATION PORTS ==========
    signal sched_uop_out_0 : uop_exec_type;
    signal sched_uop_out_0_valid : std_logic;
    signal sched_uop_out_1 : uop_exec_type;
    signal sched_uop_out_1_valid : std_logic;
    -- ================================================
    
    -- ========== REORDER BUFFER SIGNALS ==========
    signal rob_head_operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
    signal rob_head_arch_dest_reg : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
    signal rob_head_phys_dest_reg : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    
    signal rob_alloc_instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
    signal rob_pc_out : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    
    signal rob_commit_ready : std_logic;
    signal rob_full : std_logic;
    signal rob_empty : std_logic;
    -- ============================================
    
    -- ========== LOAD - STORE UNIT SIGNALS ==========
    signal lsu_gen_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal sq_calc_addr_tag : std_logic_vector(integer(ceil(log2(real(SQ_ENTRIES)))) - 1 downto 0);
    signal sq_calc_addr_valid : std_logic;
    signal lq_calc_addr_tag : std_logic_vector(integer(ceil(log2(real(LQ_ENTRIES)))) - 1 downto 0); 
    signal lq_calc_addr_valid : std_logic;
    
    signal sq_store_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal sq_store_data_tag : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    signal sq_store_data_valid : std_logic;
    
    signal sq_full : std_logic;
    signal lq_full : std_logic;
    
    signal sq_enqueue_en : std_logic;
    signal lq_enqueue_en : std_logic;
    signal lq_retire_en : std_logic;
    
    signal sq_alloc_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
    signal lq_alloc_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
    
    signal sq_data_tag : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);       
    signal lq_dest_tag : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    
    signal sq_retire_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
    signal sq_retire_tag_valid : std_logic;

    -- ===============================================
    signal next_uop_full : uop_full_type;
    signal next_uop_exec : uop_exec_type;
    signal next_uop_store : std_logic;
    signal next_uop_load : std_logic;
    signal next_uop_init_commit_ready : std_logic;
    
    -- ========== COMMON DATA BUS ==========
    signal cdb : cdb_type;
    
    signal cdb_request_0 : std_logic;
    signal cdb_request_1 : std_logic;
    
    signal cdb_granted_0 : std_logic;
    signal cdb_granted_1 : std_logic;
    
    signal cdb_0 : cdb_type;
    signal cdb_1 : cdb_type;
    -- =====================================
    
    -- =========== CONTROL SIGNALS ===========
    signal stall_1 : std_logic;
    signal stall_2 : std_logic;
    signal eu_0_ready : std_logic;
    signal eu_1_ready : std_logic;
    
    signal is_cond_branch_commit : std_logic;
    
    signal i_branch_mispredict_detected : std_logic;
    -- =======================================

    signal csr_read_val : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal debug_rat : debug_rat_type;
begin
    -- ========================================================================================
    --                                PIPELINE REGISTER LOGIC
    -- ========================================================================================
    
    pipeline_reg_1_we <= (not stall_2 and fifo_ready and not raa_empty) or (not pipeline_reg_1.valid and not raa_empty and fifo_ready);
    
    pipeline_reg_2_0_we <= pipeline_reg_3_0_we or not pipeline_reg_2_0.valid;
    pipeline_reg_3_0_we <= pipeline_reg_4_0_we or not pipeline_reg_3_0.valid;
    pipeline_reg_4_0_we <= eu_0_ready or not pipeline_reg_4_0.valid;
    
    pipeline_reg_2_1_we <= pipeline_reg_3_1_we or not pipeline_reg_2_1.valid;
    pipeline_reg_3_1_we <= pipeline_reg_4_1_we or not pipeline_reg_3_1.valid;
    pipeline_reg_4_1_we <= eu_1_ready or not pipeline_reg_4_1.valid;
    pipeline_reg_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_1.valid <= '0';
                pipeline_reg_2_0 <= EE_PIPELINE_REG_2_0_RESET;
                pipeline_reg_2_1 <= EE_PIPELINE_REG_2_1_RESET;
                pipeline_reg_3_0 <= EE_PIPELINE_REG_3_0_RESET;
                pipeline_reg_3_1 <= EE_PIPELINE_REG_3_1_RESET;
                pipeline_reg_4_0 <= EE_PIPELINE_REG_4_0_RESET;
                pipeline_reg_4_1 <= EE_PIPELINE_REG_4_1_RESET;
            else
                if (pipeline_reg_1_we = '1') then
                    pipeline_reg_1 <= pipeline_reg_1_next;
                elsif (stall_2 and pipeline_reg_1.valid and cdb.valid) then
                    pipeline_reg_1.speculated_branches_mask <= pipeline_reg_1.speculated_branches_mask and not cdb.branch_mask;
                end if;
                
                if (cdb.branch_mispredicted and cdb.valid) then
                    pipeline_reg_1.valid <= '0';
                elsif (pipeline_reg_1.valid) then
                    if (stall_2) then
                        pipeline_reg_1.valid <= pipeline_reg_1.valid;
                    else
                        pipeline_reg_1.valid <= pipeline_reg_1_we;
                    end if;
                else
                    pipeline_reg_1.valid <= pipeline_reg_1_we;
                end if;
                
                if (pipeline_reg_2_0_we = '1') then
                    pipeline_reg_2_0 <= pipeline_reg_2_0_next;
                end if;
                
                if (pipeline_reg_3_0_we = '1') then
                    pipeline_reg_3_0 <= pipeline_reg_3_0_next;
                end if;
                
                if (pipeline_reg_4_0_we = '1') then
                    pipeline_reg_4_0 <= pipeline_reg_4_0_next;
                end if;
                
                if (pipeline_reg_2_1_we = '1') then
                    pipeline_reg_2_1 <= pipeline_reg_2_1_next;
                end if;
                
                if (pipeline_reg_3_1_we = '1') then
                    pipeline_reg_3_1 <= pipeline_reg_3_1_next;
                end if;
                
                if (pipeline_reg_4_1_we = '1') then
                    pipeline_reg_4_1 <= pipeline_reg_4_1_next;
                end if;
            end if;
        end if;
    end process;
    
    process(next_uop, rf_phys_dest_reg_addr)
    begin
        pipeline_reg_1_next.pc <= next_uop.pc;
        pipeline_reg_1_next.operation_type <= next_uop.operation_type;
        pipeline_reg_1_next.operation_select <= next_uop.operation_select;
        pipeline_reg_1_next.csr <= next_uop.csr;
        pipeline_reg_1_next.immediate <= next_uop.immediate;
        pipeline_reg_1_next.arch_dest_reg_addr <= next_uop.arch_dest_reg_addr;
        pipeline_reg_1_next.phys_dest_reg_addr <= rf_phys_dest_reg_addr;
        pipeline_reg_1_next.branch_mask <= next_uop.branch_mask;
        pipeline_reg_1_next.speculated_branches_mask <= next_uop.speculated_branches_mask when cdb.valid = '0' else next_uop.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_1_next.branch_predicted_outcome <= next_uop.branch_predicted_outcome;
    end process;
    
    process(sched_uop_out_0, sched_uop_out_0_valid, cdb, i_branch_mispredict_detected)
    begin
        pipeline_reg_2_0_next.uop <= sched_uop_out_0;
        pipeline_reg_2_0_next.uop.speculated_branches_mask <= sched_uop_out_0.speculated_branches_mask when cdb.valid = '0' else sched_uop_out_0.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_2_0_next.valid <= '1' when sched_uop_out_0_valid = '1' and not ((sched_uop_out_0.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;
    
    process(sched_uop_out_1, sched_uop_out_1_valid, cdb, i_branch_mispredict_detected)
    begin
        pipeline_reg_2_1_next.uop <= sched_uop_out_1;
        pipeline_reg_2_1_next.uop.speculated_branches_mask <= sched_uop_out_1.speculated_branches_mask when cdb.valid = '0' else sched_uop_out_1.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_2_1_next.valid <= '1' when sched_uop_out_1_valid = '1' and not ((sched_uop_out_1.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;
    
    process(pipeline_reg_2_0, cdb, i_branch_mispredict_detected)
    begin
        pipeline_reg_3_0_next.uop <= pipeline_reg_2_0.uop;
        pipeline_reg_3_0_next.uop.speculated_branches_mask <= pipeline_reg_2_0.uop.speculated_branches_mask when cdb.valid = '0' else pipeline_reg_2_0.uop.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_3_0_next.valid <= '1' when pipeline_reg_2_0.valid = '1' and not ((pipeline_reg_2_0.uop.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;
    
    process(pipeline_reg_2_1, cdb, i_branch_mispredict_detected)
    begin
        pipeline_reg_3_1_next.uop <= pipeline_reg_2_1.uop;
        pipeline_reg_3_1_next.uop.speculated_branches_mask <= pipeline_reg_2_1.uop.speculated_branches_mask when cdb.valid = '0' else pipeline_reg_2_1.uop.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_3_1_next.valid <= '1' when pipeline_reg_2_1.valid = '1' and not ((pipeline_reg_2_1.uop.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;
    
    process(pipeline_reg_3_0, cdb, i_branch_mispredict_detected, rf_rd_data_1, rf_rd_data_2, rob_pc_out)
    begin
        pipeline_reg_4_0_next.eu_input.instr_tag <= pipeline_reg_3_0.uop.instr_tag;
        pipeline_reg_4_0_next.eu_input.operand_1 <= rf_rd_data_1;
        
        if (CSR_PERF_COUNTERS_EN = true) then
            pipeline_reg_4_0_next.eu_input.operand_2 <= csr_read_val when pipeline_reg_3_0.uop.operation_type = OPTYPE_SYSTEM else rf_rd_data_2;
        else
            pipeline_reg_4_0_next.eu_input.operand_2 <= rf_rd_data_2;
        end if;
        
        pipeline_reg_4_0_next.eu_input.immediate <= pipeline_reg_3_0.uop.immediate;
        pipeline_reg_4_0_next.eu_input.pc <= rob_pc_out;
        pipeline_reg_4_0_next.eu_input.phys_dest_reg_addr <= pipeline_reg_3_0.uop.phys_dest_reg_addr;
        pipeline_reg_4_0_next.eu_input.operation_select <= pipeline_reg_3_0.uop.operation_select;
        pipeline_reg_4_0_next.eu_input.branch_mask <= pipeline_reg_3_0.uop.branch_mask;
        pipeline_reg_4_0_next.eu_input.speculated_branches_mask <= pipeline_reg_3_0.uop.speculated_branches_mask when cdb.valid = '0' else pipeline_reg_3_0.uop.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_4_0_next.eu_input.branch_predicted_outcome <= bpt_branch_predicted_outcome;
        pipeline_reg_4_0_next.eu_input.branch_predicted_target_pc <= bpt_branch_predicted_target_pc;
        pipeline_reg_4_0_next.valid <= '1' when pipeline_reg_3_0.valid = '1' and not ((pipeline_reg_3_0.uop.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;

    process(pipeline_reg_3_1, cdb, i_branch_mispredict_detected, rf_rd_data_3, rf_rd_data_4)
    begin
        pipeline_reg_4_1_next.eu_input.instr_tag <= pipeline_reg_3_1.uop.instr_tag;
        pipeline_reg_4_1_next.eu_input.operand_1 <= rf_rd_data_3;
        pipeline_reg_4_1_next.eu_input.operand_2 <= rf_rd_data_4;
        pipeline_reg_4_1_next.eu_input.immediate <= pipeline_reg_3_1.uop.immediate;
        pipeline_reg_4_1_next.eu_input.phys_src_reg_2_addr <= pipeline_reg_3_1.uop.phys_src_reg_2_addr;
        pipeline_reg_4_1_next.eu_input.stq_tag <= pipeline_reg_3_1.uop.stq_tag;
        pipeline_reg_4_1_next.eu_input.ldq_tag <= pipeline_reg_3_1.uop.ldq_tag;
        pipeline_reg_4_1_next.eu_input.operation_select <= pipeline_reg_3_1.uop.operation_select;
        pipeline_reg_4_1_next.eu_input.speculated_branches_mask <= pipeline_reg_3_1.uop.speculated_branches_mask when cdb.valid = '0' else pipeline_reg_3_1.uop.speculated_branches_mask and not cdb.branch_mask;
        pipeline_reg_4_1_next.valid <= '1' when pipeline_reg_3_1.valid = '1' and not ((pipeline_reg_3_1.uop.speculated_branches_mask and cdb.branch_mask) /= BRANCH_MASK_ZERO and i_branch_mispredict_detected = '1') else '0';
    end process;
    -- ========================================================================================
    -- ========================================================================================
                   
    next_uop_full.pc <= pipeline_reg_1.pc;
    next_uop_full.branch_mask <= pipeline_reg_1.branch_mask;
    next_uop_full.operation_type <= pipeline_reg_1.operation_type;
    next_uop_full.operation_select <= pipeline_reg_1.operation_select;
    next_uop_full.csr <= pipeline_reg_1.csr;
    next_uop_full.immediate <= pipeline_reg_1.immediate;
    next_uop_full.arch_src_reg_1_addr <= pipeline_reg_1.arch_src_reg_1_addr;
    next_uop_full.arch_src_reg_2_addr <= pipeline_reg_1.arch_src_reg_2_addr;
    next_uop_full.arch_dest_reg_addr <= pipeline_reg_1.arch_dest_reg_addr;
    next_uop_full.phys_src_reg_1_addr <= rf_phys_src_reg_1_addr;
    next_uop_full.phys_src_reg_2_addr <= rf_phys_src_reg_2_addr;
    next_uop_full.phys_dest_reg_addr <= pipeline_reg_1.phys_dest_reg_addr;
    next_uop_full.instr_tag <= rob_alloc_instr_tag;
    next_uop_full.stq_tag <= sq_alloc_tag;
    next_uop_full.ldq_tag <= lq_alloc_tag;
    next_uop_full.speculated_branches_mask <= pipeline_reg_1.speculated_branches_mask;
    next_uop_full.branch_predicted_outcome <= pipeline_reg_1.branch_predicted_outcome;
                    
    next_uop_exec.operation_type <= pipeline_reg_1.operation_type;
    next_uop_exec.operation_select <= pipeline_reg_1.operation_select;
    next_uop_exec.csr <= pipeline_reg_1.csr;
    next_uop_exec.immediate <= pipeline_reg_1.immediate;
    next_uop_exec.phys_src_reg_1_addr <= rf_phys_src_reg_1_addr;
    next_uop_exec.phys_src_reg_2_addr <= rf_phys_src_reg_2_addr;
    next_uop_exec.phys_dest_reg_addr <= pipeline_reg_1.phys_dest_reg_addr;
    next_uop_exec.instr_tag <= rob_alloc_instr_tag;
    next_uop_exec.stq_tag <= sq_alloc_tag;
    next_uop_exec.ldq_tag <= lq_alloc_tag;
    next_uop_exec.branch_mask <= pipeline_reg_1.branch_mask;
    next_uop_exec.speculated_branches_mask <= pipeline_reg_1.speculated_branches_mask;

    next_uop_init_commit_ready <= '1' when pipeline_reg_1.operation_type = OPTYPE_STORE else '0';
    --sq_retire_tag_valid <= '1' when rob_head_operation_type = OP_TYPE_STORE and rob_commit_ready = '1' else '0';
    sq_retire_tag_valid <= '1' when rob_head_operation_type = OPTYPE_STORE and rob_commit_ready = '1' else '0';
    lq_retire_en <= '1' when rob_head_operation_type = OPTYPE_LOAD and rob_commit_ready = '1' else '0';

    i_branch_mispredict_detected <= cdb.branch_mispredicted and cdb.valid;
    -- Will need to take SH, SB, LH, LB into consideration in the future
    next_uop_store <= '1' when (pipeline_reg_1.operation_type = OPTYPE_STORE) else '0';
    next_uop_load <= '1' when (pipeline_reg_1.operation_type = OPTYPE_LOAD) else '0';
    
    stall_1 <= not pipeline_reg_1_we;
               
    stall_2 <= rob_full or
               sched_full or
               (sq_full and next_uop_store) or 
               (lq_full and next_uop_load);

    fifo_read_en <= pipeline_reg_1_we;
      
    branch_prediction_table : entity work.branch_prediction_table(rtl)
                              port map(branch_mask_w => fe_branch_mask,
                                       branch_predicted_pc_w => fe_branch_predicted_pc,
                                       branch_prediction_w => fe_branch_prediction,
                                       
                                       branch_mask_r => pipeline_reg_2_0.uop.branch_mask,
                                       branch_predicted_pc_r => bpt_branch_predicted_target_pc,
                                       branch_prediction_r => bpt_branch_predicted_outcome,
                                       rd_en => pipeline_reg_3_0_we,
                                       
                                       clk => clk);
    
    -- ==================================================================================================
    --                                        REGISTER RENAMING
    -- ==================================================================================================
    raa_get_en <= '1' when stall_1 = '0' and next_uop.arch_dest_reg_addr /= "00000" else '0'; 
    raa_put_en <= '1' when rob_commit_ready = '1' and freed_reg_addr /= PHYS_REG_TAG_ZERO else '0';
      
    register_alias_allocator : entity work.register_alias_allocator_2(rtl)
                               generic map(PHYS_REGFILE_ENTRIES => PHYS_REGFILE_ENTRIES,
                                           ARCH_REGFILE_ENTRIES => ARCH_REGFILE_ENTRIES)
                               port map(cdb => cdb,
                                        curr_instr_branch_mask => next_uop.branch_mask,
                                        next_uop_valid => not stall_1,
                               
                                        free_reg_alias => freed_reg_addr,
                                        alloc_reg_alias => rf_phys_dest_reg_addr,
                                        
                                        put_en => raa_put_en,
                                        get_en => raa_get_en,
                                        
                                        empty => raa_empty,
                                        clk => clk,
                                        reset => reset);
      
    -- Holds mappings for in-flight instructions. Updates whenewer a new instruction issues
    frontend_register_alias_table : entity work.register_alias_table(rtl)
                                    generic map(PHYS_REGFILE_ENTRIES => PHYS_REGFILE_ENTRIES,
                                                ARCH_REGFILE_ENTRIES => ARCH_REGFILE_ENTRIES,
                                                ZERO_CYCLE_DELAY => false,
                                                VALID_BIT_INIT_VAL => '1',
                                                ENABLE_VALID_BITS => true)
                                    port map(debug_rat => debug_rat,
                                    
                                             cdb => cdb,
                                    
                                             arch_reg_addr_read_1 => next_uop.arch_src_reg_1_addr,
                                             arch_reg_addr_read_2 => next_uop.arch_src_reg_2_addr,
                                             read_en => not stall_1,
                                             
                                             phys_reg_addr_read_1 => rf_phys_src_reg_1_addr,
                                             phys_reg_addr_read_2 => rf_phys_src_reg_2_addr,
                                             
                                             arch_reg_addr_write_1 => next_uop.arch_dest_reg_addr,
                                             phys_reg_addr_write_1 => rf_phys_dest_reg_addr,
                                             write_en => not stall_1,
                                             
                                             next_instr_branch_mask => next_uop.branch_mask,
                                             next_uop_valid => not stall_1,
                                             
                                             clk => clk,
                                             reset => reset);  
                                         
    retirement_register_alias_table : entity work.register_alias_table(rtl)
                                      generic map(PHYS_REGFILE_ENTRIES => PHYS_REGFILE_ENTRIES,
                                                ARCH_REGFILE_ENTRIES => ARCH_REGFILE_ENTRIES,
                                                ZERO_CYCLE_DELAY => true,
                                                VALID_BIT_INIT_VAL => '0',
                                                ENABLE_VALID_BITS => false)
                                      port map(cdb => CDB_OPEN_CONST,
                                      
                                               arch_reg_addr_read_1 => rob_head_arch_dest_reg,                   -- Architectural address of a register to be marked as free
                                               arch_reg_addr_read_2 => REG_ADDR_ZERO,                       -- Currently unused
                                               read_en => '1',
                                               
                                               phys_reg_addr_read_1 => freed_reg_addr,                      -- Address of a physical register to be marked as free
                                                 
                                               arch_reg_addr_write_1 => rob_head_arch_dest_reg,
                                               phys_reg_addr_write_1 => rob_head_phys_dest_reg,
                                               write_en => rob_commit_ready,
                                                 
                                               next_instr_branch_mask => (others => '0'),
                                               next_uop_valid => '0',
                                                 
                                               clk => clk,
                                               reset => reset);  
                                         
    -- ==================================================================================================
    -- ==================================================================================================
    csr_regs_gen : if (CSR_PERF_COUNTERS_EN = true) generate
        csr_regs : entity work.zicsr_registers(rtl)
                   port map(read_addr => pipeline_reg_2_0.uop.csr,
                            read_data => csr_read_val,
                            
                            perfcntr_br_commit => is_cond_branch_commit,
                            perfcntr_br_mispred_cdb => i_branch_mispredict_detected,
                            perfcntr_br_mispred_fe => perfcntr_br_targ_mispred,
                            perfcntr_bc_empty => perfcntr_bc_empty,
                            
                            perfcntr_icache_stall => perfcntr_icache_stall,
                            
                            dcache_access => (dcache_write_valid and dcache_write_ready) or (dcache_read_valid and dcache_read_ready),
                            dcache_miss => dcache_write_miss or dcache_read_miss,
                            
                            perfcntr_issue_stall_cycles => stall_1,
                            perfcntr_fifo_full => perfcntr_fifo_full,
                            perfcntr_raa_empty => raa_empty,
                            perfcntr_rob_full => rob_full,
                            perfcntr_sched_full => sched_full,
                            perfcntr_lq_full => lq_full,
                            perfcntr_sq_full => sq_full,
                            
                            instr_ret => perf_commit_ready,
                            
                            clk => clk,
                            reset => reset);
    end generate;
    
    rf_write_en <= '1' when cdb.valid = '1' and (cdb.branch_mask = BRANCH_MASK_ZERO or cdb.is_jalr = '1') else '0';
    register_file : entity work.register_file(rtl)
                    generic map(REG_DATA_WIDTH_BITS => CPU_DATA_WIDTH_BITS,
                                REGFILE_ENTRIES => PHYS_REGFILE_ENTRIES)
                    port map(-- DEBUG
                             debug_rat => debug_rat,
                             cdb => cdb,
                    
                             -- ADDRESSES
                             rd_1_addr => pipeline_reg_2_0.uop.phys_src_reg_1_addr,     -- Operand for ALU operations
                             rd_2_addr => pipeline_reg_2_0.uop.phys_src_reg_2_addr,     -- Operand for ALU operations
                             rd_3_addr => pipeline_reg_2_1.uop.phys_src_reg_2_addr,     -- Operand for memory data read operations
                             rd_4_addr => pipeline_reg_2_1.uop.phys_src_reg_1_addr,     -- Operand for memory address operations
                             wr_addr => cdb.phys_dest_reg,
                             
                             
                             alloc_reg_addr => rf_phys_dest_reg_addr,
                             alloc_reg_addr_v => raa_get_en,
                             
                             reg_1_valid_bit_addr => rf_phys_src_reg_1_addr,
                             reg_2_valid_bit_addr => rf_phys_src_reg_2_addr,
                             reg_1_valid => rf_phys_src_reg_1_addr_valid,
                             reg_2_valid => rf_phys_src_reg_2_addr_valid,
                             -- DATA
                             rd_1_data => rf_rd_data_1,
                             rd_2_data => rf_rd_data_2,
                             rd_3_data => rf_rd_data_3,
                             rd_4_data => rf_rd_data_4,
                             wr_data => cdb.data,
                             
                             -- CONTROL
                             rd_1_en => pipeline_reg_3_0_we,
                             rd_2_en => pipeline_reg_3_1_we,
                             en => rf_write_en,
                             reset => reset,
                             clk => clk);
                             
    reorder_buffer : entity work.reorder_buffer(rtl)
                     generic map(ARCH_REGFILE_ENTRIES => ARCH_REGFILE_ENTRIES,
                                 PHYS_REGFILE_ENTRIES => PHYS_REGFILE_ENTRIES,
                                 OPERATION_TYPE_BITS => OPERATION_TYPE_BITS)
                     port map(cdb => cdb,

                              head_operation_type => rob_head_operation_type,
                              head_phys_dest_reg => rob_head_phys_dest_reg,
                              head_stq_tag => sq_retire_tag,
                              head_arch_dest_reg => rob_head_arch_dest_reg,

                              next_instr_tag => rob_alloc_instr_tag,
                              
                              uop => next_uop_full,
                              next_uop_valid => not stall_2 and pipeline_reg_1.valid and not i_branch_mispredict_detected,
                              uop_commit_ready => next_uop_init_commit_ready,
                              
                              write_1_en => not stall_2 and pipeline_reg_1.valid and not i_branch_mispredict_detected,
                              commit_1_en => not i_branch_mispredict_detected,       -- Disable commit at the same time as a mispredict. Causes issues with the register renaming subsystem.

                              rob_entry_addr => pipeline_reg_2_0.uop.instr_tag,
                              pc_rd_en => pipeline_reg_3_0_we,
                              pc_1_out => rob_pc_out,

                              head_valid => rob_commit_ready,
                              full => rob_full,
                              empty => rob_empty,

                              perf_commit_ready => perf_commit_ready,
                              
                              clk => clk,
                              reset => reset);
      
    unified_scheduler : entity work.unified_scheduler(rtl)
                          port map(cdb => cdb,

                                   uop_in_0 => next_uop_exec,
                                   uop_in_0_valid => not stall_2 and pipeline_reg_1.valid and not i_branch_mispredict_detected,
                                   operand_1_valid => rf_phys_src_reg_1_addr_valid,
                                   operand_2_valid => rf_phys_src_reg_2_addr_valid,
                                   
                                   uop_out_0 => sched_uop_out_0,
                                   uop_out_0_valid => sched_uop_out_0_valid,
                                   uop_out_1 => sched_uop_out_1,
                                   uop_out_1_valid => sched_uop_out_1_valid,
                                  
                                   dispatch_en(0) => pipeline_reg_2_0_we,
                                   dispatch_en(1) => pipeline_reg_2_1_we,
                                   full => sched_full,
                                   
                                   clk => clk,
                                   reset => reset);
    -- INTEGER ALU
    -- INTEGER DIV (WIP)
    -- INTEGER MUL (WIP)
    execution_unit_0 : entity work.execution_unit_0_new(rtl)
                               port map(eu_in_0 => pipeline_reg_4_0.eu_input,
                               
                                        cdb => cdb_0,
                                        cdb_request => cdb_request_0,
                                        cdb_granted => cdb_granted_0,
                                        
                                        valid => pipeline_reg_4_0.valid,
                                        ready => eu_0_ready,
                                        
                                        reset => reset,
                                        clk => clk);
                                        
    execution_unit_1 : entity work.execution_unit_1(rtl)
                       port map(cdb => cdb,
                                eu_in_0 => pipeline_reg_4_1.eu_input,
                                
                                valid => pipeline_reg_4_1.valid,
                                ready => eu_1_ready,
                                
                                lsu_generated_address => lsu_gen_addr,
                                lsu_generated_data => sq_store_data,
                                lsu_generated_data_tag => sq_store_data_tag,
                                lsu_generated_data_valid => sq_store_data_valid,
                                lsu_stq_tag => sq_calc_addr_tag,
                                lsu_stq_tag_valid => sq_calc_addr_valid,
                                lsu_ldq_tag => lq_calc_addr_tag,
                                lsu_ldq_tag_valid => lq_calc_addr_valid,
                                
                                reset => reset,
                                clk => clk);
                                        
    load_store_unit : entity work.load_store_unit_cache(rtl)
                      generic map(SQ_ENTRIES => SQ_ENTRIES,
                                  LQ_ENTRIES => LQ_ENTRIES)
                      port map(cdb_in => cdb,
                               cdb_out => cdb_1,
                               cdb_request => cdb_request_1,
                               cdb_granted => cdb_granted_1,

                               next_uop => next_uop_full,
                               next_uop_valid => not stall_2 and pipeline_reg_1.valid and not i_branch_mispredict_detected,
                               instr_tag => rob_alloc_instr_tag,
                      
                               generated_address => lsu_gen_addr,
                               sq_calc_addr_tag => sq_calc_addr_tag,
                               sq_calc_addr_valid => sq_calc_addr_valid,
                               lq_calc_addr_tag => lq_calc_addr_tag,
                               lq_calc_addr_valid => lq_calc_addr_valid,
                               
                               sq_store_data => sq_store_data,
                               sq_store_data_tag => sq_store_data_tag,
                               sq_store_data_valid => sq_store_data_valid,
                               
                               sq_data_tag => sq_data_tag,
                               lq_dest_tag => lq_dest_tag,
                               
                               sq_alloc_tag => sq_alloc_tag,
                               lq_alloc_tag => lq_alloc_tag,
                               
                               sq_full => sq_full,
                               lq_full => lq_full,
                               
                               sq_enqueue_en => sq_enqueue_en,
                               
                               sq_retire_tag => sq_retire_tag,
                               sq_retire_tag_valid => sq_retire_tag_valid,
                               
                               lq_enqueue_en => lq_enqueue_en,
                               lq_retire_en => lq_retire_en,
                               
                               cache_read_addr => dcache_read_addr,
                               cache_read_data => dcache_read_data,
                               cache_read_valid => dcache_read_valid,
                               cache_read_ready => dcache_read_ready,
                               cache_read_hit => dcache_read_hit,
                               cache_read_miss => dcache_read_miss,
                               
                               cache_write_addr => dcache_write_addr,
                               cache_write_data => dcache_write_data,
                               cache_write_size => dcache_write_size,
                               cache_write_cacheop => dcache_write_cacheop,
                               cache_write_valid => dcache_write_valid,
                               cache_write_ready => dcache_write_ready,
                               cache_write_hit => dcache_write_hit,
                               cache_write_miss => dcache_write_miss,
                               
                               loaded_cacheline_tag => dcache_loaded_cacheline_tag,
                               loaded_cacheline_tag_valid => dcache_loaded_cacheline_tag_valid,
                               
                               reset => reset,
                               clk => clk);

    is_cond_branch_commit <= '1' when rob_head_operation_type = OPTYPE_BRANCH and rob_commit_ready = '1' else '0';

    sq_data_tag <= rf_phys_src_reg_2_addr;
    sq_enqueue_en <= '1' when pipeline_reg_1.operation_type = OPTYPE_STORE and pipeline_reg_1.valid = '1' and stall_2 = '0' and i_branch_mispredict_detected = '0' else '0';

    lq_dest_tag <= pipeline_reg_1.phys_dest_reg_addr;
    lq_enqueue_en <= '1' when pipeline_reg_1.operation_type = OPTYPE_LOAD and pipeline_reg_1.valid = '1' and stall_2 = '0' and i_branch_mispredict_detected = '0' else '0';

    cdb_out <= cdb;

    cdb <= cdb_1 when cdb_granted_1 = '1' else
           cdb_0;

    cdb_granted_0 <= cdb_request_0 and (not cdb_request_1);
    
    cdb_granted_1 <= cdb_request_1;
    --cdb_granted_1 <= '0';
   
end structural;

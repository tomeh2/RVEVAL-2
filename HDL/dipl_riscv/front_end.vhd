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

-- TODO: Re-make BTB and connect it with prediction logic in the FE

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.PKG_CPU.ALL;
use STD.TEXTIO.ALL;

entity front_end is
    port(
        cdb : in cdb_type;
        
        fifo_full : in std_logic;
        
        bus_data_read : in std_logic_vector(31 downto 0);
        bus_addr_read : out std_logic_vector(31 downto 0);
        bus_stbr : out std_logic;
        bus_ackr : in std_logic;

        branch_mask : out std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_pc : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_prediction : out std_logic;
        
        decoded_uop : out uop_decoded_type;
        decoded_uop_valid : out std_logic;

        reset : in std_logic;
        clk : in std_logic
    );
end front_end;

architecture Structural of front_end is
    -- DEBUG 
    --type ram_type is array (2 ** 12 - 1 downto 0) of std_logic_vector (32 - 1 downto 0);

--    impure function init_ram_hex return ram_type is
--        file text_file : text open read_mode is "../../../firmware.hex";
--        variable text_line : line;
--        variable ram_content : ram_type;
--        variable temp : std_logic_vector(31 downto 0);
--        begin
--            for i in 0 to 2 ** 12 - 1 loop
--                readline(text_file, text_line);
--                hread(text_line, temp);

--                ram_content(i) := temp;
--				--for j in 0 to 3 loop
--                --    ram_content(i)(8 * (j + 1) - 1 downto 8 * j) := temp(8 * (4 - j) - 1 downto 8 * (3 - j));
--                --end loop;
--            end loop;    
 
--        return ram_content;
--    end function;

    --signal progmem_debug : ram_type := init_ram_hex;

    -- PIPELINE
    signal f1_f2_pipeline_reg : f1_f2_pipeline_reg_type;
    signal f1_f2_pipeline_reg_next : f1_f2_pipeline_reg_type;
    
    signal f2_f3_pipeline_reg : f2_f3_pipeline_reg_type;
    signal f2_f3_pipeline_reg_next : f2_f3_pipeline_reg_type;
    
    signal f3_d1_pipeline_reg : f3_d1_pipeline_reg_type;
    signal f3_d1_pipeline_reg_next : f3_d1_pipeline_reg_type;
    
    signal stall_f1_f3 : std_logic;
    signal stall_f2_d1 : std_logic;
    signal branch_mispredicted : std_logic;
    signal flush_pipeline : std_logic;
    
    -- ICACHE
    signal ic_wait : std_logic;
    
    -- F1 STAGE
    signal bp_in : bp_in_type;
    signal bp_out : bp_out_type;
        
    signal f1_pc_reg : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal f1_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    -- F2 STAGE
    signal f2_ic_data_valid : std_logic;
    signal f2_icache_miss : std_logic;
    
    signal f2_pred_target_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal f2_pred_is_branch : std_logic;
    signal f2_pred_outcome : std_logic;

    -- D1 STAGE
    signal d1_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal d1_instr : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal d1_fifo_insert_ready : std_logic;
    
    signal d1_branch_taken_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal d1_branch_target_mispredict : std_logic;
    signal d1_speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    signal d1_alloc_branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    signal d1_bc_empty : std_logic;
    signal d1_is_jalr : std_logic;
    
    signal d1_is_speculative_br : std_logic;
    signal d1_is_uncond_br : std_logic;
    
    signal d1_instr_dec_uop : uop_instr_dec_type;
    signal d1_target_mispred_recovery_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
begin
    -- ========================== PIPELINE CONTROL ==========================
    pipeline_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                f1_f2_pipeline_reg.valid <= '0';
                f2_f3_pipeline_reg.valid <= '0';
                f3_d1_pipeline_reg.valid <= '0';
            else
                if (flush_pipeline or d1_branch_target_mispredict) then
                    f1_f2_pipeline_reg.valid <= '0';
                elsif (stall_f1_f3 = '0') then
                    f1_f2_pipeline_reg <= f1_f2_pipeline_reg_next;
                end if;
                
                if (flush_pipeline or d1_branch_target_mispredict) then
                    f2_f3_pipeline_reg.valid <= '0';
                elsif (stall_f1_f3 = '0') then
                    f2_f3_pipeline_reg <= f2_f3_pipeline_reg_next;
                end if;
                
                if ((stall_f1_f3 and d1_fifo_insert_ready) or flush_pipeline) then
                    f3_d1_pipeline_reg.valid <= '0';
                elsif (stall_f2_d1 = '0' or (f3_d1_pipeline_reg.valid = '0' and stall_f1_f3 = '0')) then
                    f3_d1_pipeline_reg <= f3_d1_pipeline_reg_next;
                end if;
            end if;
        end if;
    end process;
    
    f1_f2_pipeline_reg_next.pc <= f1_pc;
    
    f2_f3_pipeline_reg_next.pc <= f1_f2_pipeline_reg.pc;
    f2_f3_pipeline_reg_next.branch_pred_target <= f2_pred_target_pc;
    f2_f3_pipeline_reg_next.branch_pred_outcome <= f2_pred_outcome;
    
    f3_d1_pipeline_reg_next.pc <= f2_f3_pipeline_reg.pc;
    f3_d1_pipeline_reg_next.branch_pred_outcome <= f2_f3_pipeline_reg.branch_pred_outcome;
    f3_d1_pipeline_reg_next.branch_pred_target <= f2_f3_pipeline_reg.branch_pred_target;
    
    f1_f2_pipeline_reg_next.valid <= '1';
    f2_f3_pipeline_reg_next.valid <= f1_f2_pipeline_reg.valid;
    f3_d1_pipeline_reg_next.valid <= '0' when stall_f1_f3 or d1_branch_target_mispredict else f2_f3_pipeline_reg.valid;
    
    stall_f2_d1 <= d1_bc_empty or fifo_full;
    stall_f1_f3 <= (ic_wait and f2_f3_pipeline_reg.valid) or (stall_f2_d1 and f3_d1_pipeline_reg.valid);
    branch_mispredicted <= (cdb.valid and cdb.branch_mispredicted);--(debug_cdb_mispred and debug_cdb_valid);----
    flush_pipeline <= branch_mispredicted;-- or debug_clear_pipeline;
    -- ======================================================================

    -- ========================== F1 STAGE ========================== 
    branch_target_buffer : entity work.branch_target_buffer(rtl)
                           port map(pc => f1_pc_reg,
                                    target_addr => f2_pred_target_pc,
                                    hit => f2_pred_is_branch,
                                    stall => stall_f1_f3,
                                    
                                    branch_write_addr => cdb.pc_low_bits,
                                    branch_write_target_addr => cdb.target_addr,
                                    write_en => cdb.branch_taken and cdb.valid,
                                    
                                    clk => clk,
                                    reset => reset);
    
    branch_predictor_gen : if (BP_TYPE = "STATIC") generate
            bp_static : entity work.bp_static(rtl)
                        port map(bp_in => bp_in,
                                bp_out => bp_out,
                                          
                                clk => clk,
                                reset => reset);
        elsif (BP_TYPE = "2BSP") generate
            bp_2bsp : entity work.bp_saturating_counter(rtl)
                      port map(bp_in => bp_in,
                              bp_out => bp_out,
                              stall => stall_f1_f3,
                                          
                              clk => clk,
                              reset => reset);
    end generate;
    
    pc_update_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                f1_pc_reg <= PC_VAL_INIT;
            else
                if (branch_mispredicted = '1') then
                    f1_pc_reg <= cdb.target_addr;--debug_cdb_targ_addr;
                elsif (d1_branch_target_mispredict = '1') then
                    f1_pc_reg <= d1_target_mispred_recovery_pc;
                elsif (f2_pred_is_branch = '1' and f2_pred_outcome = '1' and f1_f2_pipeline_reg.valid = '1') then
                    f1_pc_reg <= std_logic_vector(unsigned(f2_pred_target_pc) + 4);
                elsif (stall_f1_f3 = '0') then
                    f1_pc_reg <= std_logic_vector(unsigned(f1_pc_reg) + 4);
                end if;
            end if;
        end if;
    end process;
    f1_pc <= f2_pred_target_pc when f2_pred_is_branch = '1' and f2_pred_outcome = '1' and d1_branch_target_mispredict = '0' and branch_mispredicted = '0' and f1_f2_pipeline_reg.valid = '1' else f1_pc_reg;
    
    bp_in.fetch_addr <= f1_pc;
    bp_in.put_addr <= cdb.pc_low_bits;
    bp_in.put_outcome <= cdb.branch_taken;
    bp_in.put_en <= '1' when cdb.branch_mask /= BRANCH_MASK_ZERO and cdb.is_jalr = '0' and cdb.valid = '1' else '0';
    
    f2_pred_outcome <= bp_out.predicted_outcome;
    -- ==============================================================
    
    -- ========================== F2 STAGE ==========================
    icache_inst : entity work.icache(rtl)
                  port map(read_addr => f1_pc,
                           read_en => '1',
                           read_cancel => flush_pipeline or d1_branch_target_mispredict,
                           stall => stall_f1_f3,
                           
                           fetching => ic_wait,
                           --hit => ic_wait,
                           miss => f2_icache_miss,
                           data_out => f3_d1_pipeline_reg_next.instruction,
                           data_valid => f2_ic_data_valid,
                           
                           bus_addr_read => bus_addr_read,
                           bus_data_read => bus_data_read,
                           bus_stbr => bus_stbr,
                           bus_ackr => bus_ackr,
                           
                           clk => clk,
                           reset => reset); 
    
    f3_d1_pipeline_reg_next.pc <= f2_f3_pipeline_reg.pc;
    -- ==============================================================
    
    -- ========================== D1 STAGE ==========================
    instruction_decoder_inst : entity work.instruction_decoder(rtl)
                               port map(instruction => f3_d1_pipeline_reg.instruction,
                                        pc => f3_d1_pipeline_reg.pc,
                                        
                                        branch_taken_pc => d1_branch_taken_pc,
                                        
                                        is_speculative_branch => d1_is_speculative_br,
                                        is_uncond_branch => d1_is_uncond_br,
                                        is_jalr => d1_is_jalr,
                                        
                                        uop => d1_instr_dec_uop);
                                        
    branch_controller_inst : entity work.branch_controller(rtl)
                             port map(cdb => cdb,
                             
                                      speculated_branches_mask => d1_speculated_branches_mask,
                                      alloc_branch_mask => d1_alloc_branch_mask,
                                      
                                      branch_alloc_en => ((d1_is_speculative_br and f3_d1_pipeline_reg.valid and not d1_bc_empty and not fifo_full)),
                                      
                                      empty => d1_bc_empty,
                                      
                                      reset => reset,
                                      clk => clk);
                    
    -- Since all branch instructions (except for JALR) have target addresses which can be computed immediately,
    -- We can already resolve most branch target mispredicts
    d1_branch_target_mispredict <= '1' when (((f3_d1_pipeline_reg.branch_pred_outcome = '1' and 
                                            ((f3_d1_pipeline_reg.branch_pred_target /= d1_branch_taken_pc and d1_is_jalr = '0') or      -- Was a branch instruction
                                            (d1_is_speculative_br = '0' and d1_is_uncond_br = '0'))) or
                                            (d1_is_uncond_br = '1' and d1_is_jalr = '0' and 
                                            (f3_d1_pipeline_reg.branch_pred_target /= d1_branch_taken_pc or f3_d1_pipeline_reg.branch_pred_outcome = '0'))) 
                                            and f3_d1_pipeline_reg.valid = '1') else '0';                           -- Was not a branch instruction
                                       
    d1_target_mispred_recovery_pc <= std_logic_vector(unsigned(f3_d1_pipeline_reg.pc) + 4) when ((d1_is_speculative_br = '0' and d1_is_uncond_br = '0') or
                                                                                                (d1_is_speculative_br = '1' and f3_d1_pipeline_reg.branch_pred_outcome = '0'))
                                                                                           else d1_branch_taken_pc;
                                       
    d1_fifo_insert_ready <= not d1_bc_empty and not fifo_full and f3_d1_pipeline_reg.valid;
                                       
    decoded_uop.pc <= f3_d1_pipeline_reg.pc;
    decoded_uop.operation_type <= d1_instr_dec_uop.operation_type;
    decoded_uop.operation_select <= d1_instr_dec_uop.operation_select;
    decoded_uop.csr <= d1_instr_dec_uop.csr;
    decoded_uop.immediate <= d1_instr_dec_uop.immediate;
    decoded_uop.arch_src_reg_1_addr <= d1_instr_dec_uop.arch_src_reg_1_addr;
    decoded_uop.arch_src_reg_2_addr <= d1_instr_dec_uop.arch_src_reg_2_addr;
    decoded_uop.arch_dest_reg_addr <= d1_instr_dec_uop.arch_dest_reg_addr;
    decoded_uop.branch_mask <= d1_alloc_branch_mask;
    decoded_uop.branch_predicted_outcome <= f3_d1_pipeline_reg.branch_pred_outcome;
    decoded_uop.speculated_branches_mask <= d1_speculated_branches_mask;
    decoded_uop_valid <= d1_fifo_insert_ready and not flush_pipeline;
    
    branch_mask <= d1_alloc_branch_mask;
    branch_predicted_pc <= d1_target_mispred_recovery_pc;
    branch_prediction <= f3_d1_pipeline_reg.branch_pred_outcome;
    -- ==============================================================
    
    -- DEBUG!!!!
--    process(all)
--    begin
--        if f3_d1_pipeline_reg.valid = '1' then
--            assert f3_d1_pipeline_reg.instruction = progmem_debug(to_integer(unsigned(f3_d1_pipeline_reg.pc(14 downto 2)))) report "Instruction fetch mismatch!" severity failure;
--        end if;
--    end process;
end Structural;











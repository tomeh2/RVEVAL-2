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
use WORK.PKG_CPU.ALL;
use WORK.PKG_FU.ALL;

-- MODULES --
-- 1) INTEGER ALU
-- 2) INTEGER DIV (WIP)
-- 3) INTEGER MUL (WIP)

entity execution_unit_0 is
    port(
        eu_in_0 : in eu_input_type;
    
        valid : in std_logic;       -- Signals that the input values are valid
        ready : out std_logic;      -- Whether this EU is ready to start executing a new operation
        -- =================================================
        
        -- ==================== CDB ====================
        cdb : out cdb_type; 
        cdb_request : out std_logic;
        cdb_granted : in std_logic;
        -- =============================================
        
        clk : in std_logic;
        reset : in std_logic
    );
end execution_unit_0;

architecture structural of execution_unit_0 is
    signal operand_1 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal operand_2 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal alu_result : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal i_ready : std_logic;
    
    signal alu_comp_result : std_logic;
    signal alu_comp_result_n : std_logic;
    signal branch_taken : std_logic;
    signal branch_target_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal branch_base_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    
    signal pipeline_reg_0 : exec_unit_0_pipeline_reg_0_type;
    signal pipeline_reg_0_next : exec_unit_0_pipeline_reg_0_type;
    
    alias uop_uses_immediate : std_logic is eu_in_0.operation_select(7);
    alias uop_is_branch : std_logic is eu_in_0.operation_select(6);
    alias uop_uses_pc : std_logic is eu_in_0.operation_select(5);
    alias uop_negate_branch_cond : std_logic is eu_in_0.operation_select(4);
    alias uop_alu_op_sel : std_logic_vector(3 downto 0) is eu_in_0.operation_select(3 downto 0);
    
    signal uop_is_jalr : std_logic;
    signal uop_is_jal_jalr : std_logic;
begin
    -- =====================================================
    --                  PIPELINE REGISTERS    
    -- =====================================================
    pipeline_reg_0_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_0 <= EU_0_PIPELINE_REG_0_INIT;
            elsif (i_ready = '1') then
                pipeline_reg_0 <= pipeline_reg_0_next;  
            end if;
        end if;
    end process;
    
    pipeline_reg_0_next.pc_low_bits <= eu_in_0.pc(CDB_PC_BITS + 1 downto 2);            -- PC is ALWAYS 4-aligned so no need to send last two bits
    pipeline_reg_0_next.result <= alu_result;
    pipeline_reg_0_next.target_addr <= branch_target_addr;
    pipeline_reg_0_next.instr_tag <= eu_in_0.instr_tag;
    pipeline_reg_0_next.phys_dest_reg <= eu_in_0.phys_dest_reg_addr;
    pipeline_reg_0_next.branch_mask <= eu_in_0.branch_mask;
    pipeline_reg_0_next.speculated_branches_mask <= eu_in_0.speculated_branches_mask when cdb.valid = '0' else eu_in_0.speculated_branches_mask and not cdb.branch_mask;
    pipeline_reg_0_next.branch_taken <= branch_taken when eu_in_0.branch_mask /= BRANCH_MASK_ZERO else '0';
    pipeline_reg_0_next.branch_mispredicted <= '1' when (eu_in_0.branch_mask /= BRANCH_MASK_ZERO and eu_in_0.branch_predicted_outcome /= branch_taken) or (eu_in_0.branch_predicted_target_pc /= branch_target_addr and uop_is_jalr = '1') else '0';
    pipeline_reg_0_next.is_jalr <= uop_is_jalr;
    pipeline_reg_0_next.valid <= '1' when valid = '1' and not ((eu_in_0.speculated_branches_mask and pipeline_reg_0.branch_mask) /= BRANCH_MASK_ZERO and pipeline_reg_0.valid = '1' and pipeline_reg_0.branch_mispredicted = '1') else '0';
    -- =====================================================
    -- =====================================================



    -- =====================================================
    --                          ALU 
    -- =====================================================
    operand_1 <= eu_in_0.operand_1 when uop_uses_pc = '0' else eu_in_0.pc;
    
    process(all)
    begin
        if (uop_is_jal_jalr = '1') then
            operand_2 <= X"0000_0004";
        elsif (uop_uses_immediate = '1') then
            operand_2 <= eu_in_0.immediate;
        else
            operand_2 <= eu_in_0.operand_2;
        end if;
    end process;

    alu : entity work.arithmetic_logic_unit(rtl)
          generic map(OPERAND_WIDTH_BITS => CPU_DATA_WIDTH_BITS)
          port map(operand_1 => operand_1,
                   operand_2 => operand_2,
                   result => alu_result,
                   alu_op_sel => uop_alu_op_sel);
    
    -- =====================================================
    -- =====================================================
    
    
    
    -- =====================================================
    --                      BRANCHING
    -- =====================================================
    uop_is_jalr <= '1' when uop_alu_op_sel(2 downto 0) = "001" and uop_is_branch = '1' else '0';
    uop_is_jal_jalr <= uop_is_jalr or (not uop_is_branch and uop_negate_branch_cond);
    
    alu_comp_result <= alu_result(0);
    alu_comp_result_n <= not alu_comp_result;
    
    branch_taken <= (alu_comp_result or uop_is_jalr) when uop_negate_branch_cond = '0' else alu_comp_result_n;
    
    process(all)
    begin
        if (uop_is_jal_jalr = '1') then
            branch_target_addr <= std_logic_vector(unsigned(eu_in_0.operand_1) + unsigned(eu_in_0.immediate));
        elsif (branch_taken = '0') then
            branch_target_addr <= std_logic_vector(unsigned(eu_in_0.pc) + 4);
        elsif (branch_taken = '1') then
            branch_target_addr <= std_logic_vector(unsigned(eu_in_0.pc) + unsigned(eu_in_0.immediate));
        else
            branch_target_addr <= (others => '0');
        end if;
    end process;

    -- =====================================================
    -- =====================================================
    i_ready <= '0' when (not pipeline_reg_0.valid or cdb_granted) = '0' else '1';
    ready <= i_ready;
                   
    cdb.pc_low_bits <= pipeline_reg_0.pc_low_bits;
    cdb.data <= pipeline_reg_0.result;
    cdb.target_addr <= pipeline_reg_0.target_addr;
    cdb.instr_tag <= pipeline_reg_0.instr_tag;
    cdb.phys_dest_reg <= pipeline_reg_0.phys_dest_reg;
    cdb.branch_mask <= pipeline_reg_0.branch_mask;
    cdb.branch_taken <= pipeline_reg_0.branch_taken;
    cdb.branch_mispredicted <= pipeline_reg_0.branch_mispredicted;
    cdb.is_jalr <= pipeline_reg_0.is_jalr;
    cdb.valid <= pipeline_reg_0.valid;
    
    cdb_request <= pipeline_reg_0.valid;

end structural;

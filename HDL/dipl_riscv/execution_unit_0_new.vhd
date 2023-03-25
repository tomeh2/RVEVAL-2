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

-- Supported Operations:
--  1) INT ALU (ADD, SUB, LOGIC OPs)
--  2) BRANCH & JUMP 

entity execution_unit_0_new is
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
end execution_unit_0_new;

architecture rtl of execution_unit_0_new is
    signal operand_1 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal operand_2 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal alu_result : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
    signal alu_comp_res : std_logic;
    signal alu_comp_res_n : std_logic;
    signal branch_taken : std_logic;
    
    signal branch_target_addr_t_base : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);    -- Branch target addr if branch is taken 
    signal branch_target_addr_t : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);    -- Branch target addr if branch is taken 
    signal branch_target_addr_nt : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);    -- Branch target addr if branch is not taken 
    signal branch_target_addr : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
    signal i_ready : std_logic;
    signal eu0_pipeline_reg_0 : cdb_type;
    signal eu0_pipeline_reg_0_next : cdb_type;
begin
    pipeline_reg_0_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                eu0_pipeline_reg_0.valid <= '0';
            elsif (i_ready = '1') then
                eu0_pipeline_reg_0 <= eu0_pipeline_reg_0_next;
            end if;
        end if;
    end process;

    operand_1 <= eu_in_0.operand_1 when eu_in_0.operation_select(5) = '0' else eu_in_0.pc;

    operand_2_mux : process(eu_in_0)
    begin
        case eu_in_0.operation_select(9 downto 7) is
            when "001" =>           -- REG-IMM ALU OPs
                operand_2 <= eu_in_0.immediate;
            when "010" | "100" =>   -- JAL & JALR
                operand_2 <= CONST_4;
            when others =>
                operand_2 <= eu_in_0.operand_2;
        end case;
    end process;

    alu : entity work.arithmetic_logic_unit(rtl)
          generic map(OPERAND_WIDTH_BITS => CPU_DATA_WIDTH_BITS)
          port map(operand_1 => operand_1,
                   operand_2 => operand_2,
                   result => alu_result,
                   alu_op_sel => eu_in_0.operation_select(3 downto 0));

    alu_comp_res <= alu_result(0);
    alu_comp_res_n <= not alu_result(0);
    branch_taken <= (alu_comp_res or eu_in_0.operation_select(9) or eu_in_0.operation_select(8)) when eu_in_0.operation_select(4) = '0' else alu_comp_res_n;

    branch_target_addr_t_base <= eu_in_0.operand_1 when eu_in_0.operation_select(8) else eu_in_0.pc;
    branch_target_addr_t <= std_logic_vector(unsigned(branch_target_addr_t_base) + unsigned(eu_in_0.immediate));
    branch_target_addr_nt <= std_logic_vector(unsigned(eu_in_0.pc) + 4);
    
    branch_target_addr <= branch_target_addr_t when branch_taken = '1' else branch_target_addr_nt;
    
    eu0_pipeline_reg_0_next.pc_low_bits <= eu_in_0.pc;
    eu0_pipeline_reg_0_next.data <= alu_result;
    eu0_pipeline_reg_0_next.target_addr <= branch_target_addr;
    eu0_pipeline_reg_0_next.instr_tag <= eu_in_0.instr_tag;
    eu0_pipeline_reg_0_next.phys_dest_reg <= eu_in_0.phys_dest_reg_addr;
    eu0_pipeline_reg_0_next.branch_mask <= eu_in_0.branch_mask;
    eu0_pipeline_reg_0_next.branch_taken <= (branch_taken and eu_in_0.operation_select(6)) or eu_in_0.operation_select(8) or eu_in_0.operation_select(9);
    eu0_pipeline_reg_0_next.branch_mispredicted <= '1' when (eu_in_0.operation_select(6) = '1' and eu_in_0.branch_predicted_outcome /= branch_taken) or (eu_in_0.branch_predicted_target_pc /= branch_target_addr and eu_in_0.operation_select(8) = '1') else '0';
    eu0_pipeline_reg_0_next.is_jalr <= eu_in_0.operation_select(8);
    eu0_pipeline_reg_0_next.is_jal <= eu_in_0.operation_select(9);
    eu0_pipeline_reg_0_next.valid <= '1' when valid = '1' and not ((eu_in_0.speculated_branches_mask and eu0_pipeline_reg_0.branch_mask) /= BRANCH_MASK_ZERO and eu0_pipeline_reg_0.valid = '1' and eu0_pipeline_reg_0.branch_mispredicted = '1') else '0';
    
    i_ready <= not (eu0_pipeline_reg_0.valid and not cdb_granted);
    ready <= i_ready;
    
    cdb_request <= eu0_pipeline_reg_0.valid;
    cdb <= eu0_pipeline_reg_0;
end rtl;
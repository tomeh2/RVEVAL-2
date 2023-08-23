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
        cdb_in : in cdb_type;
    
        eu_in_0 : in eu_input_type;
    
        valid : in std_logic;       -- Signals that the input values are valid
        ready : out std_logic;      -- Whether this EU is ready to start executing a new operation
        -- =================================================
        
        -- ==================== CDB ====================
        cdb : out cdb_single_type; 
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

    type pipeline_reg_0_type is record
        cdb : cdb_single_type;
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    end record;

    signal i_ready : std_logic;
    signal pipeline_reg_0 : pipeline_reg_0_type;
    signal pipeline_reg_0_next : pipeline_reg_0_type;
begin
    pipeline_reg_0_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_0.cdb.valid <= '0';
            else 
                if (i_ready = '1') then
                    pipeline_reg_0 <= pipeline_reg_0_next;
                else
                    if (cdb_in.cdb_branch.valid = '1' and pipeline_reg_0.cdb.valid = '1') then
                        pipeline_reg_0.speculated_branches_mask <= pipeline_reg_0.speculated_branches_mask and not cdb_in.cdb_branch.branch_mask;
                    end if;
                    
                    if (cdb_in.cdb_branch.valid = '1' and cdb_in.cdb_branch.branch_mispredicted = '1' and (pipeline_reg_0.speculated_branches_mask and cdb_in.cdb_branch.branch_mask) /= BRANCH_MASK_ZERO) then
                        pipeline_reg_0.cdb.valid <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    operand_1 <= eu_in_0.operand_1 when eu_in_0.operation_select(5) = '0' else eu_in_0.pc;

    operand_2_mux : process(eu_in_0)
    begin
        case eu_in_0.operation_select(9 downto 7) is
            when "001" =>           -- REG-IMM ALU OPs
                operand_2 <= eu_in_0.immediate;
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

    pipeline_reg_0_next.cdb.pc_low_bits <= eu_in_0.pc;
    pipeline_reg_0_next.cdb.data <= alu_result;
    pipeline_reg_0_next.cdb.instr_tag <= eu_in_0.instr_tag;
    pipeline_reg_0_next.cdb.phys_dest_reg <= eu_in_0.phys_dest_reg_addr;
    pipeline_reg_0_next.cdb.branch_mask <= (others => '0');
    pipeline_reg_0_next.cdb.valid <= '1' when valid = '1' and not ((eu_in_0.speculated_branches_mask and cdb_in.cdb_branch.branch_mask) /= BRANCH_MASK_ZERO and cdb_in.cdb_branch.valid = '1' and cdb_in.cdb_branch.branch_mispredicted = '1') else '0';
    
    i_ready <= not (pipeline_reg_0.cdb.valid and not cdb_granted);
    ready <= i_ready;
    
    cdb_request <= pipeline_reg_0.cdb.valid;
    cdb <= pipeline_reg_0.cdb;
end rtl;
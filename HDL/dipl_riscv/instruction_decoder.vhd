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

entity instruction_decoder is
    port(
        instruction : in std_logic_vector(31 downto 0);
        pc : in std_logic_vector(31 downto 0);
        
        branch_taken_pc : out std_logic_vector(31 downto 0);
        
        --is_speculative_branch : out std_logic;
        --is_uncond_branch : out std_logic;
        --is_jalr : out std_logic;

        uop : out uop_instr_dec_type
    );
end instruction_decoder;

architecture rtl of instruction_decoder is
    signal branch_op_sel : std_logic_vector(3 downto 0);
    
    -- EU 0 CONTROL SIGNALS
    alias uop_is_jal : std_logic is uop.operation_select(9);
    alias uop_is_jalr : std_logic is uop.operation_select(8);
    alias uop_uses_immediate : std_logic is uop.operation_select(7);
    alias uop_is_speculative_branch : std_logic is uop.operation_select(6);
    alias uop_uses_pc : std_logic is uop.operation_select(5);
    alias uop_negate_branch_cond : std_logic is uop.operation_select(4);
    alias uop_alu_op_sel : std_logic_vector(3 downto 0) is uop.operation_select(3 downto 0);
    
    -- EU 1 CONTROL SIGNALS
    alias uop_is_store : std_logic is uop.operation_select(7);
    
begin
    immediate_gen_proc : process(instruction)
    begin
        case (instruction(6 downto 2)) is
            when OPCODE_LUI | OPCODE_AUIPC =>           -- U-type
                uop.immediate(31 downto 12) <= instruction(31 downto 12);
                uop.immediate(11 downto 0) <= (others => '0');
            when OPCODE_JAL =>                          -- J-type
                uop.immediate(31 downto 20) <= (others => instruction(31));
                uop.immediate(19 downto 12) <= instruction(19 downto 12);
                uop.immediate(11) <= instruction(20);
                uop.immediate(10 downto 1) <= instruction(30 downto 21);
                uop.immediate(0) <= '0';
            when OPCODE_COND_BR =>                      -- B-type
                uop.immediate(31 downto 12) <= (others => instruction(31));
                uop.immediate(11) <= instruction(7);
                uop.immediate(10 downto 5) <= instruction(30 downto 25);
                uop.immediate(4 downto 1) <= instruction(11 downto 8);
                uop.immediate(0) <= '0';
            when OPCODE_STORE =>                        -- S-type
                uop.immediate(31 downto 11) <= (others => instruction(31));
                uop.immediate(10 downto 5) <= instruction(30 downto 25);
                uop.immediate(4 downto 0) <= instruction(11 downto 7);
            when others => 
                uop.immediate(31 downto 11) <= (others => instruction(31));
                uop.immediate(10 downto 0) <= instruction(30 downto 20);
        end case;
    end process;

    
    
    process(instruction, pc, branch_op_sel, uop.immediate)
    begin
        uop.arch_src_reg_1_addr <= instruction(19 downto 15);
        uop.arch_src_reg_2_addr <= instruction(24 downto 20);
        uop.arch_dest_reg_addr <= instruction(11 downto 7);
        uop.pc <= pc;
        
        if (CSR_PERF_COUNTERS_EN = true) then
            uop.csr <= instruction(31 downto 20);
        end if;
        
        uop.operation_select(OPERATION_SELECT_BITS - 1 downto 3) <= (others => '0');
        branch_op_sel <= (others => '0');
        
        branch_taken_pc <= std_logic_vector(unsigned(pc) + unsigned(uop.immediate));

        uop_alu_op_sel(2 downto 0) <= instruction(14 downto 12);
    
        case (instruction(6 downto 2)) is
            when OPCODE_ALU_REG_REG =>
                uop.operation_type <= OPTYPE_INTEGER;      
                uop_alu_op_sel <= instruction(30) & instruction(14 downto 12);
                
            when OPCODE_ALU_REG_IMM => 
                uop.operation_type <= OPTYPE_INTEGER;  
                if (instruction(14 downto 12) = "001" or instruction(14 downto 12) = "101") then
                    uop_alu_op_sel(3) <= instruction(30); 
                else
                    uop_alu_op_sel(3) <= '0';
                end if;
                uop_alu_op_sel(2 downto 0) <= instruction(14 downto 12);
                uop_uses_immediate <= '1';
                
                uop.arch_src_reg_2_addr <= (others => '0');

            when OPCODE_LOAD | OPCODE_STORE => 
                uop.operation_type <= OPTYPE_STORE when instruction(6 downto 5) = "01" else OPTYPE_LOAD;
                uop.operation_select(7) <= '1' when instruction(6 downto 5) = "01" else '0';
                uop.operation_select(2 downto 0) <= instruction(14 downto 12);
                
                uop.arch_dest_reg_addr <= "00000" when instruction(6 downto 5) = "01" else instruction(11 downto 7);

            when OPCODE_LUI => 
                uop.operation_type <= OPTYPE_INTEGER;
                uop.operation_select(7) <= '1';
                uop.operation_select(3 downto 0) <= (others => '0');
                
                uop.arch_src_reg_1_addr <= "00000";
            when OPCODE_AUIPC => 
                uop.operation_type <= OPTYPE_INTEGER;
                uop.operation_select(5) <= '1';
                uop.operation_select(7) <= '1';
                uop.operation_select(3 downto 0) <= (others => '0');
                
            when OPCODE_COND_BR => 
                case instruction(14 downto 13) is
                    when "00" => branch_op_sel <= ALU_OP_EQ;
                    when "10" => branch_op_sel <= ALU_OP_LESS;
                    when "11" => branch_op_sel <= ALU_OP_LESSU;
                    when others => branch_op_sel <= (others => '0');
                end case;
            
                uop.operation_type <= OPTYPE_BRANCH;
                uop_is_speculative_branch <= '1';
                uop_negate_branch_cond <= instruction(12);
                uop_alu_op_sel <= branch_op_sel;

                uop.arch_dest_reg_addr <= "00000";
                
            when OPCODE_JAL | OPCODE_JALR => 
                uop.operation_type <= OPTYPE_BRANCH;
                uop.operation_select(2 downto 0) <= "000";
                
                if (instruction(3) = '1') then  -- JAL
                    uop_is_jal <= '1';
                else
                    uop_is_jalr <= '1';
                end if;
                --uop_is_jal <= '1';
                uop_uses_pc <= '1';
                uop_is_speculative_branch <= '1';
                --uop_negate_branch_cond <= '1';

--            when OPCODE_JALR =>
--                uop.operation_type <= OPTYPE_BRANCH;        -- This instruction gets treated like a conditional branch by the Exec. Engine, but as a branch that is always taken
--                uop.operation_select(2 downto 0) <= "000";  -- No conditional branch has this alu op sel value so it can be used to identify this as a JALR instruction
                
--                uop_is_jalr <= '1';
--                uop_uses_pc <= '1';
--                uop_is_speculative_branch <= '1';
            
            when OPCODE_SYSTEM =>
                uop.operation_type <= (others => '0');
                uop.operation_select <= (others => '0');
            
                if (CSR_PERF_COUNTERS_EN = true) then
                    uop.operation_type <= OPTYPE_SYSTEM;
                    uop.operation_select <= "000000" & ALU_OP_ADD;
                
                    uop.arch_src_reg_1_addr <= (others => '0');
                end if;
            when OPCODE_MEM => 
                uop.operation_type <= OPTYPE_STORE;
                uop.operation_select(7) <= '1';
                uop.operation_select(6) <= '1';
                uop.operation_select(4 downto 3) <= instruction(21 downto 20);
                
                uop.arch_src_reg_2_addr <= (others => '0');
            when "XXXXX" | "UUUUU" => 
            
            when others => 
                uop.operation_type <= (others => '0');
                uop.operation_select <= (others => '0');
                
                report "Illegal instruction! PC = " & to_hstring(pc) & " | Instruction = " & to_hstring(instruction) severity failure;
        end case;   
    end process;
    
    
end rtl;

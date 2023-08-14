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

-- Holds calculated branch target addresses that the CPU will jump to in case the branch or jump is taken.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.PKG_CPU.ALL;

entity branch_controller is
    port(
        cdb : in cdb_type; 
   
        speculated_branches_mask : out std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        alloc_branch_mask : out std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        
        branch_alloc_en : in std_logic;
        
        empty : out std_logic;
        
        reset : in std_logic;
        clk : in std_logic
    );
end branch_controller;

architecture rtl of branch_controller is
    -- [BRANCH MASK | BUSY]
    type bc_masks_type is array (BRANCHING_DEPTH - 1 downto 0) of std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    type bc_dependent_masks_type is array (BRANCHING_DEPTH - 1 downto 0) of std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    type bc_alternate_pc_table_type is array (BRANCHING_DEPTH - 1 downto 0) of std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    
    signal bc_masks : bc_masks_type;
    signal bc_dependent_masks : bc_dependent_masks_type;
    
    -- Contains a 1 at every bit that has been allocated and not yet deallocated
    signal outstanding_branches_mask_i : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    
    signal allocated_mask_index : std_logic_vector(integer(ceil(log2(real(BRANCHING_DEPTH)))) - 1 downto 0);
    signal bc_empty_i : std_logic;
begin
    empty <= not bc_empty_i;

    free_mask_select_index : entity work.priority_encoder(rtl)
                         generic map(NUM_INPUTS => BRANCHING_DEPTH,
                                     HIGHER_INPUT_HIGHER_PRIO => false)
                         port map(d => not outstanding_branches_mask_i,
                                  q => allocated_mask_index,
                                  valid => bc_empty_i);

    bc_table_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to BRANCHING_DEPTH - 1 loop
                    bc_masks(i)(BRANCHING_DEPTH - 1 downto 0) <= std_logic_vector(to_unsigned(2 ** i, BRANCHING_DEPTH));
                end loop;
                outstanding_branches_mask_i <= (others => '0');
                bc_dependent_masks <= (others => (others => '0'));
            else
                if (branch_alloc_en = '1') then
                    bc_dependent_masks(to_integer(unsigned(allocated_mask_index))) <= outstanding_branches_mask_i or alloc_branch_mask;
                    outstanding_branches_mask_i(to_integer(unsigned(allocated_mask_index))) <= '1';
                end if;
                
                if (cdb.cdb_branch.branch_mask /= BRANCH_MASK_ZERO and cdb.cdb_branch.branch_mispredicted = '0' and cdb.cdb_branch.valid = '1') then        -- CORRECTLY PREDICTED
                    outstanding_branches_mask_i(branch_mask_to_int(cdb.cdb_branch.branch_mask)) <= '0';
                    
                    for i in 0 to BRANCHING_DEPTH - 1 loop
                        bc_dependent_masks(i)(branch_mask_to_int(cdb.cdb_branch.branch_mask)) <= '0';
                    end loop;
                elsif (cdb.cdb_branch.branch_mispredicted = '1' and cdb.cdb_branch.valid = '1') then                                             -- MISPREDICT! CLEAR ALL ENTRIES ALLOCATED TO BRANCHES AFTER THE MISPREDICTED ONE
                    outstanding_branches_mask_i <= bc_dependent_masks(branch_mask_to_int(cdb.cdb_branch.branch_mask));-- and not cdb.branch_mask;
                    outstanding_branches_mask_i(branch_mask_to_int(cdb.cdb_branch.branch_mask)) <= '0'; -- and not cdb.branch_mask;
                end if;
            end if;
        end if;
    end process;
    
    speculated_branches_mask <= outstanding_branches_mask_i;
    alloc_branch_mask <= bc_masks(to_integer(unsigned(allocated_mask_index))) when branch_alloc_en = '1' else (others => '0');
end rtl;

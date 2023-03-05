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
use WORK.PKG_CPU.ALL;

entity branch_prediction_table is
    port (
        branch_mask_w : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_pc_w : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_prediction_w : in std_logic;
        
        branch_mask_r : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_pc_r : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_prediction_r : out std_logic;
        rd_en : in std_logic;
        
        clk : in std_logic
    );
end branch_prediction_table;

architecture rtl of branch_prediction_table is
    constant TABLE_ENTRY_WIDTH : integer := CPU_ADDR_WIDTH_BITS + 1;

    type branch_prediction_table_type is array (BRANCHING_DEPTH - 1 downto 0) of std_logic_vector(TABLE_ENTRY_WIDTH - 1 downto 0);
    signal branch_prediction_table : branch_prediction_table_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (branch_mask_w /= BRANCH_MASK_ZERO) then
                branch_prediction_table(branch_mask_to_int(branch_mask_w)) <= branch_predicted_pc_w & branch_prediction_w;
            end if;
            
            if (rd_en = '1') then
                branch_predicted_pc_r <= branch_prediction_table(branch_mask_to_int(branch_mask_r))(TABLE_ENTRY_WIDTH - 1 downto 1);
                branch_prediction_r <= branch_prediction_table(branch_mask_to_int(branch_mask_r))(0);
            end if;
        end if;
    end process;
end rtl;












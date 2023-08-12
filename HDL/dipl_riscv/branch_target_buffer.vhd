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
use WORK.PKG_CPU.ALL;

-- Implements a direct-mapped BTB

entity branch_target_buffer is
    port(
            pc : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
            target_addr : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
            hit : out std_logic;
            stall : in std_logic;
            
            branch_write_addr : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
            branch_write_target_addr : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
            write_en : in std_logic;
            
            reset : in std_logic;
            clk : in std_logic
        );
end branch_target_buffer;

architecture rtl of branch_target_buffer is
    constant INDEX_BITS : integer := integer(ceil(log2(real(BP_ENTRIES))));
    
    constant TAG_BITS_START : integer := CPU_ADDR_WIDTH_BITS + BTB_TAG_BITS - 1;
    constant TAG_BITS_END : integer := CPU_ADDR_WIDTH_BITS;
    constant TARG_BITS_START : integer := CPU_ADDR_WIDTH_BITS - 1;
    constant TARG_BITS_END : integer := 0;

    type btb_type is array (BP_ENTRIES - 1 downto 0) of std_logic_vector(BTB_TAG_BITS + CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal btb : btb_type;
    signal btb_valid_bits : std_logic_vector(BP_ENTRIES - 1 downto 0);
    
    signal btb_read_entry : std_logic_vector(BTB_TAG_BITS + CPU_ADDR_WIDTH_BITS - 1 downto 0); 
    signal btb_read_targ_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0); 
    signal btb_read_tag : std_logic_vector(BTB_TAG_BITS - 1 downto 0); 
    signal btb_read_valid : std_logic; 
    
    signal branch_tag_pipeline_reg : std_logic_vector(BTB_TAG_BITS - 1 downto 0);
begin
    pipeline_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                branch_tag_pipeline_reg <= (others => '0');
            elsif (stall = '0') then
                branch_tag_pipeline_reg <= pc(BTB_TAG_BITS + INDEX_BITS + 1 downto INDEX_BITS + 2);
            end if;
        end if;
    end process;

    btb_proc : process(clk)
    begin 
        if (rising_edge(clk)) then
            if (reset = '1') then
                btb_valid_bits <= (others => '0');
                btb_read_valid <= '0';
                btb_read_entry <= (others => '0');
            else
                if (stall = '0') then
                    btb_read_entry <= btb(to_integer(unsigned(pc(INDEX_BITS + 1 downto 2))));
                    btb_read_valid <= btb_valid_bits(to_integer(unsigned(pc(INDEX_BITS + 1 downto 2))));
                end if;
            
                if (write_en = '1') then
                    btb(to_integer(unsigned(branch_write_addr(INDEX_BITS + 1 downto 2)))) <= 
                        branch_write_addr(BTB_TAG_BITS + INDEX_BITS + 1 downto INDEX_BITS + 2) & branch_write_target_addr;
                        btb_valid_bits(to_integer(unsigned(branch_write_addr(INDEX_BITS + 1 downto 2)))) <= '1';
                end if;
            end if;
        end if;
    end process;
    
    btb_read_targ_addr <= btb_read_entry(TARG_BITS_START downto TARG_BITS_END);
    btb_read_tag <= btb_read_entry(TAG_BITS_START downto TAG_BITS_END);
    
    hit <= '1' when btb_read_tag = branch_tag_pipeline_reg and btb_read_valid = '1' else '0';
    target_addr <= btb_read_targ_addr;
end rtl;









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

entity zicsr_registers is
    port(
        read_addr : in std_logic_vector(11 downto 0);
        read_data : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
        instr_ret : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end zicsr_registers;

architecture rtl of zicsr_registers is
    type csr_regs_type is array (1 downto 0) of std_logic_vector(63 downto 0);      -- 0: RDTIME AND RDCYCLE | 1: INSTRET
    signal csr_regs : csr_regs_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                csr_regs <= (others => (others => '0'));
            else
                csr_regs(0) <= std_logic_vector(unsigned(csr_regs(0)) + 1);
                
                if (instr_ret = '1') then
                    csr_regs(1) <= std_logic_vector(unsigned(csr_regs(1)) + 1);
                end if;
            end if;         
        end if;
    end process;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            case read_addr is 
                when X"C00" => read_data <= csr_regs(0)(31 downto 0);            -- RDCYCLE
                when X"C01" => read_data <= csr_regs(0)(31 downto 0);            -- RDTIME
                when X"C02" => read_data <= csr_regs(1)(31 downto 0);            -- INSTRET
                
                when X"C80" => read_data <= csr_regs(0)(63 downto 32);           -- RDCYCLE
                when X"C81" => read_data <= csr_regs(0)(63 downto 32);           -- RDTIME
                when X"C82" => read_data <= csr_regs(1)(63 downto 32);           -- INSTRET
                
                when others => read_data <= (others => '0');
            end case;
        end if;
    end process;

end rtl;

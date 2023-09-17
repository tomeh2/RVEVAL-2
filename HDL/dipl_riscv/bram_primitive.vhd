library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- BRAM Primitive used to instantiate BRAMs correctly in caches

entity bram_primitive is
    generic(
        DATA_WIDTH : integer;
        SIZE : integer
    );
    port(
        d : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        q1 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        q2 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        
        addr_read_1 : in std_logic_vector(integer(ceil(log2(real(SIZE)))) - 1 downto 0);
        addr_read_2 : in std_logic_vector(integer(ceil(log2(real(SIZE)))) - 1 downto 0);
        
        addr_write : in std_logic_vector(integer(ceil(log2(real(SIZE)))) - 1 downto 0);
        
        write_en : in std_logic;
        read_en : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end bram_primitive;

architecture rtl of bram_primitive is
    type bram_prim_type is array (SIZE - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal bram : bram_prim_type;

begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                q1 <= (others => '0');
                q2 <= (others => '0');
            else
                if (read_en = '1') then
                    q1 <= bram(to_integer(unsigned(addr_read_1)));
                    q2 <= bram(to_integer(unsigned(addr_read_2)));
                end if;
                
                if (write_en = '1') then
                    bram(to_integer(unsigned(addr_write))) <= d;
                end if;
            end if;
        end if;
    end process;

end rtl;

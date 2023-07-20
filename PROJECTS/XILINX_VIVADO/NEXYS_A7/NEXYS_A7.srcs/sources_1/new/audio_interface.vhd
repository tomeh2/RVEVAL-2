library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_interface is
    port(
        pdm_input : in std_logic;
    
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_stbw : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        bus_cyc : in std_logic;
        
        clk_bus : in std_logic;
        clk_pdm : in std_logic;
        reset : in std_logic
    );
end audio_interface;

architecture rtl of audio_interface is
    signal fir_filter_output : signed(15 downto 0);
    
    signal sample_rate_divider_counter_reg : unsigned(7 downto 0);
    signal sample_rate_divisor : unsigned(7 downto 0) := X"3F";
    
    signal clk_pdm_div_2 : std_logic;
    
    signal fifo_wr_en, i_bus_ready : std_logic;
    
    COMPONENT fifo_generator_0
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC 
  );
END COMPONENT;
begin
    fir_filter_instance : entity work.fir_filter
                          generic map(BITS_PER_SAMPLE => 16,
                                      ORDER => 4)
                          port map(input_signal(8) => pdm_input,
                                   input_signal(7 downto 0) => (others => '0'),
                                   input_signal(15 downto 9) => (others => '0'),
                                   output_signal => fir_filter_output,
                                   
                                   clk => clk_pdm_div_2,
                                   reset => reset);
                                   
    process(clk_pdm_div_2)
    begin
        if (rising_edge(clk_pdm_div_2)) then
            if (reset = '1') then
                sample_rate_divider_counter_reg <= (others => '0');
            else
                if (sample_rate_divider_counter_reg = sample_rate_divisor) then
                    sample_rate_divider_counter_reg <= (others => '0');
                else
                    sample_rate_divider_counter_reg <= sample_rate_divider_counter_reg + 1;
                end if;
            end if;
        end if;
    end process;
    
    process(clk_pdm)
    begin
        if (rising_edge(clk_pdm)) then
            if (reset = '1') then
                clk_pdm_div_2 <= '0';
            else
                clk_pdm_div_2 <= not clk_pdm_div_2;
            end if;
        end if;   
    end process;
    
    fifo_wr_en <= '1' when sample_rate_divider_counter_reg = sample_rate_divisor else '0';
                                   
    your_instance_name : fifo_generator_0
      PORT MAP (
        rst => reset,
        wr_clk => clk_pdm_div_2,
        rd_clk => clk_bus,
        din => std_logic_vector(fir_filter_output),
        wr_en => fifo_wr_en,
        rd_en => bus_ack,
        dout => bus_rdata(15 downto 0)
        --full => full,
        --empty => empty,
        --wr_rst_busy => wr_rst_busy,
        --rd_rst_busy => rd_rst_busy
      );
      
    bus_cntrl : process(clk_bus)
    begin
        if (rising_edge(clk_bus)) then
            if (reset = '1') then
                i_bus_ready <= '0';
            else
                i_bus_ready <= bus_cyc and not i_bus_ready;
            end if;
        end if;
    end process;
    
    bus_ack <= i_bus_ready;

end rtl;

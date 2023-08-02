library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_interface is
    port(
        pdm_input : in std_logic;
    
        bus_addr : in std_logic_vector(31 downto 0);
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
    signal pcm_sample, pcm_sample_2, pdm_sample_3 : std_logic_vector(15 downto 0);
    
    signal sample_rate_divider_counter_reg : unsigned(7 downto 0);
    signal sample_rate_divisor : unsigned(7 downto 0) := X"7F";
   
    signal cic_dec_valid, fifo_wr_en, i_bus_ready, fifo_empty : std_logic;
    
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
    empty : OUT STD_LOGIC
  );
END COMPONENT;

begin
    cic_decimator : entity work.cic_decimator
                          generic map(BITS_PER_SAMPLE => 16,
                                      DELAY => 1,
                                      ORDER => 4,
                                      DECIMATION_FACTOR => 4)
                          port map(signal_in(0) => pdm_input,
                                   signal_in(15 downto 1) => (others => '0'),
                                   --signal_in(15 downto 9) => (others => '0'),
                                   std_logic_vector(signal_out) => pcm_sample,
                                   signal_out_valid => cic_dec_valid,
                                   
                                   clk => clk_pdm,
                                   reset => reset);
                                   
    fir_filter_inst : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 8,
                                  ORDER => 61)
                      port map(signal_in(7 DOWNTO 0) => signed(pcm_sample(7 downto 0)),
                              signal_in(15 downto 8) => (others => '0'),
                               signal_in_valid => cic_dec_valid,
                               std_logic_vector(signal_out) => pcm_sample_2,
                               
                               clk => clk_pdm,
                               reset => reset);
                               
    decimator_inst : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 16)
                     port map(signal_in => pcm_sample_2,
                              signal_in_valid => cic_dec_valid,
                              signal_out => pdm_sample_3,
                              signal_out_valid => fifo_wr_en,
                              
                              clk => clk_pdm,
                              reset => reset);

    your_instance_name : fifo_generator_0
      PORT MAP (
        rst => reset,
        wr_clk => clk_pdm,
        rd_clk => clk_bus,
        din(15 downto 0) => pcm_sample_2,
        wr_en => fifo_wr_en,
        rd_en => bus_ack,
        dout => bus_rdata(15 downto 0),
        --full => full,
        empty => fifo_empty
      );
      
    bus_rdata(16) <= fifo_empty;
    bus_rdata(31 downto 17) <= (others => '0'); 
      
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

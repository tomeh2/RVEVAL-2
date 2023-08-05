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
    type pcm_sample_array_type is array (7 downto 0) of std_logic_vector(15 downto 0);
    signal pcm_samples_intermediates : pcm_sample_array_type;
   
    type pcm_sample_valids_type is array (7 downto 0) of std_logic;
    signal pcm_sample_valid_intermediates : pcm_sample_valids_type;
    
    signal fifo_empty, i_bus_ready : std_logic;
    
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
    signal clk_pdm_div_2 : std_logic;
begin
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

    cic_decimator_8 : entity work.cic_decimator
                          generic map(BITS_PER_SAMPLE => 16,
                                      DELAY => 1,
                                      ORDER => 4,
                                      DECIMATION_FACTOR => 8)
                          port map(signal_in(0) => pdm_input,
                                   signal_in(15 downto 1) => (others => '0'),
                                   --signal_in(1 downto 0) => (others => '0'),
                                   signal_in_en => clk_pdm_div_2,
                                   std_logic_vector(signal_out) => pcm_samples_intermediates(0),
                                   signal_out_valid => pcm_sample_valid_intermediates(0),
                                   
                                   clk => clk_pdm,
                                   reset => reset);
    
    fir_hb_decimation_filter_1 : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 8,
                                  ORDER => 12,
                                  COEFFS => (
                                    X"0000",
                                    X"0002",
                                    X"0000",
                                    X"FFF2",
                                    X"0000",
                                    X"004C",
                                    X"0080",
                                    X"004C",
                                    X"0000",
                                    X"FFF2",
                                    X"0000",
                                    X"0002",
                                    X"0000",
                                    others => (others => '0')))
                      port map(signal_in => signed(pcm_samples_intermediates(0)),
                               signal_in_valid => pcm_sample_valid_intermediates(0),
                               std_logic_vector(signal_out) => pcm_samples_intermediates(1),
                               
                               clk => clk_pdm,
                               reset => reset); 
                               
    decimator_1_inst : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 2)
                     port map(signal_in => pcm_samples_intermediates(1),
                              signal_in_valid => pcm_sample_valid_intermediates(0),
                              signal_out => pcm_samples_intermediates(2),
                              signal_out_valid => pcm_sample_valid_intermediates(1),
                              
                              clk => clk_pdm,
                              reset => reset);
                              
    fir_hb_decimation_filter_2 : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 8,
                                  ORDER => 14,
                                  COEFFS => (
                                    X"0000",
                                    X"0000",
                                    X"0004",
                                    X"0000",
                                    X"FFEF",
                                    X"0000",
                                    X"004D",
                                    X"0080",
                                    X"004D",
                                    X"0000",
                                    X"FFEF",
                                    X"0000",
                                    X"0004",
                                    X"0000",
                                    X"0000",
                                    others => (others => '0')))
                      port map(signal_in => signed(pcm_samples_intermediates(2)),
                               signal_in_valid => pcm_sample_valid_intermediates(1),
                               std_logic_vector(signal_out) => pcm_samples_intermediates(3),
                               
                               clk => clk_pdm,
                               reset => reset); 
                               
    decimator_2_inst : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 2)
                     port map(signal_in => pcm_samples_intermediates(3),
                              signal_in_valid => pcm_sample_valid_intermediates(1),
                              signal_out => pcm_samples_intermediates(4),
                              signal_out_valid => pcm_sample_valid_intermediates(2),
                              
                              clk => clk_pdm,
                              reset => reset);
                              
    fir_hb_decimation_filter_3 : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 8,
                                  ORDER => 59,
                                  COEFFS => (
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0001",
                                    X"0000",
                                    X"FFFE",
                                    X"0000",
                                    X"0003",
                                    X"0000",
                                    X"FFFC",
                                    X"0000",
                                    X"0006",
                                    X"0000",
                                    X"FFF7",
                                    X"0000",
                                    X"000E",
                                    X"0000",
                                    X"FFE6",
                                    X"0000",
                                    X"0051",
                                    X"0080",
                                    X"0051",
                                    X"0000",
                                    X"FFE6",
                                    X"0000",
                                    X"000E",
                                    X"0000",
                                    X"FFF7",
                                    X"0000",
                                    X"0006",
                                    X"0000",
                                    X"FFFC",
                                    X"0000",
                                    X"0003",
                                    X"0000",
                                    X"FFFE",
                                    X"0000",
                                    X"0001",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    X"0000",
                                    others => (others => '0')))
                      port map(signal_in => signed(pcm_samples_intermediates(4)),
                               signal_in_valid => pcm_sample_valid_intermediates(2),
                               std_logic_vector(signal_out) => pcm_samples_intermediates(5),
                               
                               clk => clk_pdm,
                               reset => reset); 
                               
    decimator_3_inst : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 2)
                     port map(signal_in => pcm_samples_intermediates(5),
                              signal_in_valid => pcm_sample_valid_intermediates(2),
                              signal_out => pcm_samples_intermediates(6),
                              signal_out_valid => pcm_sample_valid_intermediates(3),
                              
                              clk => clk_pdm,
                              reset => reset);
    
    your_instance_name : fifo_generator_0
      PORT MAP (
        rst => reset,
        wr_clk => clk_pdm,
        rd_clk => clk_bus,
        din(15 downto 0) => pcm_samples_intermediates(6),
        wr_en => pcm_sample_valid_intermediates(3),
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

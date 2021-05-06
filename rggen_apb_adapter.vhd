library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_apb_adaper is
  generic (
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    ERROR_STATUS:         boolean   := false
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_psel:                 in  std_logic;
    i_penable:              in  std_logic;
    i_paddr:                in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_pprot:                in  std_logic_vector(2 downto 0);
    i_pwrite:               in  std_logic;
    i_pstrb:                in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_pwdata:               in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_pready:               out std_logic;
    o_prdata:               out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_pslverr:              out std_logic;
    o_register_valid:       out std_logic;
    o_register_access:      out std_logic_vector(1 downto 0);
    o_register_address:     out std_logic_vector(LOCAL_ADDRESS_WIDTH - 1 downto 0);
    o_register_write_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_strobe:      out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_register_active:      in  std_logic_vector(1 * REGISTERS - 1 downto 0);
    i_register_ready:       in  std_logic_vector(1 * REGISTERS - 1 downto 0);
    i_register_status:      in  std_logic_vector(2 * REGISTERS - 1 downto 0);
    i_register_read_data:   in  std_logic_vector(BUS_WIDTH * REGISTERS - 1 downto 0)
  );
end rggen_apb_adaper;

architecture rtl of rggen_apb_adaper is
  signal  bus_valid:      std_logic;
  signal  bus_access:     std_logic_vector(1 downto 0);
  signal  bus_address:    std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_write_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_strobe:     std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_ready:      std_logic;
  signal  bus_status:     std_logic_vector(1 downto 0);
  signal  bus_read_data:  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_ack:        std_logic;
  signal  pready:         std_logic;
  signal  prdata:         std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  pslverr:        std_logic;
begin
  bus_valid       <= i_psel and (not pready);
  bus_access      <= "11" when i_pwrite = '1' else "10";
  bus_address     <= i_paddr;
  bus_write_data  <= i_pwdata;
  bus_strobe      <= i_pstrb;
  bus_ack         <= bus_valid and bus_ready;

  o_pready  <= pready;
  o_prdata  <= prdata;
  o_pslverr <= pslverr;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      pready  <= '0';
    elsif (rising_edge(i_clk)) then
      pready  <= bus_ack;
    end if;
  end process;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if (bus_ack = '1') then
        prdata  <= bus_read_data;
        pslverr <= bus_status(1);
      end if;
    end if;
  end process;

  u_adapter_common: entity work.rggen_adapter_common
    generic map (
      ADDRESS_WIDTH       => ADDRESS_WIDTH,
      LOCAL_ADDRESS_WIDTH => LOCAL_ADDRESS_WIDTH,
      BUS_WIDTH           => BUS_WIDTH,
      REGISTERS           => REGISTERS,
      PRE_DECODE          => PRE_DECODE,
      BASE_ADDRESS        => BASE_ADDRESS,
      BYTE_SIZE           => BYTE_SIZE,
      ERROR_STATUS        => ERROR_STATUS
    )
    port map (
      i_clk                 => i_clk,
      i_rst_n               => i_rst_n,
      i_bus_valid           => bus_valid,
      i_bus_access          => bus_access,
      i_bus_address         => bus_address,
      i_bus_write_data      => bus_write_data,
      i_bus_strobe          => bus_strobe,
      o_bus_ready           => bus_ready,
      o_bus_status          => bus_status,
      o_bus_read_data       => bus_read_data,
      o_register_valid      => o_register_valid,
      o_register_access     => o_register_access,
      o_register_address    => o_register_address,
      o_register_write_data => o_register_write_data,
      o_register_strobe     => o_register_strobe,
      i_register_active     => i_register_active,
      i_register_ready      => i_register_ready,
      i_register_status     => i_register_status,
      i_register_read_data  => i_register_read_data
    );
end rtl;

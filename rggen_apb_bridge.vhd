library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_apb_bridge is
    generic (
      ADDRESS_WIDTH:  positive  := 8;
      BUS_WIDTH:      positive  := 32
    );
    port (
      i_clk:            in  std_logic;
      i_rst_n:          in  std_logic;
      i_bus_valid:      in  std_logic;
      i_bus_access:     in  std_logic_vector(1 downto 0);
      i_bus_address:    in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      i_bus_write_data: in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_bus_strobe:     in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_bus_ready:      out std_logic;
      o_bus_status:     out std_logic_vector(1 downto 0);
      o_bus_read_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
      o_psel:           out std_logic;
      o_penable:        out std_logic;
      o_paddr:          out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      o_pprot:          out std_logic_vector(2 downto 0);
      o_pwrite:         out std_logic;
      o_pstrb:          out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_pwdata:         out std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_pready:         in  std_logic;
      i_prdata:         in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_pslverr:        in  std_logic
    );
end rggen_apb_bridge;

architecture rtl of rggen_apb_bridge is
  signal  busy: std_logic;
begin
  o_psel    <= i_bus_valid;
  o_penable <= i_bus_valid and busy;
  o_paddr   <= i_bus_address;
  o_pprot   <= (others => '0');
  o_pwrite  <= i_bus_access(0);
  o_pstrb   <= i_bus_strobe;
  o_pwdata  <= i_bus_write_data;

  o_bus_ready     <= i_pready and busy;
  o_bus_status    <= "10" when i_pslverr = '1' else "00";
  o_bus_read_data <= i_prdata;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      busy  <= '0';
    elsif (rising_edge(i_clk)) then
      if (busy = '1' and i_pready = '1') then
        busy  <= '0';
      elsif (i_bus_valid = '1') then
        busy  <= '1';
      end if;
    end if;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_wishbone_bridge is
  generic (
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32;
    USE_STALL:      boolean   := true
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
    o_wb_cyc:         out std_logic;
    o_wb_stb:         out std_logic;
    i_wb_stall:       in  std_logic;
    o_wb_adr:         out std_logic_vector(ADDRESS_WIDTH -1 downto 0);
    o_wb_we:          out std_logic;
    o_wb_dat:         out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_wb_sel:         out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_wb_ack:         in  std_logic;
    i_wb_err:         in  std_logic;
    i_wb_rty:         in  std_logic;
    i_wb_dat:         in  std_logic_vector(BUS_WIDTH - 1 downto 0)
  );
end rggen_wishbone_bridge;

architecture rtl of rggen_wishbone_bridge is
  signal  request_done:   std_logic;
  signal  response_valid: std_logic;
begin
  o_wb_cyc  <= i_bus_valid;
  o_wb_stb  <= i_bus_valid and (not request_done);
  o_wb_adr  <= i_bus_address;
  o_wb_we   <= '1' when i_bus_access /= RGGEN_READ else '0';
  o_wb_dat  <= i_bus_write_data;
  o_wb_sel  <= i_bus_strobe;

  o_bus_ready     <= response_valid;
  o_bus_status    <= RGGEN_OKAY when i_wb_ack = '1' else RGGEN_SLAVE_ERROR;
  o_bus_read_data <= i_wb_dat;

  g_stall: if (USE_STALL) generate
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        request_done  <= '0';
      elsif (rising_edge(i_clk)) then
        if ((i_bus_valid and response_valid) = '1') then
          request_done  <= '0';
        elsif ((i_bus_valid and (not i_wb_stall)) = '1') then
          request_done  <= '1';
        end if;
      end if;
    end process;
  end generate;

  g_no_stall: if (not USE_STALL) generate
    request_done  <= '0';
  end generate;

  response_valid  <= i_wb_ack or i_wb_err or i_wb_rty;
end rtl;

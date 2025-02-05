library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_avalon_bridge is
    generic (
      ADDRESS_WIDTH:  positive  := 8;
      BUS_WIDTH:      positive  := 32;
      READ_STROBE:    boolean   := true
    );
    port (
      i_clk:                in  std_logic;
      i_rst_n:              in  std_logic;
      i_bus_valid:          in  std_logic;
      i_bus_access:         in  std_logic_vector(1 downto 0);
      i_bus_address:        in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      i_bus_write_data:     in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_bus_strobe:         in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_bus_ready:          out std_logic;
      o_bus_status:         out std_logic_vector(1 downto 0);
      o_bus_read_data:      out std_logic_vector(BUS_WIDTH - 1 downto 0);
      o_read:               out std_logic;
      o_write:              out std_logic;
      o_address:            out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      o_byteenable:         out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_writedata:          out std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_waitrequest:        in  std_logic;
      i_readdatavalid:      in  std_logic;
      i_writeresponsevalid: in  std_logic;
      i_response:           in  std_logic_vector(1 downto 0);
      i_readdata:           in  std_logic_vector(BUS_WIDTH - 1 downto 0)
    );
end rggen_avalon_bridge;

architecture rtl of rggen_avalon_bridge is
  signal  read_access:  std_logic;
  signal  write_access: std_logic;
  signal  request_done: std_logic;
begin
  o_read          <= i_bus_valid and read_access  and (not request_done);
  o_write         <= i_bus_valid and write_access and (not request_done);
  o_address       <= i_bus_address;
  o_byteenable    <= i_bus_strobe when (i_bus_access /= RGGEN_READ) or READ_STROBE else (others => '1');
  o_writedata     <= i_bus_write_data;
  o_bus_ready     <= i_readdatavalid or i_writeresponsevalid;
  o_bus_status    <= i_response;
  o_bus_read_data <= i_readdata;

  read_access   <= '1' when i_bus_access = RGGEN_READ else '0';
  write_access  <= not read_access;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      request_done  <= '0';
    elsif (rising_edge(i_clk)) then
      if (i_bus_valid = '1') then
        if ((i_readdatavalid or i_writeresponsevalid) = '1') then
          request_done  <= '0';
        elsif (request_done = '0') then
          request_done  <= i_waitrequest;
        end if;
      end if;
    end if;
  end process;
end rtl;

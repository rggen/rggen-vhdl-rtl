library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_backdoor is
  generic (
    DATA_WIDTH: positive        := 32;
    INSIDE_VHDL_DESIGN: boolean := false
  );
  port (
    i_clk:              in  std_logic;
    i_rst_n:            in  std_logic;
    i_frontdoor_valid:  in  std_logic;
    i_frontdoor_ready:  in  std_logic;
    o_backdoor_valid:   out std_logic;
    o_pending_valid:    out std_logic;
    o_read_mask:        out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_write_mask:       out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_write_data:       out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_read_data:        in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_value:            in  std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end rggen_backdoor;

architecture rtl of rggen_backdoor is
begin
  o_backdoor_valid  <= '0';
  o_pending_valid   <= '0';
  o_read_mask       <= (others => '0');
  o_write_mask      <= (others => '0');
  o_write_data      <= (others => '0');
end rtl;

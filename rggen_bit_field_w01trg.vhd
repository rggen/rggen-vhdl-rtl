library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_bit_field_w01trg is
  generic (
    WRITE_ONE_TRIGGER:  boolean   := true;
    WIDTH:              positive  := 1
  );
  port (
    i_clk:              in  std_logic;
    i_rst_n:            in  std_logic;
    i_sw_valid:         in  std_logic;
    i_sw_read_mask:     in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_enable:  in  std_logic_vector(0 downto 0);
    i_sw_write_mask:    in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    o_sw_read_data:     out std_logic_vector(WIDTH - 1 downto 0);
    o_sw_value:         out std_logic_vector(WIDTH - 1 downto 0);
    o_trigger:          out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_bit_field_w01trg;

architecture rtl of rggen_bit_field_w01trg is
  signal  trigger:  std_logic_vector(WIDTH - 1 downto 0);
begin
  o_sw_read_data  <= (others => '0');
  o_sw_value      <= trigger;
  o_trigger       <= trigger;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      trigger <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if (i_sw_valid = '1') then
        if (WRITE_ONE_TRIGGER) then
          trigger <= i_sw_write_mask and i_sw_write_data;
        else
          trigger <= i_sw_write_mask and (not i_sw_write_data);
        end if;
      elsif (unsigned(trigger) /= 0) then
        trigger <= (others => '0');
      end if;
    end if;
  end process;
end rtl;

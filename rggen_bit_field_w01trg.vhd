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
    i_sw_read_valid:    in  std_logic;
    i_sw_write_valid:   in  std_logic;
    i_sw_write_enable:  in  std_logic_vector(0 downto 0);
    i_sw_mask:          in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    o_sw_read_data:     out std_logic_vector(WIDTH - 1 downto 0);
    o_sw_value:         out std_logic_vector(WIDTH - 1 downto 0);
    i_value:            in  std_logic_vector(WIDTH - 1 downto 0);
    o_trigger:          out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_bit_field_w01trg;

architecture rtl of rggen_bit_field_w01trg is
  function get_assert_trigger(
    valid:      std_logic;
    mask:       std_logic_vector;
    write_data: std_logic_vector
  ) return std_logic_vector is
    variable  trigger:        std_logic_vector(mask'range);
    variable  trigger_value:  std_logic;
  begin
    if (WRITE_ONE_TRIGGER) then
      trigger_value := '1';
    else
      trigger_value := '0';
    end if;

    for i in 0 to WIDTH - 1 loop
      if ((valid = '1') and (mask(0) = '1') and (write_data(i) = trigger_value)) then
        trigger(i)  := '1';
      else
        trigger(i)  := '0';
      end if;
    end loop;

    return trigger;
  end get_assert_trigger;

  signal  trigger:        std_logic_vector(WIDTH - 1 downto 0);
  signal  assert_trigger: std_logic_vector(WIDTH - 1 downto 0);
begin
  o_sw_read_data  <= i_value;
  o_sw_value      <= trigger;
  o_trigger       <= trigger;

  assert_trigger  <= get_assert_trigger(i_sw_write_valid, i_sw_mask, i_sw_write_data);
  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      trigger <= (others => '0');
    elsif (rising_edge(i_clk)) then
      for i in 0 to WIDTH - 1 loop
        if (assert_trigger(i) = '1') then
          trigger(i)  <= '1';
        elsif (trigger(i) = '1') then
          trigger(i)  <= '0';
        end if;
      end loop;
    end if;
  end process;
end rtl;

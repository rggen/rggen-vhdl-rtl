library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_bit_field_counter is
  generic (
    WIDTH:          positive  := 8;
    INITIAL_VALUE:  unsigned  := x"0";
    UP_WIDTH:       natural   := 1;
    DOWN_WIDTH:     natural   := 1;
    WRAP_AROUND:    boolean   := false;
    USE_CLEAR:      boolean   := true
  );
  port (
    i_clk:            in  std_logic;
    i_rst_n:          in  std_logic;
    i_sw_read_valid:  in  std_logic;
    i_sw_write_valid: in  std_logic;
    i_sw_mask:        in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_data:  in  std_logic_vector(WIDTH - 1 downto 0);
    o_sw_read_data:   out std_logic_vector(WIDTH - 1 downto 0);
    o_sw_value:       out std_logic_vector(WIDTH - 1 downto 0);
    i_clear:          in  std_logic_vector(0 downto 0);
    i_up:             in  std_logic_vector(clip_width(UP_WIDTH) - 1 downto 0);
    i_down:           in  std_logic_vector(clip_width(DOWN_WIDTH) - 1 downto 0);
    o_count:          out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_bit_field_counter;

architecture rtl of rggen_bit_field_counter is
  function calc_count_next_simple(
    count:  std_logic_vector;
    up:     std_logic_vector;
    down:   std_logic_vector
  ) return std_logic_vector is
    variable  count_next: unsigned(WIDTH - 1 downto 0);
  begin
    count_next  := unsigned(count);

    for i in 0 to UP_WIDTH - 1 loop
      if (up(i) = '1') then
        count_next  := count_next + 1;
      end if;
    end loop;

    for i in 0 to DOWN_WIDTH - 1 loop
      if (down(i) = '1') then
        count_next  := count_next - 1;
      end if;
    end loop;

    return std_logic_vector(count_next);
  end calc_count_next_simple;

  constant  COUNT_NEXT_WIDTH: positive  := WIDTH + 1;

  function calc_count_next(
    count:  std_logic_vector;
    up:     std_logic_vector;
    down:   std_logic_vector
  ) return std_logic_vector is
    variable  up_down:        std_logic_vector(1 downto 0);
    variable  up_down_value:  unsigned(COUNT_NEXT_WIDTH - 1 downto 0);
    variable  count_next:     unsigned(COUNT_NEXT_WIDTH - 1 downto 0);
  begin
    up_down_value := (others => '0');
    for i in 0 to UP_WIDTH - 1 loop
      if (up(i) = '1') then
        up_down_value := up_down_value + 1;
      end if;
    end loop;

    for i in 0 to DOWN_WIDTH - 1 loop
      if (down(i) = '1') then
        up_down_value := up_down_value - 1;
      end if;
    end loop;

    count_next  := resize(unsigned(count), COUNT_NEXT_WIDTH) + up_down_value;
    if (count_next(COUNT_NEXT_WIDTH - 1) = '1') then
      if (up_down_value(COUNT_NEXT_WIDTH - 1) = '1') then
        --  underflow
        count_next  := (others => '0');
      else
        --  overflow
        count_next  := (others => '1');
      end if;
    end if;

    return std_logic_vector(count_next(WIDTH - 1 downto 0));
  end calc_count_next;

  signal  count:  std_logic_vector(WIDTH - 1 downto 0);
  signal  up:     std_logic_vector(clip_width(UP_WIDTH) - 1 downto 0);
  signal  down:   std_logic_vector(clip_width(DOWN_WIDTH) - 1 downto 0);
begin
  o_sw_read_data  <= count;
  o_sw_value      <= count;
  o_count         <= count;

  process (i_up, i_down) begin
    if (UP_WIDTH > 0) then
      up  <= i_up;
    else
      up  <= (others => '0');
    end if;

    if (DOWN_WIDTH > 0) then
      down  <= i_down;
    else
      down  <= (others => '0');
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      count <= std_logic_vector(INITIAL_VALUE);
    elsif (rising_edge(i_clk)) then
      if (i_clear(0) = '1') then
        count <= std_logic_vector(INITIAL_VALUE);
      elsif (i_sw_write_valid = '1') then
        for i in 0 to WIDTH - 1 loop
          if (i_sw_mask(i) = '1') then
            count(i)  <= i_sw_write_data(i);
          end if;
        end loop;
      elsif ((unsigned(up) /= 0) or (unsigned(down) /= 0)) then
        if (WRAP_AROUND) then
          count <= calc_count_next_simple(count, up, down);
        else
          count <= calc_count_next(count, up, down);
        end if;
      end if;
    end if;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package rggen_rtl is
  constant  RGGEN_ACCESS_DATA_BIT:        integer := 0;
  constant  RGGEN_ACCESS_NON_POSTED_BIT:  integer := 1;

  type rggen_sw_hw_access is (
    RGGEN_SW_ACCESS,
    RGGEN_HW_ACCESS
  );

  type rggen_polarity is (
    RGGEN_ACTIVE_LOW,
    RGGEN_ACTIVE_HIGH
  );

  type rggen_sw_action is (
    RGGEN_READ_NONE,
    RGGEN_READ_DEFAULT,
    RGGEN_READ_CLEAR,
    RGGEN_READ_SET,
    RGGEN_WRITE_NONE,
    RGGEN_WRITE_DEFAULT,
    RGGEN_WRITE_0_CLEAR,
    RGGEN_WRITE_1_CLEAR,
    RGGEN_WRITE_CLEAR,
    RGGEN_WRITE_0_SET,
    RGGEN_WRITE_1_SET,
    RGGEN_WRITE_SET,
    RGGEN_WRITE_0_TOGGLE,
    RGGEN_WRITE_1_TOGGLE
  );

  function clog2 (n: positive) return natural;

  function mux (
    word_select:  std_logic_vector;
    words:        std_logic_vector
  ) return std_logic_vector;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return unsigned;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return std_logic_vector;
end rggen_rtl;

package body rggen_rtl is
  function clog2 (n: positive) return natural is
  begin
    return natural(ceil(log(real(n), 2.0)));
  end clog2;

  function mux (
    word_select:  std_logic_vector;
    words:        std_logic_vector
  ) return std_logic_vector is
    constant  entries:    positive  := word_select'length;
    constant  word_width: positive  := words'length / entries;

    variable  word:     std_logic_vector(word_width -1 downto 0);
    variable  mask:     std_logic_vector(word_width -1 downto 0);
    variable  out_data: std_logic_vector(word_width -1 downto 0);
  begin
    for i in 0 to entries - 1 loop
      word  := words(word_width*(i+1)-1 downto word_width*i);
      mask  := (others => word_select(i));
      if i = 0 then
        out_data  := (word and mask);
      else
        out_data  := (word and mask) or out_data;
      end if;
    end loop;
    return out_data;
  end mux;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return unsigned is
  begin
    return packed_values(width*(index+1)-1 downto width*index);
  end slice;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return std_logic_vector is
  begin
    return std_logic_vector(packed_values(width*(index+1)-1 downto width*index));
  end slice;
end rggen_rtl;

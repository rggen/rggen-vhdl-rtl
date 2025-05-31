library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package rggen_rtl is
  constant  RGGEN_ACCESS_DATA_BIT:        integer := 0;
  constant  RGGEN_ACCESS_NON_POSTED_BIT:  integer := 1;

  constant  RGGEN_READ:         std_logic_vector  := "10";
  constant  RGGEN_POSTED_WRITE: std_logic_vector  := "01";
  constant  RGGEN_WRITE:        std_logic_vector  := "11";

  constant  RGGEN_OKAY:         std_logic_vector  := "00";
  constant  RGGEN_EXOKAY:       std_logic_vector  := "01";
  constant  RGGEN_SLAVE_ERROR:  std_logic_vector  := "10";
  constant  RGGEN_DECODE_ERROR: std_logic_vector  := "11";

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

  function bit_slice (
    value:  std_logic_vector;
    index:  natural
  ) return std_logic;

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

  function repeat (
    replication_value:  unsigned;
    width:              positive;
    multiplier:         positive
  ) return unsigned;

  function clip_id_width(
    id_width: natural
  ) return natural;
end rggen_rtl;

package body rggen_rtl is
  function clog2 (n: positive) return natural is
  begin
    return natural(ceil(log(real(n), 2.0)));
  end clog2;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return unsigned is
    alias values: unsigned(packed_values'length - 1 downto 0) is packed_values;
  begin
    return values(width*(index+1)-1 downto width*index);
  end slice;

  function slice (
    packed_values:  unsigned;
    width:          positive;
    index:          natural
  ) return std_logic_vector is
    alias values: unsigned(packed_values'length - 1 downto 0) is packed_values;
  begin
    return std_logic_vector(values(width*(index+1)-1 downto width*index));
  end slice;

  function bit_slice (
    value:  std_logic_vector;
    index:  natural
  ) return std_logic is
    alias v:  std_logic_vector(value'length - 1 downto 0) is value;
  begin
    return v(index);
  end bit_slice;

  function repeat (
    replication_value:  unsigned;
    width:              positive;
    multiplier:         positive
  ) return unsigned is
    alias     value:  unsigned(replication_value'length - 1 downto 0) is replication_value;
    variable  result: unsigned(width * multiplier - 1 downto 0);
  begin
    for i in 0 to multiplier - 1 loop
      result(width * (i + 1) - 1 downto width * i)  := value(width - 1 downto 0);
    end loop;
    return result;
  end repeat;

  function clip_id_width(
    id_width: natural
  ) return natural is
  begin
    if (id_width = 0) then
      return 1;
    else
      return id_width;
    end if;
  end clip_id_width;
end rggen_rtl;

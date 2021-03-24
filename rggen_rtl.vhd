library ieee;
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
end rggen_rtl;

package body rggen_rtl is
  function clog2(n: positive) return natural is
  begin
    return natural(ceil(log(real(n), 2.0)));
  end clog2;
end rggen_rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_address_decoder is
  generic (
    READABLE:       boolean   := true;
    WRITABLE:       boolean   := true;
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32;
    START_ADDRESS:  unsigned  := x"0";
    END_ADDRESS:    unsigned  := x"0"
  );
  port (
    i_address:          in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_access:           in  std_logic_vector(1 downto 0);
    i_additional_match: in  std_logic;
    o_match:            out std_logic
  );
end rggen_address_decoder;

architecture rtl of rggen_address_decoder is
  constant  ADDRESS_LSB:        natural   := clog2(BUS_WIDTH) - 3;
  constant  WIDTH:              natural   := ADDRESS_WIDTH - ADDRESS_LSB;
  constant  DIRECTION_BIT:      natural   := 0;
  constant  COMPARE_ADDRESS_0:  unsigned  := START_ADDRESS(ADDRESS_WIDTH - 1 downto ADDRESS_LSB);
  constant  COMPARE_ADDRESS_1:  unsigned  := END_ADDRESS(ADDRESS_WIDTH - 1 downto ADDRESS_LSB);

  function match_address (
    address:  std_logic_vector
  ) return std_logic is
    variable  result_0: boolean;
    variable  result_1: boolean;
  begin
    if (COMPARE_ADDRESS_0 = COMPARE_ADDRESS_1) then
      result_0  := unsigned(address) = COMPARE_ADDRESS_0;
      result_1  := true;
    else
      result_0  := unsigned(address) >= COMPARE_ADDRESS_0;
      result_1  := unsigned(address) <= COMPARE_ADDRESS_1;
    end if;

    if (result_0 and result_1) then
      return '1';
    else
      return '0';
    end if;
  end match_address;

  function match_access (
    write_access: std_logic
  ) return std_logic is
  begin
    if (READABLE and WRITABLE) then
      return '1';
    elsif (READABLE) then
      return not write_access;
    else
      return write_access;
    end if;
  end match_access;

  signal  address_matched:  std_logic;
  signal  access_matched:   std_logic;
begin
  o_match <= address_matched and access_matched and i_additional_match;

  address_matched <= match_address(i_address(ADDRESS_WIDTH -1 downto ADDRESS_LSB));
  access_matched  <= match_access(i_access(DIRECTION_BIT));
end rtl;

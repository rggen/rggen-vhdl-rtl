library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rggen_or_reducer is
  generic (
    WIDTH:  positive  := 2;
    N:      positive  := 2
  );
  port (
    i_data:   in  std_logic_vector(WIDTH * N - 1 downto 0);
    o_result: out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_or_reducer;

architecture rtl of rggen_or_reducer is
  constant  NEXT_N: positive  := N / 2 + N rem 2;

  signal  next_data:  std_logic_vector(WIDTH * NEXT_N - 1 downto 0);
begin
  process (i_data) begin
    for i in 0 to NEXT_N - 1 loop
      if ((i = (NEXT_N - 1)) and ((N rem 2) = 1)) then
        next_data(WIDTH * (i + 1) - 1 downto WIDTH * i) <=
          i_data(WIDTH * ((2 * i) + 1) - 1 downto WIDTH * ((2 * i) + 0));
      else
        next_data(WIDTH * (i + 1) - 1 downto WIDTH * i) <=
          i_data(WIDTH * ((2 * i) + 2) - 1 downto WIDTH * ((2 * i) + 1)) or
          i_data(WIDTH * ((2 * i) + 1) - 1 downto WIDTH * ((2 * i) + 0));
      end if;
    end loop;
  end process;

  g_reducer: if (NEXT_N > 1) generate
  begin
    u_reducer: entity work.rggen_or_reducer
      generic map (
        WIDTH => WIDTH,
        N     => NEXT_N
      )
      port map (
        i_data    => next_data,
        o_result  => o_result
      );
  end generate;

  g_last: if (NEXT_N = 1) generate
  begin
    o_result  <= next_data;
  end generate;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rggen_mux is
  generic (
    WIDTH:    positive  := 2;
    ENTRIES:  positive  := 2
  );
  port (
    i_select: in  std_logic_vector(ENTRIES - 1 downto 0);
    i_data:   in  std_logic_vector(ENTRIES * WIDTH - 1 downto 0);
    o_data:   out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_mux;

architecture rtl of rggen_mux is
begin
  g_mux: if (ENTRIES > 1) generate
    signal  data: std_logic_vector(i_data'range);
  begin
    process (i_select, i_data) begin
      for i in 0 to ENTRIES - 1 loop
        if (i_select(i) = '1') then
          data(WIDTH * (i + 1) - 1 downto WIDTH * i) <=
            i_data(WIDTH * (i + 1) - 1 downto WIDTH * i);
        else
          data(WIDTH * (i + 1) - 1 downto WIDTH * i) <=
            (others => '0');
        end if;
      end loop;
    end process;

    u_reducer: entity work.rggen_or_reducer
      generic map (
        WIDTH => WIDTH,
        N     => ENTRIES
      )
      port map (
        i_data    => data,
        o_result  => o_data
      );
  end generate;

  g_bypass: if (ENTRIES = 1) generate
  begin
    o_data  <= i_data;
  end generate;
end rtl;

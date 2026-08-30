library ieee;
use ieee.std_logic_1164.all;

entity edge_detect is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        level : in  std_logic;  -- señal de entrada
        tick  : out std_logic   -- pulso de 1 ciclo en flanco de subida
    );
end edge_detect;

architecture gate_level_arch of edge_detect is
    signal delay_reg : std_logic;
begin

    -- registro de retardo (guarda el valor anterior)
    process(clk, reset)
    begin
        if reset = '1' then
            delay_reg <= '0';
        elsif rising_edge(clk) then
            delay_reg <= level;
        end if;
    end process;

    -- lógica de detección de flanco de subida
    tick <= (not delay_reg) and level and (not reset);

end gate_level_arch;
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Emilio Elias Sujar Overbury
-- Este template implementa una FSM que lee un frame proveniente del sensor CMOS cuando EN se habilita, con interfaz de salida pensada para conectarse a la FIFO.
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
-- cam_read_inst: entity cam_read
-- port map (
--     clk     => CLK, -- i
--     reset   => RST, -- i
--     pclk_tick   => PCLK_tick, -- i
--     enable   => EN, -- i
    
    -- Camera IO ---------------------------
--     DIN     => CAM_DATA,     -- i[7:0]
--     VSYNC   => CAM_VSYNC,     -- i
--     HSYNC   => CAM_HSYNC,     -- i
    
    -- FIFO interface --------------
--     DOUT    => FIFO_DIN,     -- o[7:0]
--     PUSH     => FIFO_PUSH,      -- o
-- );


entity cam_read is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           pclk_tick : in STD_LOGIC;
           enable : in STD_LOGIC;
           DIN : in STD_LOGIC_VECTOR (7 downto 0);
           VSYNC : in STD_LOGIC;
           HSYNC : in STD_LOGIC;
           DOUT : out STD_LOGIC_VECTOR (7 downto 0);
           PUSH : out STD_LOGIC);
end cam_read;

--TFM. Modelaremos la FSM para enviar bytes utiles a la FIFO.
architecture Behavioral of cam_read is
    type state_type is (idle, wait_frame_end, wait_frame_start, wait_line_start, push_byte);
    signal state_reg, state_next: state_type;
    signal salida_next, salida_reg: STD_LOGIC_VECTOR (7 downto 0); -- para cada salida, crearemos dos senales internas.
    signal push_next, push_reg: STD_LOGIC;

begin
--EC34. Utilizaremos dos segmentos de codigo:
--  un proceso para modelar el registro de estado. Unico bloque sincrono.
    REG: process (clk, reset) -- el reset de la FSM debe ser AS NCRONO.
    begin
        if reset='1' then
            state_reg <= idle;
            salida_reg <= (others => '0');
            push_reg <= '0';   -- idle
        elsif rising_edge(clk) then-- Las salidas deben ser registradas: olvida si son tipo Moore o Mealy.
            push_reg <= '0';   -- solo deben producirse cambios cuando PCLK sube.
            if (pclk_tick = '1') then
                state_reg <= state_next;
                salida_reg <= salida_next;
                push_reg <= push_next;
            end if;
        end if; -- proceso sincrono, no necesita sentencia else.
    end process REG;
        
    
--  otro proceso para modelar la logica de estado siguiente. 
    COMB: process (state_reg, enable, VSYNC, HSYNC, DIN, salida_reg)    
    begin
    --EC34. Asignacion por defecto: simplifica el codigo y evita LATCHES no deseados.
    state_next <= state_reg;
    salida_next <= salida_reg;
    push_next <= '0'; -- solo se activa para bytes validos.
    case state_reg is
        when idle =>
            if (enable = '1') then 
                state_next <= wait_frame_end;
            end if;
            
        when wait_frame_end =>
            if (VSYNC = '0') and (HSYNC = '0') then 
                state_next <= wait_frame_start;
            end if;
        
        when wait_frame_start =>
            if (VSYNC = '1') then 
                state_next <= wait_line_start;
            end if;
        
        when wait_line_start => -- VSYNC = 1 y HSYNC = 0.
            if (VSYNC = '0') then -- Fin de frame. VSYNC baja 6 ciclos PCLK despues de bajar HSYNC en la ultima linea.
                state_next <= idle;
            elsif (HSYNC = '1') then -- Primer byte válido de la linea nueva.
                salida_next <= DIN;
                push_next <= '1';
                state_next <= push_byte;
            end if;
        
        when push_byte => -- VSYNC = 1 y HSYNC = 1.
            if (HSYNC = '0') then -- Fin de linea. VSYNC sigue a 1.
                state_next <= wait_line_start;
            else
                salida_next <= DIN;
                push_next <= '1';
            end if;
    end case;
    end process COMB;
    
    DOUT <= salida_reg;
    PUSH <= push_reg;

end Behavioral;




----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Emilio Elias Sujar Overbury
-- 
-- Create Date: 04.06.2025 16:55:21
-- Design Name: 
-- Module Name: FT245_IF - Behavioral
-- Project Name: PARALELO
-- Target Devices: 
-- Tool Versions: 
-- Description: This proyect implements a FSM that controls asyncronous writing on a FT245 interface. MCLK operates at 100MHz.
-- There are two main segments, one secuencial process for state control (with asyncronous reset), and one combinational process for next state and other signals.
-- Inut signal TXEn is syncronized by passing through two FF.
-- Template instance example is shown for reference.
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
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
-- FT245_inst: entity FT245_IF
-- port map (
--     clk     => MCLK, -- i
--     reset   => MRST, -- i
    
    -- User IO ---------------------------
--     DIN     => UserDataIn,     -- i[7:0]
--     wr_en   => User_wr_en,     -- i
--     ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
--     TXEn    => FT245_TXEn,     -- i
--     WRn     => FT245_WRn,      -- o
--     DATA    => FT245_D         -- o[7:0]
-- );


entity FT245_IF is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           DIN : in STD_LOGIC_VECTOR (7 downto 0);
           wr_en : in STD_LOGIC;
           ready : out STD_LOGIC;
           TXEn : in STD_LOGIC;
           WRn : out STD_LOGIC;
           DATA : out STD_LOGIC_VECTOR (7 downto 0));
end FT245_IF;

--EC34. Modelaremos la FSM para el control de escritura as ncrono en un interfaz tipo FT245.
architecture Behavioral of FT245_IF is
    type state_type is (idle, write_1);
    signal state_reg, state_next: state_type;
--EC34. Trabajar con la versi n sincronizada de TXEn
    signal synchronizer: STD_LOGIC_VECTOR (2 downto 0); -- Modulo M24.
    signal TXEn_sync: STD_LOGIC;
    
    signal salida_next, salida_reg: STD_LOGIC_VECTOR (7 downto 0); -- para cada salida, crearemos dos se ales internas.
    signal WRn_next, WRn_reg: STD_LOGIC;
    signal ready_next, ready_reg: STD_LOGIC;

begin
--EC34. Utilizaremos dos segmentos de c digo:
--  un proceso para modelar el registro de estado. Unico bloque sincrono.
    REG: process (clk, reset) -- el reset de la FSM debe ser AS NCRONO.
    begin
        if reset='1' then
            state_reg <= idle;
            salida_reg <= (others => '0');
            ready_reg <= '1';   -- idle
            WRn_reg <= '1'; -- idle;
        elsif rising_edge(clk) then-- Las salidas deben ser registradas: olvida si son tipo Moore o Mealy.
            state_reg <= state_next;
            salida_reg <= salida_next;
            WRn_reg <= WRn_next;
            ready_reg <= ready_next;
        end if; -- proceso sincrono, no necesita sentencia else.
    end process REG;
        
    
--  otro proceso para modelar la l gica de estado siguiente. 
    COMB: process (state_reg, DIN, wr_en, TXEn_sync)    
    begin
    --EC34. Asignaci n por defecto: simplifica el c digo y evita LATCHES no deseados.
    state_next <= state_reg;
    salida_next <= salida_reg;
    ready_next <= ready_reg;
    WRn_next <= WRn_reg;
    case state_reg is
        when idle =>
            ready_next <= '1';
            WRn_next <= '1';
            if (wr_en = '1' and TXEn_sync = '0') then
                salida_next <= DIN;
                ready_next <= '0';
                WRn_next <= '0';
                state_next <= write_1;
            end if;
        
        when write_1 =>
            ready_next <= '0';
            WRn_next <= '1';
            state_next <= idle;
    end case;
    end process COMB;
    
    ready <= ready_reg;
    WRn <= WRn_reg;
    DATA <= salida_reg;

-- EC34. Modelaremos un simple sincronizador de 2 FF. Codigo copiado de M24.
    process begin
        wait until rising_edge(clk);
        synchronizer <= TXEn & synchronizer(2 downto 1);
    end process;
    TXEn_sync <= synchronizer(0);

end Behavioral;



